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

final class GeneralSettingsTab: NSViewController {
    var onLanguageChanged: (() -> Void)?
    var onDisplayChanged: (() -> Void)?
    var onFullScreenHideChanged: (() -> Void)?
    var onBackdropChanged: (() -> Void)?

    private let scrollView = NSScrollView()
    private let contentView = NSView()

    // UI Elements
    private let languageLabel = NSTextField(labelWithString: "")
    private let languagePopup = NSPopUpButton()
    private let displayLabel = NSTextField(labelWithString: "")
    private let displayPopup = NSPopUpButton()
    private let displayDetailLabel = NSTextField(labelWithString: "")
    private let fullScreenLabel = NSTextField(labelWithString: "")
    private let fullScreenToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fullScreenDetailLabel = NSTextField(labelWithString: "")
    private let backdropLabel = NSTextField(labelWithString: "")
    private var backdropChoiceViews: [BackdropChoiceView] = []
    private var displayIDs: [Int?] = []

    override func loadView() {
        view = NSView()
        setup()
    }

    private func setup() {
        // Setup scroll view
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24)
        ])

        // Style labels
        languageLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        displayLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        fullScreenLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        backdropLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        [displayDetailLabel, fullScreenDetailLabel].forEach {
            $0.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            $0.textColor = .secondaryLabelColor
            $0.lineBreakMode = .byWordWrapping
            $0.maximumNumberOfLines = 2
        }

        // Language
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)

        let languageStack = NSStackView(views: [languageLabel, languagePopup])
        languageStack.orientation = .vertical
        languageStack.alignment = .leading
        languageStack.spacing = 8
        languagePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        // Display
        displayPopup.target = self
        displayPopup.action = #selector(displayChanged)

        let displayStack = NSStackView(views: [displayLabel, displayPopup, displayDetailLabel])
        displayStack.orientation = .vertical
        displayStack.alignment = .leading
        displayStack.spacing = 8
        displayPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

        // Full Screen
        fullScreenToggle.target = self
        fullScreenToggle.action = #selector(fullScreenHideChanged)

        let fullScreenStack = NSStackView(views: [fullScreenLabel, fullScreenToggle, fullScreenDetailLabel])
        fullScreenStack.orientation = .vertical
        fullScreenStack.alignment = .leading
        fullScreenStack.spacing = 8

        // Backdrop
        let backdropRowStack = NSStackView()
        backdropRowStack.orientation = .horizontal
        backdropRowStack.alignment = .top
        backdropRowStack.spacing = 8

        backdropChoiceViews = BattleBackdrop.allCases.map { backdrop in
            let choiceView = BackdropChoiceView(backdrop: backdrop)
            choiceView.onSelected = { [weak self] selectedBackdrop in
                self?.selectBackdrop(selectedBackdrop)
            }
            backdropRowStack.addArrangedSubview(choiceView)
            return choiceView
        }

        let backdropStack = NSStackView(views: [backdropLabel, backdropRowStack])
        backdropStack.orientation = .vertical
        backdropStack.alignment = .leading
        backdropStack.spacing = 8

        // Main stack
        let mainStack = NSStackView(views: [
            languageStack,
            makeSeparator(),
            displayStack,
            makeSeparator(),
            fullScreenStack,
            makeSeparator(),
            backdropStack
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            displayDetailLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            fullScreenDetailLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        refresh()
    }

    func refresh() {
        languageLabel.stringValue = L10n.text(.language)
        displayLabel.stringValue = L10n.text(.display)
        fullScreenLabel.stringValue = L10n.text(.fullScreen)
        fullScreenToggle.title = L10n.text(.hideInFullScreen)
        fullScreenDetailLabel.stringValue = L10n.text(.hideInFullScreenDetail)
        backdropLabel.stringValue = L10n.text(.backdrop)

        // Language options
        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: AppLanguage.allCases.map(\.displayName))
        let selectedLanguage = AppLanguage.load()
        languagePopup.selectItem(at: AppLanguage.allCases.firstIndex(of: selectedLanguage) ?? 0)

        // Display options
        let screens = NSScreen.screens
        displayIDs = [nil] + screens.map(\.notchDisplayID)
        displayPopup.removeAllItems()
        displayPopup.addItem(withTitle: L10n.text(.followActiveDisplay))
        screens.forEach { screen in
            displayPopup.addItem(withTitle: screen.notchDisplayName)
        }

        let selectedDisplayID = ScreenPinning.load()
        if let selectedDisplayID,
           let index = screens.firstIndex(where: { $0.notchDisplayID == selectedDisplayID }) {
            displayPopup.selectItem(at: index + 1)
            displayDetailLabel.stringValue = L10n.string(.fixedToDisplay, screens[index].notchDisplayName)
        } else {
            displayPopup.selectItem(at: 0)
            displayDetailLabel.stringValue = selectedDisplayID == nil
                ? L10n.text(.followsActiveDisplay)
                : L10n.text(.pinnedDisplayMissing)
        }

        // Full screen toggle
        fullScreenToggle.state = FullScreenHidePreference.load() ? .on : .off

        // Backdrop
        backdropChoiceViews.forEach { $0.refreshSelection() }
    }

    @objc private func languageChanged() {
        let index = languagePopup.indexOfSelectedItem
        guard AppLanguage.allCases.indices.contains(index) else { return }
        AppLanguage.save(AppLanguage.allCases[index])
        refresh()
        onLanguageChanged?()
    }

    @objc private func displayChanged() {
        let index = displayPopup.indexOfSelectedItem
        let selectedDisplayID = displayIDs.indices.contains(index) ? displayIDs[index] : nil
        ScreenPinning.save(selectedDisplayID)
        refresh()
        onDisplayChanged?()
    }

    @objc private func fullScreenHideChanged() {
        FullScreenHidePreference.save(fullScreenToggle.state == .on)
        onFullScreenHideChanged?()
    }

    private func selectBackdrop(_ backdrop: BattleBackdrop) {
        backdrop.save()
        refresh()
        onBackdropChanged?()
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }
}

