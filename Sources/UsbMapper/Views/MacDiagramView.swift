import SwiftUI

// MARK: - Layout Algorithm

/// Computes exact x/y positions for a left-to-right USB topology tree.
///
/// Each node occupies a vertical "slot". Leaf nodes get a slot equal to `nodeHeight`.
/// Non-leaf nodes get a slot equal to the sum of their children's slots (+ gaps between them).
/// The parent box is centered vertically within its slot, placing it midway between its first
/// and last child. Edges are Bezier S-curves with per-port attachment points, weighted by speed.
enum FlowLayout {
    static let nodeWidth: CGFloat = 164
    static let nodeHeight: CGFloat = 46     // tall enough for 2 content rows + padding
    static let busHeaderHeight: CGFloat = 52
    static let hGap: CGFloat = 44           // horizontal gap between parent-right and child-left
    static let vGap: CGFloat = 14           // vertical gap between sibling subtrees

    struct LayoutNode: Identifiable {
        let id: UUID
        let node: USBNode
        let rect: CGRect
    }

    struct Edge {
        let from: CGRect
        let to: CGRect
        let color: Color
        let sourcePortY: CGFloat  // Y of the port dot on from-box's right edge
        let lineWidth: CGFloat    // stroke weight derived from connection speed
        let isCableLimited: Bool  // true when child has .speedMismatch status
    }

    struct BusLayout: Identifiable {
        let id: Int
        let busInfo: BusInfo
        let headerRect: CGRect
        let nodes: [LayoutNode]
        let edges: [Edge]
        let totalSize: CGSize
    }

    // MARK: Public

    static func layoutBus(_ bus: BusInfo) -> BusLayout {
        var allNodes: [LayoutNode] = []
        var allEdges: [Edge] = []

        let rootsOriginX = nodeWidth + hGap

        // Pre-compute total slot height so we can centre the roots within totalHeight,
        // ensuring root midYs align with the bus header's midY even when the header
        // is taller than any individual root subtree.
        let rootsSlotTotal: CGFloat = bus.roots.isEmpty ? 0 :
            bus.roots.map { slotHeight(for: $0) }.reduce(0, +) +
            CGFloat(bus.roots.count - 1) * vGap
        let totalHeight = max(busHeaderHeight, rootsSlotTotal)
        var cursor: CGFloat = (totalHeight - rootsSlotTotal) / 2

        var rootRects: [(rect: CGRect, node: USBNode)] = []

        for root in bus.roots {
            let (nodes, edges, slot) = layoutSubtree(root, x: rootsOriginX, slotTop: cursor)
            allNodes.append(contentsOf: nodes)
            allEdges.append(contentsOf: edges)
            if let first = nodes.first { rootRects.append((first.rect, root)) }
            cursor += slot + vGap
        }

        let headerY = (totalHeight - busHeaderHeight) / 2
        let headerRect = CGRect(x: 0, y: headerY, width: nodeWidth, height: busHeaderHeight)

        // Bus header → each root; ports distributed evenly along the header's right edge
        let rootN = rootRects.count
        for (k, (rootRect, root)) in rootRects.enumerated() {
            let portY = headerRect.minY + CGFloat(k + 1) / CGFloat(rootN + 1) * headerRect.height
            let color: Color = bus.isThunderbolt
                ? Color.blue.opacity(0.85)
                : root.actualSpeed.color.opacity(0.85)
            let isCableLimited: Bool
            if case .speedMismatch = root.bottleneckStatus { isCableLimited = true }
            else { isCableLimited = false }
            allEdges.append(Edge(
                from: headerRect, to: rootRect, color: color,
                sourcePortY: portY,
                lineWidth: root.actualSpeed.lineWidth,
                isCableLimited: isCableLimited
            ))
        }

        let maxX = allNodes.map { $0.rect.maxX }.max() ?? nodeWidth
        let totalWidth = bus.roots.isEmpty ? nodeWidth : maxX

        return BusLayout(
            id: bus.number,
            busInfo: bus,
            headerRect: headerRect,
            nodes: allNodes,
            edges: allEdges,
            totalSize: CGSize(width: totalWidth, height: totalHeight)
        )
    }

