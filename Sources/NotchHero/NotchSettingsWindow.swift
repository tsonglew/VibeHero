import AppKit

final class NotchSettingsWindow: NSWindow {
    private let settingsView = NotchSettingsView()

    var onRoleChanged: (() -> Void)? {
        get { settingsView.onRoleChanged }
        set { settingsView.onRoleChanged = newValue }
    }

    var onDisplayChanged: (() -> Void)? {
        get { settingsView.onDisplayChanged }
        set { settingsView.onDisplayChanged = newValue }
    }

    var onSkillChanged: (() -> Void)? {
        get { settingsView.onSkillChanged }
        set { settingsView.onSkillChanged = newValue }
    }

    var onBackdropChanged: (() -> Void)? {
        get { settingsView.onBackdropChanged }
        set { settingsView.onBackdropChanged = newValue }
    }

    var onFullScreenHideChanged: (() -> Void)? {
        get { settingsView.onFullScreenHideChanged }
        set { settingsView.onFullScreenHideChanged = newValue }
    }

    var onLanguageChanged: (() -> Void)? {
        get { settingsView.onLanguageChanged }
        set { settingsView.onLanguageChanged = newValue }
    }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = L10n.text(.settingsTitle)
        isReleasedWhenClosed = false
        contentMinSize = NSSize(width: 460, height: 500)
        contentView = settingsView
    }

    func refresh() {
        title = L10n.text(.settingsTitle)
        settingsView.refresh()
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

private final class NotchSettingsView: NSView {
    var onRoleChanged: (() -> Void)?
    var onDisplayChanged: (() -> Void)?
    var onSkillChanged: (() -> Void)?
    var onLanguageChanged: (() -> Void)?
    var onBackdropChanged: (() -> Void)?
    var onFullScreenHideChanged: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let languagePopup = NSPopUpButton()
    private let roleLabel = NSTextField(labelWithString: "")
    private let roleDetailLabel = NSTextField(labelWithString: "")
    private let rolePerkLabel = NSTextField(labelWithString: "")
    private let roleGridStack = NSStackView()
    private let displayLabel = NSTextField(labelWithString: "")
    private let displayPopup = NSPopUpButton()
    private let displayDetailLabel = NSTextField(labelWithString: "")
    private let fullScreenLabel = NSTextField(labelWithString: "")
    private let fullScreenToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fullScreenDetailLabel = NSTextField(labelWithString: "")
    private let backdropLabel = NSTextField(labelWithString: "")
    private let backdropRowStack = NSStackView()
    private let skillsLabel = NSTextField(labelWithString: "")
    private let skillPointsLabel = NSTextField(labelWithString: "")
    private let skillStack = NSStackView()
    private let hooksLabel = NSTextField(labelWithString: "")
    private let hooksDetailLabel = NSTextField(labelWithString: "")
    private let hooksStack = NSStackView()
    private let equipmentLabel = NSTextField(labelWithString: "")
    private let equipmentStack = NSStackView()
    private let scrollView = NSScrollView()
    private var roleChoiceViews: [RoleChoiceView] = []
    private var skillRows: [SkillRowView] = []
    private var hookRows: [TokenHookRowView] = []
    private var equipmentRows: [EquipmentRowView] = []
    private var backdropChoiceViews: [BackdropChoiceView] = []
    private var displayIDs: [Int?] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
        refresh()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func refresh() {
        refreshRoleOptions()
        refreshDisplayOptions()
        refreshSkillOptions()
        refreshLanguageOptions()
        refreshFullScreenOption()
        applyLocalizedText()
        equipmentRows.forEach { $0.refresh() }
        backdropChoiceViews.forEach { $0.refreshSelection() }
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        languageLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        roleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        displayLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        fullScreenLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        skillsLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        hooksLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        equipmentLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        backdropLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        [roleDetailLabel, rolePerkLabel, displayDetailLabel, fullScreenDetailLabel, skillPointsLabel, hooksDetailLabel].forEach {
            $0.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            $0.textColor = .secondaryLabelColor
            $0.lineBreakMode = .byWordWrapping
            $0.maximumNumberOfLines = 2
        }

        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        displayPopup.target = self
        displayPopup.action = #selector(displayChanged)
        fullScreenToggle.target = self
        fullScreenToggle.action = #selector(fullScreenHideChanged)

        let languageStack = NSStackView(views: [languageLabel, languagePopup])
        languageStack.orientation = .vertical
        languageStack.alignment = .leading
        languageStack.spacing = 8
        languagePopup.translatesAutoresizingMaskIntoConstraints = false
        languagePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        roleChoiceViews = HeroRole.allCases.map { role in
            let choiceView = RoleChoiceView(role: role)
            choiceView.onSelected = { [weak self] selectedRole in
                self?.selectRole(selectedRole)
            }
            return choiceView
        }

        roleGridStack.orientation = .vertical
        roleGridStack.alignment = .leading
        roleGridStack.spacing = 8
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

        let displayStack = NSStackView(views: [displayLabel, displayPopup, displayDetailLabel])
        displayStack.orientation = .vertical
        displayStack.alignment = .leading
        displayStack.spacing = 8
        displayPopup.translatesAutoresizingMaskIntoConstraints = false
        displayPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

        let fullScreenStack = NSStackView(views: [fullScreenLabel, fullScreenToggle, fullScreenDetailLabel])
        fullScreenStack.orientation = .vertical
        fullScreenStack.alignment = .leading
        fullScreenStack.spacing = 8

        backdropChoiceViews = BattleBackdrop.allCases.map { backdrop in
            let choiceView = BackdropChoiceView(backdrop: backdrop)
            choiceView.onSelected = { [weak self] selectedBackdrop in
                self?.selectBackdrop(selectedBackdrop)
            }
            return choiceView
        }
        backdropRowStack.orientation = .horizontal
        backdropRowStack.alignment = .top
        backdropRowStack.spacing = 8
        backdropChoiceViews.forEach { backdropRowStack.addArrangedSubview($0) }

        let backdropStack = NSStackView(views: [backdropLabel, backdropRowStack])
        backdropStack.orientation = .vertical
        backdropStack.alignment = .leading
        backdropStack.spacing = 8

        skillStack.orientation = .vertical
        skillStack.alignment = .leading
        skillStack.spacing = 10
        skillRows = HeroSkill.allCases.map { skill in
            let row = SkillRowView(skill: skill)
            row.onUpgrade = { [weak self] selectedSkill in
                self?.upgrade(selectedSkill)
            }
            row.onAutoCastChanged = { [weak self] selectedSkill, enabled in
                SkillProgress.setAutoCastEnabled(enabled, for: selectedSkill)
                self?.refreshSkillOptions()
                self?.onSkillChanged?()
            }
            return row
        }
        skillRows.forEach { skillStack.addArrangedSubview($0) }

        let skillsStack = NSStackView(views: [skillsLabel, skillPointsLabel, skillStack])
        skillsStack.orientation = .vertical
        skillsStack.alignment = .leading
        skillsStack.spacing = 8

        equipmentStack.orientation = .vertical
        equipmentStack.alignment = .leading
        equipmentStack.spacing = 8
        equipmentRows = EquipmentSlot.allCases.map { slot in
            let row = EquipmentRowView(slot: slot)
            equipmentStack.addArrangedSubview(row)
            return row
        }

        let equipmentSectionStack = NSStackView(views: [equipmentLabel, equipmentStack])
        equipmentSectionStack.orientation = .vertical
        equipmentSectionStack.alignment = .leading
        equipmentSectionStack.spacing = 8

        hooksStack.orientation = .vertical
        hooksStack.alignment = .leading
        hooksStack.spacing = 8
        hookRows = CodingToolHook.allCases.map { tool in
            let row = TokenHookRowView(tool: tool)
            row.onInstall = { [weak self] selectedTool in
                self?.installHook(selectedTool)
            }
            hooksStack.addArrangedSubview(row)
            return row
        }

        let hookSettingsStack = NSStackView(views: [hooksLabel, hooksDetailLabel, hooksStack])
        hookSettingsStack.orientation = .vertical
        hookSettingsStack.alignment = .leading
        hookSettingsStack.spacing = 8

        let contentStack = NSStackView(views: [
            titleLabel,
            makeSeparator(),
            languageStack,
            makeSeparator(),
            roleStack,
            makeSeparator(),
            displayStack,
            makeSeparator(),
            fullScreenStack,
            makeSeparator(),
            backdropStack,
            makeSeparator(),
            hookSettingsStack,
            makeSeparator(),
            skillsStack,
            makeSeparator(),
            equipmentSectionStack
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 22),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -24),
            roleDetailLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            rolePerkLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            roleGridStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            displayDetailLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            fullScreenDetailLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            hooksDetailLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            hooksStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            skillPointsLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            skillStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            equipmentStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])
    }

    private func refreshRoleOptions() {
        let selectedRole = HeroRole.load()
        roleChoiceViews.forEach { $0.refresh(selectedRole: selectedRole) }
        updateRoleDetails(for: selectedRole)
    }

    private func refreshDisplayOptions() {
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
    }

    private func refreshLanguageOptions() {
        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: AppLanguage.allCases.map(\.displayName))
        let selectedLanguage = AppLanguage.load()
        languagePopup.selectItem(at: AppLanguage.allCases.firstIndex(of: selectedLanguage) ?? 0)
    }

    private func applyLocalizedText() {
        titleLabel.stringValue = L10n.text(.settingsTitle)
        languageLabel.stringValue = L10n.text(.language)
        roleLabel.stringValue = L10n.text(.heroRole)
        displayLabel.stringValue = L10n.text(.display)
        fullScreenLabel.stringValue = L10n.text(.fullScreen)
        fullScreenToggle.title = L10n.text(.hideInFullScreen)
        fullScreenDetailLabel.stringValue = L10n.text(.hideInFullScreenDetail)
        skillsLabel.stringValue = L10n.text(.skills)
        hooksLabel.stringValue = L10n.text(.tokenHooks)
        hooksDetailLabel.stringValue = L10n.text(.tokenHooksDetail)
        equipmentLabel.stringValue = L10n.text(.equipmentSectionTitle)
        backdropLabel.stringValue = L10n.text(.backdrop)
        hookRows.forEach { $0.refresh() }
    }

    @objc private func languageChanged() {
        let index = languagePopup.indexOfSelectedItem
        guard AppLanguage.allCases.indices.contains(index) else {
            return
        }

        AppLanguage.save(AppLanguage.allCases[index])
        refresh()
        onLanguageChanged?()
    }

    @objc private func displayChanged() {
        let index = displayPopup.indexOfSelectedItem
        let selectedDisplayID = displayIDs.indices.contains(index) ? displayIDs[index] : nil
        ScreenPinning.save(selectedDisplayID)
        refreshDisplayOptions()
        onDisplayChanged?()
    }

    private func refreshFullScreenOption() {
        fullScreenToggle.state = FullScreenHidePreference.load() ? .on : .off
    }

    @objc private func fullScreenHideChanged() {
        FullScreenHidePreference.save(fullScreenToggle.state == .on)
        onFullScreenHideChanged?()
    }

    private func refreshSkillOptions() {
        let heroLevel = SkillProgress.loadHeroLevel()
        skillPointsLabel.stringValue = "LV \(heroLevel) · \(SkillProgress.statusText(heroLevel: heroLevel))"
        skillRows.forEach { $0.refresh(heroLevel: heroLevel) }
    }

    private func upgrade(_ skill: HeroSkill) {
        let heroLevel = SkillProgress.loadHeroLevel()
        guard SkillProgress.upgrade(skill, heroLevel: heroLevel) else {
            return
        }

        refreshSkillOptions()
        onSkillChanged?()
    }

    private func installHook(_ tool: CodingToolHook) {
        do {
            try TokenHookInstaller.install(tool)
            hookRows.forEach { $0.refresh() }
        } catch {
            hookRows.first { $0.tool == tool }?.showError(error.localizedDescription)
        }
    }

    private func updateRoleDetails(for role: HeroRole) {
        roleDetailLabel.stringValue = role.detail
        rolePerkLabel.stringValue = role.perk
    }

    private func selectRole(_ role: HeroRole) {
        role.save()
        roleChoiceViews.forEach { $0.refresh(selectedRole: role) }
        updateRoleDetails(for: role)
        onRoleChanged?()
    }

    private func selectBackdrop(_ backdrop: BattleBackdrop) {
        backdrop.save()
        backdropChoiceViews.forEach { $0.refreshSelection() }
        onBackdropChanged?()
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
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

    required init?(coder: NSCoder) {
        nil
    }

    func refresh() {
        let state = TokenHookInstaller.state(for: tool)
        nameLabel.stringValue = tool.displayName
        detailLabel.stringValue = state.detail
        statusLabel.stringValue = state.isInstalled ? L10n.text(.hookInstalled) : ""
        installButton.title = state.isInstalled ? L10n.text(.hookInstalled) : L10n.text(.installHook)
        installButton.isEnabled = !state.isInstalled
    }

    func showError(_ message: String) {
        detailLabel.stringValue = L10n.string(.hookInstallFailed, message)
        statusLabel.stringValue = ""
        installButton.title = L10n.text(.installHook)
        installButton.isEnabled = true
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
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = NSColor.systemGreen
        statusLabel.alignment = .right

        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(install)

        [nameLabel, detailLabel, statusLabel, installButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: installButton.leadingAnchor, constant: -12),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: installButton.leadingAnchor, constant: -12),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            installButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            installButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            installButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
            statusLabel.trailingAnchor.constraint(equalTo: installButton.leadingAnchor, constant: -10),
            statusLabel.centerYAnchor.constraint(equalTo: installButton.centerYAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
    }

    @objc private func install() {
        onInstall?(tool)
    }
}

