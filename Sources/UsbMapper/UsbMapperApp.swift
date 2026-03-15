import SwiftUI
import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - App Entry Point

@main
struct UsbMapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var service = USBDataService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
                .frame(minWidth: 900, minHeight: 550)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh USB Data") {
                    Task { await service.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
