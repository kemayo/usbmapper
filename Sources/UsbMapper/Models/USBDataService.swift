import Foundation
import IOKit
import Darwin

struct BusInfo {
    let number: Int
    let portLabel: String      // e.g. "Thunderbolt Port 1", "Thunderbolt Bus 32", or "Bus 32"
    let apciecIndex: Int?      // 0, 1, 2... for known Thunderbolt port index; nil if unknown
    let isThunderbolt: Bool    // true when bus is attached via a Thunderbolt (PCIe) controller
    let controllerClass: String
    let roots: [USBNode]
}

@MainActor
class USBDataService: ObservableObject {
    @Published var buses: [BusInfo] = []
    @Published var macModelId: String = ""
    @Published var macLayout: MacPortLayout?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var allBottlenecks: [USBNode] {
        buses.flatMap { collectBottlenecks(from: $0.roots) }
    }

    private func collectBottlenecks(from nodes: [USBNode]) -> [USBNode] {
        nodes.flatMap { node -> [USBNode] in
            var result = node.isBottlenecked ? [node] : []
            result += collectBottlenecks(from: node.children)
            return result
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Run cyme and system queries concurrently
        async let cymeFetch = Task.detached { try runCyme() }
        async let modelFetch = Task.detached { getMacModelIdentifier() }
        async let ioKitFetch = Task.detached { getIOKitBusMapping() }

        do {
            let (cymeData, modelId, ioKitMapping) = try await (cymeFetch.value, modelFetch.value, ioKitFetch.value)

            let decoder = JSONDecoder()
            let cymeOutput = try decoder.decode(CymeOutput.self, from: cymeData)

            self.macModelId = modelId
            self.macLayout = MacModelDatabase.layout(for: modelId)

            self.buses = cymeOutput.buses.compactMap { cymeBus in
                let roots = USBNode.buildRoots(from: cymeBus)
                guard !roots.isEmpty else { return nil }  // skip buses with no visible devices

                let busNumber = cymeBus.usbBusNumber
                let ioInfo = ioKitMapping[busNumber]

                // Detect Thunderbolt: either IOKit found an apciecN ancestor, or cyme reports
                // a PCIe host controller (on Apple Silicon, PCIe USB = Thunderbolt).
                let isThunderbolt = ioInfo?.apciecIndex != nil
                    || cymeBus.hostController == "IOPCIDevice"

                let portLabel: String
                if let idx = ioInfo?.apciecIndex {
                    portLabel = "Thunderbolt Port \(idx + 1)"
                } else if isThunderbolt {
                    portLabel = "Thunderbolt Bus \(busNumber)"
                } else {
                    portLabel = "Bus \(busNumber)"
                }

                // Prefer the full controller device name from cyme; fall back to class name
                let controllerClass = cymeBus.hostControllerDevice ?? cymeBus.name

                return BusInfo(
                    number: busNumber,
                    portLabel: portLabel,
                    apciecIndex: ioInfo?.apciecIndex,
                    isThunderbolt: isThunderbolt,
                    controllerClass: controllerClass,
                    roots: roots
                )
            }.sorted { $0.number < $1.number }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - cyme subprocess

private func runCyme() throws -> Data {
    let cymePath = try findCymePath()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: cymePath)
    process.arguments = ["--json", "--tree"]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let errStr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw NSError(domain: "UsbMapper", code: Int(process.terminationStatus),
                      userInfo: [NSLocalizedDescriptionKey: "cyme failed: \(errStr)"])
    }
    return data
}

private func findCymePath() throws -> String {
    // 1. Bundled binary (distribution)
    if let bundled = Bundle.main.url(forResource: "cyme", withExtension: nil) {
        // Ensure executable bit is set (may be lost when copying as resource)
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: bundled.path
        )
        if FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled.path
        }
    }

    // 2. which cyme (development)
    let which = Process()
    which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    which.arguments = ["cyme"]
    let pipe = Pipe()
    which.standardOutput = pipe
    which.standardError = Pipe()
    try? which.run()
    which.waitUntilExit()
    let found = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !found.isEmpty { return found }

    // 3. Known Homebrew paths
    for path in ["/opt/homebrew/bin/cyme", "/usr/local/bin/cyme"] {
        if FileManager.default.isExecutableFile(atPath: path) { return path }
    }

    throw NSError(
        domain: "UsbMapper", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "cyme not found. Install via: brew install cyme\nOr rebuild the app to bundle cyme."]
    )
}

// MARK: - Mac model detection

private func getMacModelIdentifier() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    guard size > 0 else { return "Unknown" }
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}

// MARK: - IOKit bus-to-port mapping

struct IOKitBusInfo {
    let label: String
    let apciecIndex: Int?
    let controllerClass: String
}

private func getIOKitBusMapping() -> [Int: IOKitBusInfo] {
    var result: [Int: IOKitBusInfo] = [:]

    // Match USB host controllers
    guard let matchDict = IOServiceMatching("IOUSBHostController") else { return result }
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS else {
        return result
    }
    defer { IOObjectRelease(iterator) }

    var service = IOIteratorNext(iterator)
    while service != 0 {
        defer {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        var props: Unmanaged<CFMutableDictionary>?
        IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
        guard let propDict = props?.takeRetainedValue() as? [String: Any] else { continue }

        // Extract bus number from locationID (high byte)
        guard let locationId = propDict["locationID"] as? Int else { continue }
        let busNumber = (locationId >> 24) & 0xFF
        guard busNumber > 0 else { continue }

        let controllerClass = propDict["IOClass"] as? String ?? "Unknown"

        // Walk up the IOKit tree to find apciecN (Thunderbolt port indicator)
        let apciecResult = findApciecAncestor(of: service)

        let label: String
        if let (idx, _) = apciecResult {
            label = "Thunderbolt Port \(idx + 1)"
        } else {
            label = "Bus \(busNumber)"
        }

        result[busNumber] = IOKitBusInfo(
            label: label,
            apciecIndex: apciecResult?.0,
            controllerClass: controllerClass
        )
    }

    return result
}

/// Walk the IOKit service plane upward to find an apciecN ancestor.
/// Returns (apciecIndex, entryName) if found.
private func findApciecAncestor(of service: io_registry_entry_t) -> (Int, String)? {
    var current = service
    var depth = 0

    while depth < 50 {
        var parent: io_registry_entry_t = 0
        let kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
        guard kr == KERN_SUCCESS, parent != 0 else { break }

        if current != service { IOObjectRelease(current) }
        current = parent
        depth += 1

        var nameBuf = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(current, &nameBuf)
        let name = String(cString: nameBuf)

        // Match "apciecN" where N is the port index (0, 1, 2...)
        if name.hasPrefix("apciec") {
            let suffix = String(name.dropFirst(6))  // remove "apciec"
            if let idx = Int(suffix) {
                IOObjectRelease(current)
                return (idx, name)
            }
        }
    }

    if current != service { IOObjectRelease(current) }
    return nil
}
