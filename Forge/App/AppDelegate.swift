import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        customizeWindowAppearance()
    }

    private func customizeWindowAppearance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = NSColor(AppTheme.windowBackground)

                // Try to hide the split view divider
                self.hideSplitViewDividers(in: window.contentView)
            }
        }
    }

    private func hideSplitViewDividers(in view: NSView?) {
        guard let view = view else { return }

        if let splitView = view as? NSSplitView {
            splitView.dividerStyle = .thin
        }

        for subview in view.subviews {
            hideSplitViewDividers(in: subview)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running for menu bar
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: "Forge")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 300)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: QuickCaptureView()
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

}
