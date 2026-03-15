import SwiftUI

// MARK: - Bus Section

struct BusSectionView: View {
    let bus: BusInfo
    @Binding var selection: USBNode?

    var body: some View {
        Section {
            List(bus.roots, children: \.childrenOrNil, selection: $selection) { node in
                DeviceRowView(node: node)
            }
            .listStyle(.sidebar)
        } header: {
            BusHeaderView(bus: bus)
        }
    }
}

struct BusHeaderView: View {
    let bus: BusInfo

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cable.connector.horizontal")
                .foregroundStyle(.secondary)
                .imageScale(.small)
            Text(bus.portLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text("Bus \(bus.number)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Device Row

struct DeviceRowView: View {
    let node: USBNode

    var body: some View {
        HStack(spacing: 8) {
            // Speed indicator dot
            Circle()
                .fill(speedDotColor)
                .frame(width: 8, height: 8)

            // Device icon + name
            Label {
                Text(node.name)
                    .font(node.isHub ? .body.weight(.medium) : .body)
                    .lineLimit(1)
            } icon: {
                Image(systemName: deviceIcon)
                    .foregroundStyle(node.isHub ? Color.secondary : Color.primary)
                    .imageScale(.small)
            }

            Spacer()

            // Right-side badges
            HStack(spacing: 4) {
                if let power = node.declaredPowerMa {
                    PowerBadge(milliamps: power)
                }

                if case .speedMismatch = node.bottleneckStatus {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .imageScale(.small)
                        .help("Hub is negotiating slower than its parent port offers")
                } else if case .hubLimited = node.bottleneckStatus {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .imageScale(.small)
                        .help("USB 3.x device limited by USB 2.x hub in path")
                }

                Text(node.actualSpeed.speedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    private var speedDotColor: Color {
        if node.isBottlenecked { return .orange }
        return node.actualSpeed.color
    }

    private var deviceIcon: String {
        if node.isHub { return "arrow.triangle.branch" }
        switch node.device.deviceClass {
        case "hub":                         return "arrow.triangle.branch"
        case "audio":                       return "speaker.wave.2.fill"
        case "hid":                         return "keyboard.fill"
        case "mass-storage":                return "externaldrive.fill"
        case "video":                       return "camera.fill"
        case "printer":                     return "printer.fill"
        case "image":                       return "scanner.fill"
        case "wireless-controller":         return "wifi"
        case "miscellaneous":               return "questionmark.circle.fill"
        default:                            return "desktopcomputer"
        }
    }
}

// MARK: - Power Badge

struct PowerBadge: View {
    let milliamps: Int

    var body: some View {
        Text("\(milliamps)mA")
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        if milliamps > 500 { return .red }
        if milliamps > 250 { return .orange }
        return .secondary
    }
}

// MARK: - Device Detail Panel

struct DeviceDetailView: View {
    let node: USBNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.title2.weight(.semibold))
                    if let mfr = node.device.manufacturer {
                        Text(mfr)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(node.device.deviceClass.capitalized)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // Speed section
                SpeedDetailSection(node: node)

                Divider()

                // Power section
                PowerDetailSection(node: node)

                // Hub downstream info
                if node.isHub {
                    Divider()
                    HubDetailSection(node: node)
                }

                // Raw identifiers
                Divider()
                IdentifiersSection(node: node)

                Spacer()
            }
            .padding()
        }
    }
}

struct SpeedDetailSection: View {
    let node: USBNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Speed", systemImage: "speedometer")
                .font(.headline)

            InfoRow(label: "Negotiated", value: "\(node.actualSpeed.speedLabel) (\(node.actualSpeed.shortLabel))")
                .foregroundStyle(node.actualSpeed.color)

            if let bcdUsb = node.device.bcdUsb {
                InfoRow(label: "USB Version", value: "USB \(bcdUsb)")
                InfoRow(label: "Minimum Capable", value: node.declaredMinSpeed?.speedLabel ?? "Unknown")
            }

            // Bottleneck description
            switch node.bottleneckStatus {
            case .none:
                Label("Running at expected speed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)

            case .hubLimited(let hubName, let hubKey):
                VStack(alignment: .leading, spacing: 6) {
                    Label("Speed Bottleneck Detected", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline.weight(.semibold))
                    Text("This device supports USB 3.x but is limited to \(node.actualSpeed.speedLabel) because **\(hubName)** (at \(hubKey)) in the path only negotiated USB 2.0.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Fix: Connect this device through a USB 3.x hub, or plug its hub directly into a Thunderbolt/USB 3.x port.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .padding(8)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            case .speedMismatch(let parentSpeed):
                VStack(alignment: .leading, spacing: 6) {
                    Label("Hub Speed Mismatch", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline.weight(.semibold))
                    Text("This hub is negotiating at \(node.actualSpeed.speedLabel), but its parent port offers \(parentSpeed.speedLabel). The hub, cable, or connection may be limiting throughput.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Fix: Try a different USB cable rated for \(parentSpeed.speedLabel), or replace the hub.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .padding(8)
                .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct PowerDetailSection: View {
    let node: USBNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Power", systemImage: "bolt.fill")
                .font(.headline)

            if node.isSelfPowered {
                Label("Self-powered (has its own power supply)", systemImage: "powerplug.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else if node.isBusPowered {
                if let power = node.declaredPowerMa {
                    InfoRow(label: "Bus draw (declared)", value: "\(power) mA")
                        .foregroundStyle(power > 500 ? .red : power > 250 ? .orange : .primary)

                    if power > 500 {
                        Label("High power draw — requires a powered hub or direct port connection", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    InfoRow(label: "Source", value: "Bus Powered")
                }
            } else {
                InfoRow(label: "Source", value: "Not reported")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HubDetailSection: View {
    let node: USBNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hub", systemImage: "arrow.triangle.branch")
                .font(.headline)

            if let ports = node.numPorts {
                InfoRow(label: "Ports", value: "\(ports)")
            }

            let downstreamPower = node.totalDownstreamPowerMa
            let deviceCount = node.busPoweredDescendantCount
            let budget = node.powerBudgetMa
            if deviceCount > 0 {
                InfoRow(label: "Downstream load", value: "\(downstreamPower) mA across \(deviceCount) bus-powered device\(deviceCount == 1 ? "" : "s")")
                    .foregroundStyle(downstreamPower > budget ? .orange : .primary)

                if downstreamPower > budget {
                    Label("Total downstream load exceeds the \(budget) mA USB power budget. Consider using self-powered devices or a powered hub.", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct IdentifiersSection: View {
    let node: USBNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Identifiers", systemImage: "info.circle")
                .font(.headline)

            InfoRow(label: "Position", value: node.treeKey)
            InfoRow(label: "Vendor ID", value: String(format: "0x%04X", node.device.vendorId))
            InfoRow(label: "Product ID", value: String(format: "0x%04X", node.device.productId))
            if let serial = node.device.serialNum {
                InfoRow(label: "Serial", value: serial)
            }
            if let bcdDev = node.device.bcdDevice {
                InfoRow(label: "Device Rev", value: bcdDev)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cable.connector")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Select a device or bus to view details")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Bus Detail Panel

struct BusDetailView: View {
    let bus: BusInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: bus.isThunderbolt ? "bolt.fill" : "cable.connector.horizontal")
                        .font(.title2)
                        .foregroundStyle(bus.isThunderbolt ? Color.blue : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bus.portLabel)
                            .font(.title2.weight(.semibold))
                        Text("Bus \(bus.number)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                // Controller
                VStack(alignment: .leading, spacing: 8) {
                    Label("Controller", systemImage: "cpu")
                        .font(.headline)
                    InfoRow(label: "Class", value: bus.controllerClass)
                    if let idx = bus.apciecIndex {
                        InfoRow(label: "Thunderbolt", value: "Port \(idx + 1) (apciec\(idx))")
                    }
                }

                Divider()

                // Device stats
                VStack(alignment: .leading, spacing: 8) {
                    Label("Devices", systemImage: "cable.connector.horizontal")
                        .font(.headline)

                    InfoRow(label: "Total", value: "\(totalDeviceCount)")
                    InfoRow(label: "Hubs", value: "\(hubCount)")

                    let bn = bottleneckCount
                    if bn > 0 {
                        InfoRow(label: "Bottlenecks", value: "\(bn)")
                            .foregroundStyle(.orange)
                    } else {
                        Label("No bottlenecks", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }

                // Power stats
                let totalPower = totalDownstreamPower
                let busPowered = busPoweredCount
                let budget = powerBudgetMa
                if busPowered > 0 {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Power", systemImage: "bolt.fill")
                            .font(.headline)
                        InfoRow(label: "Bus-powered devices", value: "\(busPowered)")
                        InfoRow(label: "Total declared draw", value: "\(totalPower) mA")
                            .foregroundStyle(totalPower > budget ? .red : .primary)
                        if totalPower > budget {
                            Label(
                                "Total exceeds the \(budget) mA USB power budget. Some devices may be unreliable.",
                                systemImage: "exclamationmark.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private var totalDeviceCount: Int { countNodes(bus.roots) }
    private var hubCount: Int { countNodes(bus.roots) { $0.isHub } }
    private var bottleneckCount: Int { countNodes(bus.roots) { $0.isBottlenecked } }
    private var busPoweredCount: Int { countNodes(bus.roots) { $0.isBusPowered && $0.declaredPowerMa != nil } }
    private var totalDownstreamPower: Int { bus.roots.reduce(0) { $0 + $1.totalDownstreamPowerMa } }
    /// Power budget derived from the fastest root device speed on this bus.
    private var powerBudgetMa: Int {
        (bus.roots.map(\.actualSpeed).max() ?? .unknown).powerBudgetMa
    }

    private func countNodes(_ nodes: [USBNode], _ predicate: ((USBNode) -> Bool)? = nil) -> Int {
        nodes.reduce(0) {
            let self_ = predicate == nil ? 1 : (predicate!($1) ? 1 : 0)
            return $0 + self_ + countNodes($1.children, predicate)
        }
    }
}