private final class SkillRowView: NSView {
    let skill: HeroSkill
    var onUpgrade: ((HeroSkill) -> Void)?
    var onAutoCastChanged: ((HeroSkill, Bool) -> Void)?

    private let nameLabel = NSTextField(labelWithString: "")
    private let rankLabel = NSTextField(labelWithString: "")
    private let tierLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let requirementLabel = NSTextField(labelWithString: "")
    private let effectLabel = NSTextField(labelWithString: "")
    private let previewView: SkillPreviewView
    private let upgradeButton = NSButton(title: "", target: nil, action: nil)
    private let autoCastCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    init(skill: HeroSkill) {
        self.skill = skill
        self.previewView = SkillPreviewView(skill: skill)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func refresh(heroLevel: Int) {
        let rank = SkillProgress.rank(for: skill)
        nameLabel.stringValue = skill.name
        rankLabel.stringValue = heroLevel >= skill.unlockLevel ? skill.rankText(rank) : skill.lockedText
        tierLabel.stringValue = L10n.string(.tier, skill.treeTier)
        summaryLabel.stringValue = skill.summary
        requirementLabel.stringValue = L10n.string(.requiresPrefix, skill.requirementText)
        effectLabel.stringValue = L10n.string(.effectPrefix, skill.effectText)
        previewView.rank = rank
        previewView.isLocked = heroLevel < skill.unlockLevel || rank <= 0
        autoCastCheckbox.title = L10n.text(.autoCast)
        autoCastCheckbox.isEnabled = rank > 0
        autoCastCheckbox.state = SkillProgress.isAutoCastEnabled(skill) ? .on : .off

        let canUpgrade = SkillProgress.canUpgrade(skill, heroLevel: heroLevel)
        upgradeButton.isEnabled = canUpgrade
        if let missing = SkillProgress.missingRequirementText(for: skill, heroLevel: heroLevel) {
            upgradeButton.title = missing == skill.lockedText ? L10n.text(.locked) : L10n.text(.requiresButton)
        } else if rank <= 0 {
            upgradeButton.title = L10n.text(.unlock)
        } else if rank >= skill.maxRank {
            upgradeButton.title = L10n.text(.maxed)
        } else {
            upgradeButton.title = L10n.text(.upgrade)
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        rankLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        rankLabel.textColor = .secondaryLabelColor
        tierLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        tierLabel.textColor = NSColor.controlAccentColor
        [summaryLabel, requirementLabel, effectLabel].forEach {
            $0.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            $0.textColor = .secondaryLabelColor
            $0.lineBreakMode = .byWordWrapping
            $0.maximumNumberOfLines = 2
        }

        upgradeButton.target = self
        upgradeButton.action = #selector(upgrade)
        upgradeButton.bezelStyle = .rounded
        upgradeButton.translatesAutoresizingMaskIntoConstraints = false
        upgradeButton.widthAnchor.constraint(equalToConstant: 86).isActive = true
        autoCastCheckbox.target = self
        autoCastCheckbox.action = #selector(autoCastChanged)
        autoCastCheckbox.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        autoCastCheckbox.translatesAutoresizingMaskIntoConstraints = false
        autoCastCheckbox.widthAnchor.constraint(equalToConstant: 96).isActive = true
        previewView.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = NSStackView(views: [nameLabel, rankLabel, tierLabel])
        titleStack.orientation = .horizontal
        titleStack.alignment = .firstBaseline
        titleStack.spacing = 8

        let textStack = NSStackView(views: [titleStack, summaryLabel, requirementLabel, effectLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let actionStack = NSStackView(views: [previewView, autoCastCheckbox, upgradeButton])
        actionStack.orientation = .vertical
        actionStack.alignment = .trailing
        actionStack.spacing = 5

        let rowStack = NSStackView(views: [textStack, actionStack])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 14
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            previewView.widthAnchor.constraint(equalToConstant: 58),
            previewView.heightAnchor.constraint(equalToConstant: 42),
            summaryLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 330),
            requirementLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 330),
            effectLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 330)
        ])
    }

    @objc private func upgrade() {
        onUpgrade?(skill)
    }

    @objc private func autoCastChanged() {
        onAutoCastChanged?(skill, autoCastCheckbox.state == .on)
    }
}

