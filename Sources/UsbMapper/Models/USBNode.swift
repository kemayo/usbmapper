import Foundation

final class USBNode: ObservableObject, Identifiable, Hashable {
    let id: UUID = UUID()

    static func == (lhs: USBNode, rhs: USBNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let device: CymeDevice
    var children: [USBNode] = []
    weak var parent: USBNode?

    init(device: CymeDevice) {
        self.device = device
    }

    // MARK: - Computed Properties

    var name: String { device.name }
    var isHub: Bool { device.deviceClass == "hub" }
    var numPorts: Int? { device.extra?.hub?.numPorts }

    var treeKey: String {
        let bus = device.locationId.bus
        let pos = device.locationId.treePositions.map(String.init).joined(separator: ".")
        return "\(bus):\(pos)"
    }

    var actualSpeed: USBSpeed {
        USBSpeed.parse(device.deviceSpeed)
    }

    /// Standard USB power budget (mA) for the upstream port this node is connected at.
    var powerBudgetMa: Int { actualSpeed.powerBudgetMa }

    /// The minimum speed we know this device supports (from USB version declaration).
    var declaredMinSpeed: USBSpeed? {
        guard let bcdUsb = device.bcdUsb else { return nil }
        return USBSpeed.minSpeed(forBcdUsb: bcdUsb)
    }

    // MARK: - Bottleneck Detection

    enum BottleneckStatus: Equatable {
        case none
        /// USB 3.x device running at USB 2.x speeds due to a hub in the path
        case hubLimited(hubName: String, hubKey: String)
        /// Hub is negotiating slower than its parent offers (cable or device limit)
        case speedMismatch(parentSpeed: USBSpeed)
    }

    var bottleneckStatus: BottleneckStatus {
        // Case 1: Non-hub USB 3.x device running at USB 2.x speed
        if !isHub, let minSpeed = declaredMinSpeed, minSpeed.isUSB3OrHigher, actualSpeed.isUSB2OrLower {
            // Find the topmost USB 2.x hub in the ancestor chain (root cause)
            var limitingHub: USBNode? = nil
            var current = parent
            while let node = current {
                if node.actualSpeed.isUSB2OrLower {
                    limitingHub = node
                }
                current = node.parent
            }
            if let hub = limitingHub {
                return .hubLimited(hubName: hub.name, hubKey: hub.treeKey)
            }
        }

        // Case 2: Hub negotiating lower speed than its parent (possible cable/port issue)
        if isHub, let parentNode = parent {
            if actualSpeed < parentNode.actualSpeed {
                return .speedMismatch(parentSpeed: parentNode.actualSpeed)
            }
        }

        return .none
    }

    var isBottlenecked: Bool { bottleneckStatus != .none }

    // MARK: - Power Info

    private var firstConfig: DeviceConfiguration? {
        device.extra?.configurations?.first
    }

    var declaredPowerMa: Int? {
        guard let power = firstConfig?.maxPower else { return nil }
        return power.value > 0 ? power.value : nil
    }

    var isSelfPowered: Bool {
        firstConfig?.attributes?.contains("SelfPowered") ?? false
    }

    var isBusPowered: Bool {
        firstConfig?.attributes?.contains("BusPowered") ?? false
    }

    /// Sum of all bus-powered devices downstream (including self if bus-powered)
    var totalDownstreamPowerMa: Int {
        var total = 0
        if isBusPowered, let power = declaredPowerMa {
            total += power
        }
        for child in children {
            total += child.totalDownstreamPowerMa
        }
        return total
    }

    /// Number of bus-powered devices in the subtree (including self)
    var busPoweredDescendantCount: Int {
        var count = (isBusPowered && declaredPowerMa != nil) ? 1 : 0
        for child in children { count += child.busPoweredDescendantCount }
        return count
    }

    // MARK: - Tree helpers

    var childrenOrNil: [USBNode]? {
        children.isEmpty ? nil : children
    }

    var depth: Int {
        device.locationId.treePositions.count - 1
    }

    // MARK: - Tree Building

    /// Build root nodes from a cyme bus (tree mode). Children are embedded recursively.
    static func buildRoots(from cymeBus: CymeBus) -> [USBNode] {
        (cymeBus.devices ?? []).map { buildNode(from: $0, parent: nil) }
    }

    private static func buildNode(from device: CymeDevice, parent: USBNode?) -> USBNode {
        let node = USBNode(device: device)
        node.parent = parent
        node.children = (device.devices ?? []).map { buildNode(from: $0, parent: node) }
        return node
    }
}
