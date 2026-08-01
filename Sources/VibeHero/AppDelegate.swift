import AppKit

/// One-time rename of the persisted `NotchHero.*` UserDefaults keys to
/// `VibeHero.*`, from before the app settled on the Vibe Hero name. Without
/// this, existing players would lose kills, XP, gold, equipment and settings
/// on the first launch of a renamed build. Safe to delete once installs from
/// that era no longer matter.
enum LegacyDefaultsMigration {
    static func run() {
        let defaults = UserDefaults.standard
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix("NotchHero.") {
            let newKey = "VibeHero." + key.dropFirst("NotchHero.".count)
            if defaults.object(forKey: newKey) == nil {
                defaults.set(value, forKey: newKey)
            }
            defaults.removeObject(forKey: key)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var notchWindow: NotchWindow?
    private var statusItem: NSStatusItem?
    private var heroMenuItem: NSMenuItem?
    private var openMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var fullScreenMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LegacyDefaultsMigration.run()
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(roleChanged),
            name: .vibeHeroRoleChanged,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        let role = HeroRole.load()
        let roleIcon = createStatusIcon(for: role)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = roleIcon
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.delegate = self

        let heroItem = NSMenuItem(title: heroMenuTitle(for: role), action: nil, keyEquivalent: "")
        heroItem.image = roleIcon
        heroItem.isEnabled = false

        let openItem = NSMenuItem(title: L10n.text(.openVibeHero), action: #selector(openVibeHero), keyEquivalent: "o")
        openItem.target = self
        openItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: L10n.text(.openVibeHero))

        let settingsItem = NSMenuItem(title: L10n.text(.openSettings), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: L10n.text(.openSettings))

        let fullScreenItem = NSMenuItem(title: L10n.text(.hideInFullScreen), action: #selector(toggleFullScreenHide), keyEquivalent: "")
        fullScreenItem.target = self
        fullScreenItem.state = FullScreenHidePreference.load() ? .on : .off

        let quitItem = NSMenuItem(title: L10n.text(.quitVibeHero), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(heroItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(openItem)
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(fullScreenItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        item.menu = menu

        heroMenuItem = heroItem
        openMenuItem = openItem
        settingsMenuItem = settingsItem
        fullScreenMenuItem = fullScreenItem
        quitMenuItem = quitItem
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshStatusMenu()
    }

    private func refreshStatusMenu() {
        let role = HeroRole.load()
        let roleIcon = createStatusIcon(for: role)
        statusItem?.button?.image = roleIcon
        heroMenuItem?.image = roleIcon
        heroMenuItem?.title = heroMenuTitle(for: role)
        openMenuItem?.title = L10n.text(.openVibeHero)
        settingsMenuItem?.title = L10n.text(.openSettings)
        fullScreenMenuItem?.title = L10n.text(.hideInFullScreen)
        fullScreenMenuItem?.state = FullScreenHidePreference.load() ? .on : .off
        quitMenuItem?.title = L10n.text(.quitVibeHero)
    }

    private func heroMenuTitle(for role: HeroRole) -> String {
        L10n.string(.appTitleWithRole, role.label)
    }

    private func createStatusIcon(for role: HeroRole) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let hero = PixelActorView(kind: .hero)
        hero.frame = NSRect(origin: .zero, size: size)
        hero.heroRole = role

        let image = NSImage(size: size, flipped: true) { rect in
            hero.frame = rect
            hero.draw(rect)
            return true
        }

        image.isTemplate = false
        return image
    }

    private func showNotchWindow() {
        let window = notchWindow ?? NotchWindow()
        notchWindow = window
        window.show()
    }

    @objc private func openVibeHero() {
        showNotchWindow()
    }

    @objc private func openSettings() {
        let window = notchWindow ?? NotchWindow()
        notchWindow = window
        window.showSettings()
    }

    @objc private func toggleFullScreenHide() {
        FullScreenHidePreference.save(!FullScreenHidePreference.load())
        notchWindow?.refreshFullScreenVisibility()
        refreshStatusMenu()
    }

    @objc private func screenParametersChanged() {
        notchWindow?.anchorToPreferredScreen()
    }

    @objc private func languageChanged() {
        refreshStatusMenu()
    }

    @objc private func roleChanged() {
        refreshStatusMenu()
    }
}
