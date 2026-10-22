import AppKit

final class NotchSettingsWindow: NSWindow {
    private let tabViewController = SettingsTabViewController()

    var onRoleChanged: (() -> Void)? {
        get { tabViewController.onRoleChanged }
        set { tabViewController.onRoleChanged = newValue }
    }

    var onDisplayChanged: (() -> Void)? {
        get { tabViewController.onDisplayChanged }
        set { tabViewController.onDisplayChanged = newValue }
    }

    var onSkillChanged: (() -> Void)? {
        get { tabViewController.onSkillChanged }
        set { tabViewController.onSkillChanged = newValue }
    }

    var onBackdropChanged: (() -> Void)? {
        get { tabViewController.onBackdropChanged }
        set { tabViewController.onBackdropChanged = newValue }
    }

    var onFullScreenHideChanged: (() -> Void)? {
        get { tabViewController.onFullScreenHideChanged }
        set { tabViewController.onFullScreenHideChanged = newValue }
    }

    var onLanguageChanged: (() -> Void)? {
        get { tabViewController.onLanguageChanged }
        set { tabViewController.onLanguageChanged = newValue }
    }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = L10n.text(.settingsTitle)
        isReleasedWhenClosed = false
        contentMinSize = NSSize(width: 580, height: 480)

        let tabView = tabViewController.view
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            tabView.topAnchor.constraint(equalTo: contentView!.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor)
        ])
    }

    func refresh() {
        title = L10n.text(.settingsTitle)
        tabViewController.refresh()
    }

    func centerNear(rect anchorRect: NSRect) {
        guard let screenFrame = ScreenPinning.preferredScreen()?.visibleFrame else {
            center()
            return
        }

        let margin: CGFloat = 16
        var origin = NSPoint(
            x: anchorRect.midX - frame.width / 2,
            y: anchorRect.minY - frame.height - 10
        )

        if origin.y < screenFrame.minY + margin {
            origin.y = anchorRect.minY - frame.height / 2
        }
        origin.x = min(max(origin.x, screenFrame.minX + margin), screenFrame.maxX - frame.width - margin)
        origin.y = min(max(origin.y, screenFrame.minY + margin), screenFrame.maxY - frame.height - margin)
        setFrameOrigin(origin)
    }
}

// MARK: - Tab View Controller

final class SettingsTabViewController: NSViewController {
    var onRoleChanged: (() -> Void)?
    var onDisplayChanged: (() -> Void)?
    var onSkillChanged: (() -> Void)?
    var onBackdropChanged: (() -> Void)?
    var onFullScreenHideChanged: (() -> Void)?
    var onLanguageChanged: (() -> Void)?

    private let tabView = NSTabView()

    // Tab view controllers
    private let generalTab = GeneralSettingsTab()
    private let gameTab = GameSettingsTab()
    private let equipmentTab = EquipmentSettingsTab()
    private let toolsTab = ToolsSettingsTab()
    private let sessionsTab = SessionsSettingsTab()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        setupTabs()
    }

    private func setupTabs() {
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewBorderType = .none
        view.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.topAnchor.constraint(equalTo: view.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // General Tab
        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = L10n.text(.tabGeneral)
        generalItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        generalItem.viewController = generalTab
        generalTab.onLanguageChanged = { [weak self] in
            self?.updateTabLabels()
            self?.onLanguageChanged?()
        }
        generalTab.onDisplayChanged = { [weak self] in
            self?.onDisplayChanged?()
        }
        generalTab.onFullScreenHideChanged = { [weak self] in
            self?.onFullScreenHideChanged?()
        }
        generalTab.onBackdropChanged = { [weak self] in
            self?.onBackdropChanged?()
        }
        tabView.addTabViewItem(generalItem)

        // Game Tab
        let gameItem = NSTabViewItem(identifier: "game")
        gameItem.label = L10n.text(.tabGame)
        gameItem.image = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: nil)
        gameItem.viewController = gameTab
        gameTab.onRoleChanged = { [weak self] in
            self?.onRoleChanged?()
        }
        gameTab.onSkillChanged = { [weak self] in
            self?.onSkillChanged?()
        }
        tabView.addTabViewItem(gameItem)

        // Equipment Tab
        let equipmentItem = NSTabViewItem(identifier: "equipment")
        equipmentItem.label = L10n.text(.tabEquipment)
        equipmentItem.image = NSImage(systemSymbolName: "shield", accessibilityDescription: nil)
        equipmentItem.viewController = equipmentTab
        tabView.addTabViewItem(equipmentItem)

        // Tools Tab
        let toolsItem = NSTabViewItem(identifier: "tools")
        toolsItem.label = L10n.text(.tabTools)
        toolsItem.image = NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: nil)
        toolsItem.viewController = toolsTab
        tabView.addTabViewItem(toolsItem)

        // Sessions Tab
        let sessionsItem = NSTabViewItem(identifier: "sessions")
        sessionsItem.label = L10n.text(.tabSessions)
        sessionsItem.image = NSImage(systemSymbolName: "rectangle.stack.person.crop", accessibilityDescription: nil)
        sessionsItem.viewController = sessionsTab
        tabView.addTabViewItem(sessionsItem)
    }

    private func updateTabLabels() {
        tabView.tabViewItems[0].label = L10n.text(.tabGeneral)
        tabView.tabViewItems[1].label = L10n.text(.tabGame)
        tabView.tabViewItems[2].label = L10n.text(.tabEquipment)
        tabView.tabViewItems[3].label = L10n.text(.tabTools)
        tabView.tabViewItems[4].label = L10n.text(.tabSessions)

        generalTab.refresh()
        gameTab.refresh()
        equipmentTab.refresh()
        toolsTab.refresh()
        sessionsTab.refresh()
    }

    func refresh() {
        updateTabLabels()
    }
}

// MARK: - General Settings Tab