// MARK: - Game Settings Tab

final class GameSettingsTab: NSViewController {
    var onRoleChanged: (() -> Void)?
    var onSkillChanged: (() -> Void)?

    private let scrollView = NSScrollView()
    private let contentView = NSView()

    private let roleLabel = NSTextField(labelWithString: "")
    private let roleDetailLabel = NSTextField(labelWithString: "")
    private let rolePerkLabel = NSTextField(labelWithString: "")
    private var roleChoiceViews: [RoleChoiceView] = []
    private let skillTreeView = SkillTreeView()
    private let skillsOverlay = DevelopmentOverlayView(detail: .inDevelopmentSkillsDetail)

    override func loadView() {
        view = NSView()
        setup()
    }

    private func setup() {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            // Pinning the bottom too would cap the document at the viewport, which
            // clipped the 500pt skill module with no way to scroll to it. Filling
            // the viewport is the minimum; taller content scrolls.
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor)
        ])
        roleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        roleDetailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        roleDetailLabel.textColor = .secondaryLabelColor
        roleDetailLabel.lineBreakMode = .byWordWrapping
        roleDetailLabel.maximumNumberOfLines = 2
        rolePerkLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        rolePerkLabel.textColor = .secondaryLabelColor
        rolePerkLabel.lineBreakMode = .byWordWrapping
        rolePerkLabel.maximumNumberOfLines = 2

        let roleGridStack = NSStackView()
        roleGridStack.orientation = .vertical
        roleGridStack.alignment = .leading
        roleGridStack.spacing = 8

        roleChoiceViews = HeroRole.allCases.map { role in
            let choiceView = RoleChoiceView(role: role)
            choiceView.onSelected = { [weak self] selectedRole in
                self?.selectRole(selectedRole)
            }
            return choiceView
        }

        for rowStart in stride(from: 0, to: roleChoiceViews.count, by: 3) {
            let rowViews = Array(roleChoiceViews[rowStart..<min(rowStart + 3, roleChoiceViews.count)])
            let rowStack = NSStackView(views: rowViews)
            rowStack.orientation = .horizontal
            rowStack.alignment = .top
            rowStack.spacing = 8
            roleGridStack.addArrangedSubview(rowStack)
        }

        let roleStack = NSStackView(views: [roleLabel, roleGridStack, roleDetailLabel, rolePerkLabel])
        roleStack.orientation = .vertical
        roleStack.alignment = .leading
        roleStack.spacing = 8

        // Skill Tree
        skillTreeView.onSkillChanged = { [weak self] in
            self?.onSkillChanged?()
        }
        skillTreeView.translatesAutoresizingMaskIntoConstraints = false
        skillTreeView.heightAnchor.constraint(equalToConstant: 500).isActive = true

        // The tree is still being built, so it ships behind a scrim. The overlay
        // covers the tree exactly, which is also what keeps its nodes from being
        // clicked while they are not ready.
        let skillTreeContainer = NSView()
        skillTreeContainer.translatesAutoresizingMaskIntoConstraints = false
        skillTreeContainer.addSubview(skillTreeView)
        skillTreeContainer.addSubview(skillsOverlay)

        NSLayoutConstraint.activate([
            skillTreeView.leadingAnchor.constraint(equalTo: skillTreeContainer.leadingAnchor),
            skillTreeView.trailingAnchor.constraint(equalTo: skillTreeContainer.trailingAnchor),
            skillTreeView.topAnchor.constraint(equalTo: skillTreeContainer.topAnchor),
            skillTreeView.bottomAnchor.constraint(equalTo: skillTreeContainer.bottomAnchor),
            skillsOverlay.leadingAnchor.constraint(equalTo: skillTreeView.leadingAnchor),
            skillsOverlay.trailingAnchor.constraint(equalTo: skillTreeView.trailingAnchor),
            skillsOverlay.topAnchor.constraint(equalTo: skillTreeView.topAnchor),
            skillsOverlay.bottomAnchor.constraint(equalTo: skillTreeView.bottomAnchor)
        ])

        let skillTreeLabel = NSTextField(labelWithString: "")
        skillTreeLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        skillTreeLabel.stringValue = L10n.text(.skills)

        let skillTreeStack = NSStackView(views: [skillTreeLabel, skillTreeContainer])
        skillTreeStack.orientation = .vertical
        skillTreeStack.alignment = .leading
        skillTreeStack.spacing = 8

        // Main stack
        let mainStack = NSStackView(views: [
            roleStack,
            makeSeparator(),
            skillTreeStack
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: mainStack.bottomAnchor, constant: 24),
            skillTreeContainer.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            roleDetailLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            rolePerkLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        refresh()
    }

    func refresh() {
        roleLabel.stringValue = L10n.text(.heroRole)

        let selectedRole = HeroRole.load()
        roleChoiceViews.forEach { $0.refresh(selectedRole: selectedRole) }
        updateRoleDetails(for: selectedRole)

        skillTreeView.refresh()
        skillsOverlay.refresh()
    }

    private func updateRoleDetails(for role: HeroRole) {
        roleDetailLabel.stringValue = role.detail
        rolePerkLabel.stringValue = role.perk
    }

    private func selectRole(_ role: HeroRole) {
        role.save()
        refresh()
        onRoleChanged?()
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }
}

