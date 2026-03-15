import SwiftUI
import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = makeAppIcon()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - App Icon

    /// Renders a composite icon: blue rounded-rect background, large MacBook outline,
    /// small cable-connector badge in the lower-right corner.
    private func makeAppIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)

        return NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext

            // --- Background: blue rounded rectangle ---
            let bgPath = CGPath(
                roundedRect: rect.insetBy(dx: 0, dy: 0),
                cornerWidth: 96, cornerHeight: 96,
                transform: nil
            )
            ctx.setFillColor(NSColor(red: 0.10, green: 0.38, blue: 0.90, alpha: 1).cgColor)
            ctx.addPath(bgPath)
            ctx.fillPath()

            // --- Inner soft gradient overlay ---
            ctx.saveGState()
            ctx.addPath(bgPath)
            ctx.clip()
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    CGColor(red: 1, green: 1, blue: 1, alpha: 0.12),
                    CGColor(red: 0, green: 0, blue: 0, alpha: 0.08),
                ] as CFArray,
                locations: [0, 1]
            )!
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.maxY),
                end:   CGPoint(x: rect.midX, y: rect.minY),
                options: []
            )
            ctx.restoreGState()

            // --- MacBook symbol (large, centered slightly above middle) ---
            let laptopPt: CGFloat = 240
            let laptopCfg = NSImage.SymbolConfiguration(pointSize: laptopPt, weight: .thin)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            if let laptop = NSImage(systemSymbolName: "laptopcomputer",
                                    accessibilityDescription: nil)?
                .withSymbolConfiguration(laptopCfg) {
                // Draw centered, nudged up slightly
                let lw = laptop.size.width
                let lh = laptop.size.height
                let lx = rect.midX - lw / 2
                let ly = rect.midY - lh / 2 + 20
                laptop.draw(in: NSRect(x: lx, y: ly, width: lw, height: lh))
            }

            // --- Cable connector badge (lower-right, with a white circle backing) ---
            let badgePt: CGFloat = 104
            let badgeCfg = NSImage.SymbolConfiguration(pointSize: badgePt, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [
                    NSColor(red: 0.10, green: 0.38, blue: 0.90, alpha: 1)
                ]))
            if let cable = NSImage(systemSymbolName: "cable.connector",
                                   accessibilityDescription: nil)?
                .withSymbolConfiguration(badgeCfg) {
                let cw = cable.size.width
                let ch = cable.size.height
                // Position in lower-right quadrant
                let cx = rect.maxX - cw - 28
                let cy = rect.minY + 32

                // White circle backing for contrast
                let pad: CGFloat = 12
                let circleRect = NSRect(x: cx - pad, y: cy - pad,
                                        width: cw + pad * 2, height: ch + pad * 2)
                let circlePath = NSBezierPath(ovalIn: circleRect)
                NSColor.white.setFill()
                circlePath.fill()

                cable.draw(in: NSRect(x: cx, y: cy, width: cw, height: ch))
            }

            return true
        }
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