    // MARK: Private

    private static func layoutSubtree(
        _ node: USBNode, x: CGFloat, slotTop: CGFloat
    ) -> ([LayoutNode], [Edge], CGFloat) {
        let slot = slotHeight(for: node)
        let nodeY = slotTop + (slot - nodeHeight) / 2
        let rect = CGRect(x: x, y: nodeY, width: nodeWidth, height: nodeHeight)
        let layoutNode = LayoutNode(id: node.id, node: node, rect: rect)

        guard !node.children.isEmpty else {
            return ([layoutNode], [], slot)
        }

        var childNodes: [LayoutNode] = []
        var childEdges: [Edge] = []
        let childX = x + nodeWidth + hGap
        var childSlotTop = slotTop

        let childN = node.children.count
        for (k, child) in node.children.enumerated() {
            let (cNodes, cEdges, cSlot) = layoutSubtree(child, x: childX, slotTop: childSlotTop)
            childNodes.append(contentsOf: cNodes)
            childEdges.append(contentsOf: cEdges)
            if let childRect = cNodes.first?.rect {
                // Port Y distributed evenly within parent box height (N+1 divisor keeps
                // dots away from the corners; for N=1 this gives exactly rect.midY)
                let portY = rect.minY + CGFloat(k + 1) / CGFloat(childN + 1) * rect.height
                let isCableLimited: Bool
                if case .speedMismatch = child.bottleneckStatus { isCableLimited = true }
                else { isCableLimited = false }
                childEdges.append(Edge(
                    from: rect, to: childRect,
                    color: child.actualSpeed.color.opacity(0.85),
                    sourcePortY: portY,
                    lineWidth: child.actualSpeed.lineWidth,
                    isCableLimited: isCableLimited
                ))
            }
            childSlotTop += cSlot + vGap
        }

        return ([layoutNode] + childNodes, childEdges, slot)
    }

    static func slotHeight(for node: USBNode) -> CGFloat {
        if node.children.isEmpty { return nodeHeight }
        let childSlots = node.children.map { slotHeight(for: $0) }
        return childSlots.reduce(0, +) + CGFloat(node.children.count - 1) * vGap
    }
}

// MARK: - Topology Flow Chart View

struct TopologyFlowView: View {
    let buses: [BusInfo]
    @Binding var selectedNode: USBNode?
    @Binding var selectedBusNumber: Int?