// MARK: - Equipment Settings Tab

final class EquipmentSettingsTab: NSViewController {
    private let scrollView = NSScrollView()
    private let contentView = NSView()

    private let equipmentLabel = NSTextField(labelWithString: "")
    private let equipmentStack = NSStackView()
    private let equipmentOverlay = DevelopmentOverlayView(detail: .inDevelopmentEquipmentDetail)
    private var equipmentRows: [EquipmentRowView] = []

    override func loadView() {
        view = NSView()
        setup()
    }

    private func setup() {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            // Same reason as the game tab: pinning the bottom as well would cap the
            // document at the viewport, so a tall slot list could neither fit nor
            // scroll. Fill the viewport, then grow.
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor)
        ])

        equipmentLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        equipmentStack.orientation = .vertical
        equipmentStack.alignment = .leading
        equipmentStack.spacing = 8

        equipmentRows = EquipmentSlot.allCases.map { slot in
            let row = EquipmentRowView(slot: slot)
            equipmentStack.addArrangedSubview(row)
            return row
        }

        // Equipment is not playable yet either, so the slots ship behind the same
        // scrim as the skill tree - it dims them and, as the frontmost view here,
        // swallows the clicks that would otherwise open a slot.
        let equipmentContainer = NSView()
        equipmentContainer.translatesAutoresizingMaskIntoConstraints = false
        equipmentStack.translatesAutoresizingMaskIntoConstraints = false
        equipmentContainer.addSubview(equipmentStack)
        equipmentContainer.addSubview(equipmentOverlay)

        NSLayoutConstraint.activate([
            equipmentStack.leadingAnchor.constraint(equalTo: equipmentContainer.leadingAnchor),
            equipmentStack.trailingAnchor.constraint(equalTo: equipmentContainer.trailingAnchor),
            equipmentStack.topAnchor.constraint(equalTo: equipmentContainer.topAnchor),
            equipmentStack.bottomAnchor.constraint(equalTo: equipmentContainer.bottomAnchor),
            equipmentOverlay.leadingAnchor.constraint(equalTo: equipmentStack.leadingAnchor),
            equipmentOverlay.trailingAnchor.constraint(equalTo: equipmentStack.trailingAnchor),
            equipmentOverlay.topAnchor.constraint(equalTo: equipmentStack.topAnchor),
            equipmentOverlay.bottomAnchor.constraint(equalTo: equipmentStack.bottomAnchor)
        ])

        let mainStack = NSStackView(views: [equipmentLabel, equipmentContainer])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: mainStack.bottomAnchor, constant: 24),
            equipmentContainer.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        refresh()
    }

    func refresh() {
        equipmentLabel.stringValue = L10n.text(.equipmentSectionTitle)
        equipmentRows.forEach { $0.refresh() }
        equipmentOverlay.refresh()
    }
}

