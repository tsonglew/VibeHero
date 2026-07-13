import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        showNotchWindow()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Notch Hero")
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Notch", action: #selector(showNotchFromMenu), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Notch Hero", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
    }

    private func showNotchWindow() {
        let window = notchWindow ?? NotchWindow()
        notchWindow = window
        window.anchorToActiveScreen()
        window.orderFrontRegardless()
    }

    @objc private func showNotchFromMenu() {
        showNotchWindow()
    }

    @objc private func screenParametersChanged() {
        notchWindow?.anchorToActiveScreen()
    }
}