    private var busLayouts: [FlowLayout.BusLayout] {
        buses.map { FlowLayout.layoutBus($0) }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            if buses.isEmpty {
                Text("No USB buses found")
                    .foregroundStyle(.secondary)
                    .padding(40)
            } else {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(busLayouts) { layout in
                        BusFlowView(
                            layout: layout,
                            selectedNode: $selectedNode,
                            selectedBusNumber: $selectedBusNumber
                        )
                    }
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Per-Bus Flow View

struct BusFlowView: View {
    let layout: FlowLayout.BusLayout
    @Binding var selectedNode: USBNode?
    @Binding var selectedBusNumber: Int?

    private var isBusSelected: Bool { selectedBusNumber == layout.busInfo.number }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Lines (drawn first so boxes render on top)
            Canvas { ctx, _ in
                drawEdges(in: ctx)
            }
            .frame(width: layout.totalSize.width, height: layout.totalSize.height)
            .allowsHitTesting(false)

            // Bus header chip
            BusHeaderChip(bus: layout.busInfo, isSelected: isBusSelected)
                .frame(width: FlowLayout.nodeWidth, height: FlowLayout.busHeaderHeight)
                .position(x: layout.headerRect.midX, y: layout.headerRect.midY)
                .onTapGesture {
                    selectedBusNumber = layout.busInfo.number
                    selectedNode = nil
                }

            // Node boxes
            ForEach(layout.nodes) { ln in
                FlowNodeBox(node: ln.node, isSelected: selectedNode?.id == ln.node.id)
                    .frame(width: FlowLayout.nodeWidth, height: FlowLayout.nodeHeight)
                    .position(x: ln.rect.midX, y: ln.rect.midY)
                    .onTapGesture {
                        selectedNode = ln.node
                        selectedBusNumber = nil
                    }
            }
        }
        .frame(width: layout.totalSize.width, height: layout.totalSize.height)
    }

    private func drawEdges(in ctx: GraphicsContext) {
        let dotRadius: CGFloat = 3.5
        let cpOffset = FlowLayout.hGap * 0.6   // Bezier tangent — horizontal at both endpoints

        for edge in layout.edges {
            let start = CGPoint(x: edge.from.maxX, y: edge.sourcePortY)
            let end   = CGPoint(x: edge.to.minX,   y: edge.to.midY)
            let cp1   = CGPoint(x: start.x + cpOffset, y: start.y)
            let cp2   = CGPoint(x: end.x   - cpOffset, y: end.y)

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end, control1: cp1, control2: cp2)

            if edge.isCableLimited {
                // Thick red underlay — bleeds out around the speed-colour line as a highlight
                ctx.stroke(path, with: .color(.red.opacity(0.7)),
                           style: StrokeStyle(lineWidth: edge.lineWidth + 3,
                                              lineCap: .round))
            }
            // Speed-colour line on top — shows which tier it's actually running at
            ctx.stroke(path, with: .color(edge.color),
                       style: StrokeStyle(lineWidth: edge.lineWidth,
                                          lineCap: .round, lineJoin: .round))

            // Port dot on source right edge — drawn after stroke so it sits on top
            let dotColor = edge.isCableLimited ? Color.red : edge.color
            let dot = CGRect(x: start.x - dotRadius, y: start.y - dotRadius,
                             width: dotRadius * 2, height: dotRadius * 2)
            ctx.fill(Path(ellipseIn: dot), with: .color(dotColor))
        }
    }
}

// MARK: - Bus Header Chip

struct BusHeaderChip: View {
    let bus: BusInfo
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: bus.isThunderbolt ? "bolt.fill" : "cable.connector.horizontal")
                    .imageScale(.small)
                    .foregroundStyle(bus.isThunderbolt ? Color.blue : Color.secondary)
                Text(bus.portLabel)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Text(bus.controllerClass)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: FlowLayout.nodeWidth, height: FlowLayout.busHeaderHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.blue.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1)
                )
        )
        .contentShape(Rectangle())
        .onHover { over in over ? NSCursor.pointingHand.push() : NSCursor.pop() }
    }
}

// MARK: - Node Box

struct FlowNodeBox: View {
    let node: USBNode
    let isSelected: Bool