// MARK: - Tools Settings Tab

final class ToolsSettingsTab: NSViewController {
    private let scrollView = NSScrollView()
    private let contentView = NSView()

    private let hooksLabel = NSTextField(labelWithString: "")
    private let hooksDetailLabel = NSTextField(labelWithString: "")
    private let hooksStack = NSStackView()
    private var hookRows: [TokenHookRowView] = []

    override func loadView() {
        view = NSView()
        setup()
    }

    private func setup() {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24)
        ])

        hooksLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        hooksDetailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        hooksDetailLabel.textColor = .secondaryLabelColor
        hooksDetailLabel.lineBreakMode = .byWordWrapping
        hooksDetailLabel.maximumNumberOfLines = 3

        hooksStack.orientation = .vertical
        hooksStack.alignment = .leading
        hooksStack.spacing = 8

        hookRows = CodingToolHook.allCases.map { tool in
            let row = TokenHookRowView(tool: tool)
            row.onInstall = { [weak self] selectedTool in
                self?.installHook(selectedTool)
            }
            hooksStack.addArrangedSubview(row)
            // A leading-aligned vertical stack would otherwise leave each card at
            // its minimum width, squeezing the detail text.
            row.widthAnchor.constraint(equalTo: hooksStack.widthAnchor).isActive = true
            return row
        }

        let mainStack = NSStackView(views: [hooksLabel, hooksDetailLabel, hooksStack])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            hooksDetailLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            hooksStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        refresh()
    }

    func refresh() {
        hooksLabel.stringValue = L10n.text(.tokenHooks)
        hooksDetailLabel.stringValue = L10n.text(.tokenHooksDetail)
        hookRows.forEach { $0.refresh() }
    }

    private func installHook(_ tool: CodingToolHook) {
        do {
            try TokenHookInstaller.install(tool)
            refresh()
        } catch {
            hookRows.first { $0.tool == tool }?.showError(error.localizedDescription)
        }
    }
}

// MARK: - Helper Views

/// Scrim for a settings section that is not ready to be used yet. Sitting on top
/// of the section is what makes it work twice over: it dims the controls and, as
/// the frontmost view in that area, it takes the clicks and scrolls that would
/// otherwise reach them.
private final class DevelopmentOverlayView: NSView {
    private let badgeBackground = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let detailKey: L10nKey

    init(detail: L10nKey) {
        detailKey = detail
        super.init(frame: .zero)
        setup()
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        badgeLabel.stringValue = L10n.text(.inDevelopment)
        detailLabel.stringValue = L10n.text(detailKey)
    }

