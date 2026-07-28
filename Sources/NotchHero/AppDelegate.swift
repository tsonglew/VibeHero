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
        item.button?.image = createEngineerStatusIcon()
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

    private func createEngineerStatusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        let scale: CGFloat = 18 / 16
        let skinColor = NSColor(red: 0.95, green: 0.74, blue: 0.48, alpha: 1)
        let hairColor = NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
        let shirtColor = NSColor(red: 0.0, green: 0.72, blue: 0.78, alpha: 1)
        let glassesFrame = NSColor(red: 0.10, green: 0.14, blue: 0.18, alpha: 1)
        let glassesLens = NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1)

        // Head (skin)
        drawPixelRect(x: 5, y: 6, w: 6, h: 5, scale: scale, color: skinColor)

        // Hair (top and sides)
        drawPixelRect(x: 4, y: 10, w: 8, h: 2, scale: scale, color: hairColor)
        drawPixelRect(x: 4, y: 8, w: 1, h: 3, scale: scale, color: hairColor)
        drawPixelRect(x: 11, y: 8, w: 1, h: 3, scale: scale, color: hairColor)

        // Body (shirt)
        drawPixelRect(x: 5, y: 2, w: 6, h: 4, scale: scale, color: shirtColor)

        // Glasses frame
        drawPixelRect(x: 5, y: 7, w: 6, h: 1, scale: scale, color: glassesFrame)
        drawPixelRect(x: 5, y: 6, w: 1, h: 1, scale: scale, color: glassesFrame)
        drawPixelRect(x: 10, y: 6, w: 1, h: 1, scale: scale, color: glassesFrame)

        // Glasses lens (engineer's signature cyan glasses)
        drawPixelRect(x: 6, y: 6, w: 2, h: 1, scale: scale, color: glassesLens)
        drawPixelRect(x: 8, y: 6, w: 2, h: 1, scale: scale, color: glassesLens)

        image.unlockFocus()

        image.isTemplate = false
        return image
    }

    private func drawPixelRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, scale: CGFloat, color: NSColor) {
        color.setFill()
        NSRect(x: x * scale, y: y * scale, width: w * scale, height: h * scale).fill()
    }

    private func showNotchWindow() {
        let window = notchWindow ?? NotchWindow()
        notchWindow = window
        window.show()
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