    private var isPowerOverloaded: Bool {
        node.isHub && node.totalDownstreamPowerMa > node.powerBudgetMa
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Row 1: icon + name
            HStack(spacing: 4) {
                Image(systemName: deviceIcon)
                    .imageScale(.small)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 10))
                Text(node.name)
                    .font(.caption.weight(node.isHub ? .semibold : .regular))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }

            // Row 2: speed pill + power pill
            HStack(spacing: 4) {
                speedPill
                powerPill
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: FlowLayout.nodeWidth, height: FlowLayout.nodeHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(boxFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(boxStroke, lineWidth: isSelected ? 2 : 1)
                )
        )
        .contentShape(Rectangle())
        .onHover { over in over ? NSCursor.pointingHand.push() : NSCursor.pop() }
    }

    private var speedPillColor: Color {
        node.isBottlenecked ? bottleneckColor : node.actualSpeed.color
    }

    @ViewBuilder
    private var speedPill: some View {
        HStack(spacing: 2) {
            if node.isBottlenecked {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 7))
            }
            Text(node.actualSpeed.speedLabel)
                .font(.system(size: 9).monospacedDigit())
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(speedPillColor.opacity(0.15), in: Capsule())
        .foregroundStyle(speedPillColor)
    }

    @ViewBuilder
    private var powerPill: some View {
        if isPowerOverloaded && node.isSelfPowered {
            // Self-powered mitigates risk — show plug icon + warning + mA in orange
            HStack(spacing: 2) {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 7))
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 7))
                Text("\(node.totalDownstreamPowerMa) mA")
                    .font(.system(size: 8).monospacedDigit())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.orange.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.orange)
        } else if isPowerOverloaded {
            HStack(spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 7))
                Text("\(node.totalDownstreamPowerMa) mA")
                    .font(.system(size: 8).monospacedDigit())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.red.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.red)
        } else if node.isSelfPowered {
            Image(systemName: "powerplug.fill")
                .font(.system(size: 8))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.green.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.green)
        } else if let mA = node.declaredPowerMa, node.isBusPowered {
            Text("\(mA) mA")
                .font(.system(size: 8))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(powerColor(mA).opacity(0.15), in: Capsule())
                .foregroundStyle(powerColor(mA))
        }
    }

    private var boxFill: Color {
        if isSelected { return Color.accentColor.opacity(0.07) }
        switch node.bottleneckStatus {
        case .hubLimited:    return Color.orange.opacity(0.07)
        case .speedMismatch: return Color.yellow.opacity(0.07)
        case .none:
            if isPowerOverloaded {
                return node.isSelfPowered ? Color.orange.opacity(0.07) : Color.red.opacity(0.07)
            }
            return Color(.windowBackgroundColor)
        }
    }

    private var boxStroke: Color {
        if isSelected { return .accentColor }
        switch node.bottleneckStatus {
        case .hubLimited:    return Color.orange.opacity(0.5)
        case .speedMismatch: return Color.yellow.opacity(0.5)
        case .none:
            if isPowerOverloaded {
                return node.isSelfPowered ? Color.orange.opacity(0.5) : Color.red.opacity(0.5)
            }
            return Color.secondary.opacity(0.25)
        }
    }

    private var bottleneckColor: Color {
        switch node.bottleneckStatus {
        case .hubLimited:    return .orange
        case .speedMismatch: return .yellow
        case .none:          return .clear
        }
    }

    private var iconColor: Color { node.isHub ? .secondary : .primary }

    private var deviceIcon: String {
        if node.isHub { return "arrow.triangle.branch" }
        switch node.device.deviceClass {
        case "audio":               return "speaker.wave.2.fill"
        case "hid":                 return "keyboard.fill"
        case "mass-storage":        return "externaldrive.fill"
        case "video":               return "camera.fill"
        case "printer":             return "printer.fill"
        case "image":               return "scanner.fill"
        case "wireless-controller": return "wifi"
        default:                    return "circle.fill"
        }
    }

    private func powerColor(_ mA: Int) -> Color {
        if mA > 500 { return .red }
        if mA > 250 { return .orange }
        return .secondary
    }
}

// MARK: - Bottleneck Summary

struct BottleneckSummaryView: View {
    let bottlenecks: [USBNode]
    @Binding var selectedNode: USBNode?

    var body: some View {
        if bottlenecks.isEmpty {
            Label("No bottlenecks detected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
                .padding(.horizontal)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(bottlenecks) { node in
                        BottleneckChip(node: node, selectedNode: $selectedNode)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct BottleneckChip: View {
    let node: USBNode
    @Binding var selectedNode: USBNode?

    private var isHighlighted: Bool { selectedNode?.id == node.id }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .imageScale(.small)
                .foregroundStyle(chipColor)
            Text(node.name)
                .font(.caption)
                .lineLimit(1)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(node.actualSpeed.speedLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(chipColor.opacity(isHighlighted ? 0.2 : 0.1), in: Capsule())
        .overlay(Capsule().stroke(chipColor.opacity(isHighlighted ? 0.6 : 0.25), lineWidth: isHighlighted ? 1.5 : 0.5))
        .contentShape(Capsule())
        .onTapGesture { selectedNode = node }
        .onHover { over in over ? NSCursor.pointingHand.push() : NSCursor.pop() }
    }

    private var chipColor: Color {
        switch node.bottleneckStatus {
        case .hubLimited:    return .orange
        case .speedMismatch: return .yellow
        case .none:          return .clear
        }
    }

    private var iconName: String {
        switch node.bottleneckStatus {
        case .hubLimited:    return "exclamationmark.triangle.fill"
        case .speedMismatch: return "exclamationmark.circle.fill"
        case .none:          return "checkmark"
        }
    }
}