    private func setup() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.68).cgColor
        layer?.cornerRadius = 8

        badgeBackground.wantsLayer = true
        badgeBackground.translatesAutoresizingMaskIntoConstraints = false
        badgeBackground.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.16).cgColor
        badgeBackground.layer?.borderColor = NSColor.systemOrange.cgColor
        badgeBackground.layer?.borderWidth = 1
        badgeBackground.layer?.cornerRadius = 13
        addSubview(badgeBackground)

        badgeLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        badgeLabel.textColor = .systemOrange
        badgeLabel.alignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeBackground.addSubview(badgeLabel)

        detailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        // Badge and caption move as one block so they stay inside the scrim no
        // matter how short the section is - the equipment slots are under 100pt.
        let contentStack = NSStackView(views: [badgeBackground, detailLabel])
        contentStack.orientation = .vertical
        contentStack.alignment = .centerX
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        let centered = contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        // Centering reads best on a short section, but the skill tree is 500pt
        // tall - a block at its middle only shows up after a long scroll, so it
        // gives way to the cap near the top.
        centered.priority = .defaultLow

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centered,
            contentStack.topAnchor.constraint(lessThanOrEqualTo: topAnchor, constant: 84),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            badgeBackground.heightAnchor.constraint(equalToConstant: 26),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeBackground.leadingAnchor, constant: 14),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeBackground.trailingAnchor, constant: -14),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeBackground.centerYAnchor),
            detailLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32)
        ])
    }
}

private final class TokenHookRowView: NSView {
    let tool: CodingToolHook
    var onInstall: ((CodingToolHook) -> Void)?

    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let installButton = NSButton(title: "", target: nil, action: nil)

    init(tool: CodingToolHook) {
        self.tool = tool
        super.init(frame: .zero)
        setup()
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        let state = TokenHookInstaller.state(for: tool)
        nameLabel.stringValue = tool.displayName
        detailLabel.stringValue = state.detail
        setInstalledMarker(state.isInstalled)
        installButton.title = state.isInstalled ? L10n.text(.hookInstalled) : L10n.text(.installHook)
        installButton.isEnabled = !state.isInstalled
    }

    func showError(_ message: String) {
        detailLabel.stringValue = L10n.string(.hookInstallFailed, message)
        setInstalledMarker(false)
        installButton.title = L10n.text(.installHook)
        installButton.isEnabled = true
    }

    /// The button title already spells out "Installed", so the row only needs a
    /// glance marker beside it - a second green "Installed" label was wide
    /// enough to be drawn on top of the detail text.
    private func setInstalledMarker(_ isInstalled: Bool) {
        statusLabel.stringValue = isInstalled ? "✓" : ""
        statusLabel.toolTip = isInstalled ? L10n.text(.hookInstalled) : nil
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        detailLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        statusLabel.textColor = NSColor.systemGreen
        statusLabel.alignment = .center

        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(install)
        // Without this the row's spare width lands in the button, stretching a
        // one-word title across half the card.
        installButton.setContentHuggingPriority(.required, for: .horizontal)

        [nameLabel, detailLabel, statusLabel, installButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            // Fits one detail line snugly and grows when the text wraps.
            heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 420),

            // Right column: install button with the status marker next to it.
            installButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            installButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            installButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
            statusLabel.trailingAnchor.constraint(equalTo: installButton.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: installButton.centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 16),

            // Text column ends before the marker instead of running under it.
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -12),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -12),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        ])
    }

    @objc private func install() {
        onInstall?(tool)
    }
}

private final class EquipmentRowView: NSView {
    let slot: EquipmentSlot

    private let slotLabel = NSTextField(labelWithString: "")
    private let nameLabel = NSTextField(labelWithString: "")
    private let bonusLabel = NSTextField(labelWithString: "")

    init(slot: EquipmentSlot) {
        self.slot = slot
        super.init(frame: .zero)
        setup()
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        slotLabel.stringValue = slot.name
        if let equipped = ItemSystem.equippedDrop(for: slot) {
            nameLabel.stringValue = equipped.displayName
            nameLabel.textColor = equipped.rarity.color
            bonusLabel.stringValue = slot.bonusText(for: equipped.rarity)
        } else {
            nameLabel.stringValue = "—"
            nameLabel.textColor = .secondaryLabelColor
            bonusLabel.stringValue = ""
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        slotLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        bonusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        bonusLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [slotLabel, nameLabel, bonusLabel])
        textStack.orientation = .horizontal
        textStack.alignment = .firstBaseline
        textStack.spacing = 12
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }
}

private final class RoleChoiceView: NSView {
    let role: HeroRole
    var onSelected: ((HeroRole) -> Void)?

    private let actorView = PixelActorView(kind: .hero)
    private let nameLabel = NSTextField(labelWithString: "")
    private let perkLabel = NSTextField(labelWithString: "")
    private let clickButton = NSButton(title: "", target: nil, action: nil)

    init(role: HeroRole) {
        self.role = role
        super.init(frame: .zero)
        setup()
        refresh(selectedRole: HeroRole.load())
    }

