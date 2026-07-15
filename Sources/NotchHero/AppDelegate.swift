import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    private var statusItem: NSStatusItem?
    private var showMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .notchHeroLanguageChanged,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Vibe Hero")
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        let showItem = NSMenuItem(title: L10n.text(.showNotch), action: #selector(showNotchFromMenu), keyEquivalent: "s")
        let quitItem = NSMenuItem(title: L10n.text(.quitNotchHero), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(showItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        item.menu = menu

        showMenuItem = showItem
        quitMenuItem = quitItem
        statusItem = item
    }

    private func showNotchWindow() {
        let window = notchWindow ?? NotchWindow()
        notchWindow = window
        window.anchorToPreferredScreen()
        window.orderFrontRegardless()
    }

    @objc private func showNotchFromMenu() {
        showNotchWindow()
    }

    @objc private func screenParametersChanged() {
        notchWindow?.anchorToPreferredScreen()
    }

    @objc private func languageChanged() {
        showMenuItem?.title = L10n.text(.showNotch)
        quitMenuItem?.title = L10n.text(.quitNotchHero)
    }
}
