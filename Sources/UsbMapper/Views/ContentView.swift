import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: USBDataService
    @State private var selectedNode: USBNode?
    @State private var selectedBusNumber: Int?
    @State private var showInspector = false

    /// Resolved bus info for the currently-selected bus header chip.
    private var selectedBus: BusInfo? {
        service.buses.first { $0.number == selectedBusNumber }
    }

    /// Inspector is enabled when something is selected.
    private var hasSelection: Bool { selectedNode != nil || selectedBusNumber != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Bottleneck summary bar
            if !service.buses.isEmpty {
                HStack(spacing: 8) {
                    let bottlenecks = service.allBottlenecks
                    if bottlenecks.isEmpty {
                        Label("No bottlenecks detected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Spacer()
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .imageScale(.small)
                        Text("\(bottlenecks.count) bottleneck\(bottlenecks.count == 1 ? "" : "s") detected")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                        Spacer()
                        // Clickable chips — tapping selects the node and opens inspector
                        BottleneckSummaryView(bottlenecks: bottlenecks, selectedNode: $selectedNode)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar)

                Divider()
            }

            mainContent
        }
        .navigationTitle("USB Mapper")
        .toolbar { toolbarContent }
        .task { await service.refresh() }
        // Auto-open inspector on selection; selecting one clears the other
        .onChange(of: selectedNode) { node in
            if node != nil {
                selectedBusNumber = nil
                showInspector = true
            }
        }
        .onChange(of: selectedBusNumber) { num in
            if num != nil {
                selectedNode = nil
                showInspector = true
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if service.isLoading {
            ProgressView("Loading USB devices...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = service.errorMessage {
            ErrorView(message: error) {
                Task { await service.refresh() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if service.buses.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "cable.connector.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("No USB devices found")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                // Main: topology flow chart
                TopologyFlowView(
                    buses: service.buses,
                    selectedNode: $selectedNode,
                    selectedBusNumber: $selectedBusNumber
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Right: collapsible inspector panel
                if showInspector {
                    Divider()
                    inspectorContent
                        .frame(width: 300)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showInspector)
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let node = selectedNode {
            DeviceDetailView(node: node)
        } else if let bus = selectedBus {
            BusDetailView(bus: bus)
        } else {
            EmptyDetailView()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Mac model chip
            if !service.macModelId.isEmpty {
                Text(service.macLayout?.name ?? service.macModelId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }

            Spacer()

            // Inspector toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showInspector.toggle() }
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .disabled(!hasSelection)
            .keyboardShortcut("i", modifiers: [.command, .option])
            .help("Show/hide inspector (⌘⌥I)")

            // Refresh
            Button {
                Task { await service.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(service.isLoading)
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            Text("Failed to load USB data")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
    }
}