    required init?(coder: NSCoder) { nil }

    func refresh(selectedRole: HeroRole) {
        actorView.heroRole = role
        nameLabel.stringValue = role.label
        perkLabel.stringValue = role.perk
        let isSelected = selectedRole == role
        layer?.borderColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        layer?.borderWidth = isSelected ? 2 : 1
        layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.13).cgColor
            : NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        actorView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        perkLabel.translatesAutoresizingMaskIntoConstraints = false
        clickButton.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail

        perkLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        perkLabel.textColor = .secondaryLabelColor
        perkLabel.alignment = .center
        perkLabel.lineBreakMode = .byTruncatingTail
        perkLabel.maximumNumberOfLines = 1

        clickButton.isBordered = false
        clickButton.target = self
        clickButton.action = #selector(selectRole)

        addSubview(actorView)
        addSubview(nameLabel)
        addSubview(perkLabel)
        addSubview(clickButton)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 136),
            heightAnchor.constraint(equalToConstant: 86),
            actorView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            actorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            actorView.widthAnchor.constraint(equalToConstant: 34),
            actorView.heightAnchor.constraint(equalToConstant: 34),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: actorView.bottomAnchor, constant: 5),
            nameLabel.heightAnchor.constraint(equalToConstant: 15),
            perkLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            perkLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            perkLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            perkLabel.heightAnchor.constraint(equalToConstant: 13),
            clickButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            clickButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            clickButton.topAnchor.constraint(equalTo: topAnchor),
            clickButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func selectRole() {
        onSelected?(role)
    }
}

private final class BackdropChoiceView: NSView {
    let backdrop: BattleBackdrop
    var onSelected: ((BattleBackdrop) -> Void)?

    private let previewView = BackdropView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let clickButton = NSButton(title: "", target: nil, action: nil)

    init(backdrop: BattleBackdrop) {
        self.backdrop = backdrop
        super.init(frame: .zero)
        setup()
        previewView.backdrop = backdrop
        nameLabel.stringValue = backdrop.name
        refreshSelection()
    }

    required init?(coder: NSCoder) { nil }

    func refreshSelection() {
        nameLabel.stringValue = backdrop.name
        let isSelected = BattleBackdrop.load() == backdrop
        layer?.borderColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        layer?.borderWidth = isSelected ? 2 : 1
        layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.13).cgColor
            : NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        previewView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        clickButton.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail

        clickButton.isBordered = false
        clickButton.target = self
        clickButton.action = #selector(selectBackdrop)

        addSubview(previewView)
        addSubview(nameLabel)
        addSubview(clickButton)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 104),
            heightAnchor.constraint(equalToConstant: 72),
            previewView.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            previewView.centerXAnchor.constraint(equalTo: centerXAnchor),
            previewView.widthAnchor.constraint(equalToConstant: 90),
            previewView.heightAnchor.constraint(equalToConstant: 38),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            nameLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 4),
            nameLabel.heightAnchor.constraint(equalToConstant: 14),
            clickButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            clickButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            clickButton.topAnchor.constraint(equalTo: topAnchor),
            clickButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func selectBackdrop() {
        onSelected?(backdrop)
    }
}

// MARK: - Sessions Settings Tab

final class SessionsSettingsTab: NSViewController {
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let sessionListView = SessionListView()
    private var refreshTimer: Timer?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        setupUI()
        startMonitoring()
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        view.addSubview(scrollView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        sessionListView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sessionListView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            // The clip view is not flipped, so a document view shorter than the
            // viewport sits at its bottom edge - that is what left a screen of
            // blank space above the list. Filling the viewport pins it to the top,
            // and taller content still scrolls.
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            sessionListView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            sessionListView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sessionListView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: sessionListView.bottomAnchor, constant: 16)
        ])

        refresh()
    }

    private func startMonitoring() {
        SessionMonitor.shared.addObserver(self) { [weak self] sessions in
            Task { @MainActor in
                self?.sessionListView.updateSessions(sessions)
            }
        }
        SessionMonitor.shared.startMonitoring()

        // Refresh every 10 seconds (reduced frequency to prevent UI lag)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { @MainActor in
                SessionMonitor.shared.refreshIfNeeded()
            }
        }
    }

    func refresh() {
        titleLabel.stringValue = L10n.text(.activeSessions)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