private final class SkillPreviewView: NSView {
    let skill: HeroSkill

    var rank: Int = 0 {
        didSet { needsDisplay = true }
    }

    var isLocked: Bool = true {
        didSet { needsDisplay = true }
    }

    init(skill: HeroSkill) {
        self.skill = skill
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let activeRank = max(1, rank)
        let color = previewColor.withAlphaComponent(isLocked ? 0.36 : 1.0)

        NSColor.controlBackgroundColor.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
        NSColor.separatorColor.withAlphaComponent(isLocked ? 0.22 : 0.55).setStroke()
        NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).stroke()

        switch skill {
        case .pulseBlade:
            drawPulseBlade(color: color, rank: activeRank)
        case .tokenVolley:
            drawTokenVolley(color: color, rank: activeRank)
        case .arcBurst:
            drawArcBurst(color: color, rank: activeRank)
        case .wraithMark:
            drawWraithMark(color: color, rank: activeRank)
        case .novaStorm:
            drawNovaStorm(color: color, rank: activeRank)
        case .overclockCore:
            drawOverclockCore(color: color, rank: activeRank)
        }
    }

    private var previewColor: NSColor {
        switch skill {
        case .pulseBlade:
            NSColor(red: 1.0, green: 0.86, blue: 0.28, alpha: 1)
        case .tokenVolley:
            NSColor(red: 0.0, green: 0.90, blue: 0.82, alpha: 1)
        case .arcBurst:
            NSColor(red: 0.48, green: 0.74, blue: 1.0, alpha: 1)
        case .wraithMark:
            NSColor(red: 1.0, green: 0.42, blue: 0.52, alpha: 1)
        case .novaStorm:
            NSColor(red: 0.78, green: 0.52, blue: 1.0, alpha: 1)
        case .overclockCore:
            NSColor(red: 0.28, green: 1.0, blue: 0.52, alpha: 1)
        }
    }

    private func drawPulseBlade(color: NSColor, rank: Int) {
        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = CGFloat(2 + rank)
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: 16, y: 31))
        path.curve(
            to: NSPoint(x: 42, y: 10),
            controlPoint1: NSPoint(x: 23, y: 22),
            controlPoint2: NSPoint(x: 35, y: 17)
        )
        path.stroke()
    }

    private func drawTokenVolley(color: NSColor, rank: Int) {
        for index in 0..<(rank + 1) {
            let y = CGFloat(14 + index * 7)
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: 15 + CGFloat(index * 2), y: y, width: 22, height: 5), xRadius: 2, yRadius: 2).fill()
            color.withAlphaComponent(0.30).setFill()
            NSBezierPath(rect: NSRect(x: 9, y: y + 1, width: 8, height: 3)).fill()
        }
    }

    private func drawArcBurst(color: NSColor, rank: Int) {
        color.setStroke()
        for index in 0..<rank {
            let path = NSBezierPath()
            path.lineWidth = 1.8
            let offset = CGFloat(index * 5)
            path.move(to: NSPoint(x: 12, y: 17 + offset))
            path.curve(
                to: NSPoint(x: 45, y: 15 + offset),
                controlPoint1: NSPoint(x: 20, y: 6 + offset),
                controlPoint2: NSPoint(x: 34, y: 29 - offset)
            )
            path.stroke()
        }
    }

    private func drawWraithMark(color: NSColor, rank: Int) {
        color.setStroke()
        let radius = CGFloat(8 + rank * 2)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let path = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        path.lineWidth = 1.6
        path.stroke()
        let cross = NSBezierPath()
        cross.lineWidth = 1.4
        cross.move(to: NSPoint(x: center.x - radius * 0.6, y: center.y))
        cross.line(to: NSPoint(x: center.x + radius * 0.6, y: center.y))
        cross.move(to: NSPoint(x: center.x, y: center.y - radius * 0.6))
        cross.line(to: NSPoint(x: center.x, y: center.y + radius * 0.6))
        cross.stroke()
    }

    private func drawNovaStorm(color: NSColor, rank: Int) {
        color.setStroke()
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        for index in 0..<rank {
            let radius = CGFloat(9 + index * 5)
            let path = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            path.lineWidth = 1.5
            path.stroke()
        }
        drawSpark(center: center, color: color)
    }

    private func drawOverclockCore(color: NSColor, rank: Int) {
        color.setStroke()
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let core = NSBezierPath(ovalIn: NSRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14))
        core.lineWidth = 2
        core.stroke()
        for index in 0..<(4 + rank * 2) {
            let angle = CGFloat(index) / CGFloat(4 + rank * 2) * CGFloat.pi * 2
            let start = NSPoint(x: center.x + cos(angle) * 12, y: center.y + sin(angle) * 12)
            let end = NSPoint(x: center.x + cos(angle) * 18, y: center.y + sin(angle) * 18)
            let path = NSBezierPath()
            path.lineWidth = 1.4
            path.move(to: start)
            path.line(to: end)
            path.stroke()
        }
    }

    private func drawSpark(center: NSPoint, color: NSColor) {
        let path = NSBezierPath()
        path.lineWidth = 1.3
        path.move(to: NSPoint(x: center.x - 14, y: center.y))
        path.line(to: NSPoint(x: center.x + 14, y: center.y))
        path.move(to: NSPoint(x: center.x, y: center.y - 14))
        path.line(to: NSPoint(x: center.x, y: center.y + 14))
        color.setStroke()
        path.stroke()
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

    required init?(coder: NSCoder) {
        nil
    }

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

    required init?(coder: NSCoder) {
        nil
    }

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

    required init?(coder: NSCoder) {
        nil
    }

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
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false

        slotLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        bonusLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        bonusLabel.textColor = .secondaryLabelColor
        bonusLabel.alignment = .right

        [slotLabel, nameLabel, bonusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
            slotLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            slotLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            slotLabel.widthAnchor.constraint(equalToConstant: 76),
            nameLabel.leadingAnchor.constraint(equalTo: slotLabel.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            bonusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 10),
            bonusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bonusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
