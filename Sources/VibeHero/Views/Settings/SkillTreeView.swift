import AppKit

/// The tree and active catalog spend the same points. Native buttons provide
/// keyboard/VoiceOver access while the canvas only draws the dependency lines.
final class SkillTreeView: NSView {
    private let pointsLabel = NSTextField(labelWithString: "")
    private let budgetLabel = NSTextField(wrappingLabelWithString: "")
    private let migrationLabel = NSTextField(wrappingLabelWithString: "")
    private let acknowledgeButton = NSButton()
    private let modeSelector = NSSegmentedControl()
    private let categorySelector = NSSegmentedControl()
    private let treeScrollView = NSScrollView()
    let treeCanvas = SkillTreeCanvas()
    let detailPanel = SkillTreeDetailPanel()
    private let activeScrollView = NSScrollView()
    private let activeDocument = SkillFlippedView()
    private let activeHelpLabel = NSTextField(wrappingLabelWithString: "")
    private var activeRows: [ActiveSkillRow] = []
    private var selectedCategory: SkillTreeCategory = .attack
    private var needsInitialTreePosition = true

    var onSkillChanged: (() -> Void)?
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1).cgColor
        layer?.cornerRadius = 8
        // This is a deliberately dark canvas inside otherwise native settings.
        appearance = NSAppearance(named: .darkAqua)
        pointsLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        for label in [pointsLabel, budgetLabel, migrationLabel, activeHelpLabel] {
            label.textColor = .white.withAlphaComponent(label === pointsLabel ? 1 : 0.74)
            if label !== pointsLabel { label.font = .systemFont(ofSize: 11) }
        }
        modeSelector.segmentCount = 2
        modeSelector.selectedSegment = 0
        modeSelector.target = self
        modeSelector.action = #selector(modeChanged)
        categorySelector.segmentCount = SkillTreeCategory.allCases.count
        categorySelector.selectedSegment = 0
        categorySelector.target = self
        categorySelector.action = #selector(categoryChanged)
        acknowledgeButton.bezelStyle = .rounded
        acknowledgeButton.target = self
        acknowledgeButton.action = #selector(acknowledgeMigration)
        for child in [pointsLabel, budgetLabel, migrationLabel, acknowledgeButton, modeSelector,
                      categorySelector, treeScrollView, detailPanel, activeScrollView] as [NSView] {
            addSubview(child)
        }
        treeScrollView.documentView = treeCanvas
        treeScrollView.hasHorizontalScroller = true
        treeScrollView.autohidesScrollers = true
        treeScrollView.drawsBackground = false
        treeCanvas.onNodeSelected = { [weak self] node in self?.detailPanel.showNode(node) }
        detailPanel.onUpgrade = { [weak self] in self?.changed() }
        activeScrollView.documentView = activeDocument
        activeScrollView.hasVerticalScroller = true
        activeScrollView.autohidesScrollers = true
        activeScrollView.drawsBackground = false
        activeDocument.addSubview(activeHelpLabel)
        activeRows = HeroSkill.allCases.map { skill in
            let row = ActiveSkillRow(skill: skill)
            row.onChanged = { [weak self] in self?.changed() }
            activeDocument.addSubview(row)
            return row
        }
        refresh()
        treeCanvas.selectNode(id: SkillTreeData.nodes(for: .attack).first?.id)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let padding: CGFloat = 16
        let width = max(0, bounds.width - padding * 2)
        pointsLabel.frame = NSRect(x: padding, y: 12, width: width, height: 20)
        budgetLabel.frame = NSRect(x: padding, y: 36, width: width, height: 38)
        var y: CGFloat = 82
        if !migrationLabel.isHidden {
            migrationLabel.frame = NSRect(x: padding, y: y, width: max(100, width - 92), height: 76)
            acknowledgeButton.frame = NSRect(x: bounds.width - padding - 84, y: y + 8, width: 84, height: 30)
            y += 84
        }
        modeSelector.frame = NSRect(x: padding, y: y, width: width, height: 28)
        y += 38
        activeScrollView.frame = NSRect(x: padding, y: y, width: width, height: max(0, bounds.height - y - padding))
        categorySelector.frame = NSRect(x: padding, y: y, width: width, height: 28)
        y += 36
        treeScrollView.frame = NSRect(x: padding, y: y, width: width, height: 282)
        let canvasWidth = max(480, treeScrollView.contentSize.width)
        treeCanvas.frame = NSRect(x: 0, y: 0, width: canvasWidth, height: 270)
        treeCanvas.layoutSubtreeIfNeeded()
        if needsInitialTreePosition, treeScrollView.contentSize.width > 0 {
            treeScrollView.contentView.scroll(to: CGPoint(x: max(0, (canvasWidth - treeScrollView.contentSize.width) / 2), y: 0))
            treeScrollView.reflectScrolledClipView(treeScrollView.contentView)
            needsInitialTreePosition = false
        }
        y += 290
        detailPanel.frame = NSRect(x: padding, y: y, width: width, height: max(230, bounds.height - y - padding))
        let activeWidth = max(0, activeScrollView.contentSize.width)
        activeHelpLabel.frame = NSRect(x: 0, y: 0, width: activeWidth, height: 66)
        var rowY: CGFloat = 76
        for row in activeRows {
            row.frame = NSRect(x: 0, y: rowY, width: activeWidth, height: 194)
            rowY += 204
        }
        activeDocument.frame = NSRect(x: 0, y: 0, width: activeWidth, height: max(rowY, activeScrollView.contentSize.height))
    }

    func refresh() {
        pointsLabel.stringValue = L10n.string(.availableSkillPoints, SkillTreeProgress.availablePoints())
        budgetLabel.stringValue = L10n.text(.skillSharedBudget)
        migrationLabel.stringValue = L10n.string(.skillMigrationMessage, SkillTreeProgress.migrationCredit)
        migrationLabel.isHidden = !SkillTreeProgress.migrationNoticePending
        acknowledgeButton.isHidden = migrationLabel.isHidden
        acknowledgeButton.title = L10n.text(.skillMigrationAcknowledged)
        modeSelector.setLabel(L10n.text(.skillPassiveTree), forSegment: 0)
        modeSelector.setLabel(L10n.text(.skillActiveSkills), forSegment: 1)
        for (index, category) in SkillTreeCategory.allCases.enumerated() {
            categorySelector.setLabel(category.displayName, forSegment: index)
        }
        treeCanvas.category = selectedCategory
        treeCanvas.refresh()
        detailPanel.refresh()
        activeHelpLabel.stringValue = L10n.text(.autoCastPriorityDetail)
        activeRows.forEach { $0.refresh() }
        updateMode()
        needsLayout = true
    }

    private func changed() {
        refresh()
        onSkillChanged?()
    }

    @objc private func acknowledgeMigration() {
        SkillTreeProgress.dismissMigrationNotice()
        refresh()
    }

    @objc private func modeChanged() { updateMode() }

    private func updateMode() {
        let active = modeSelector.selectedSegment == 1
        activeScrollView.isHidden = !active
        categorySelector.isHidden = active
        treeScrollView.isHidden = active
        detailPanel.isHidden = active
    }

    @objc private func categoryChanged() {
        guard SkillTreeCategory.allCases.indices.contains(categorySelector.selectedSegment) else { return }
        selectedCategory = SkillTreeCategory.allCases[categorySelector.selectedSegment]
        treeCanvas.category = selectedCategory
        treeCanvas.selectNode(id: SkillTreeData.nodes(for: selectedCategory).first?.id)
        needsInitialTreePosition = true
        needsLayout = true
    }
}

private final class SkillFlippedView: NSView {
    override var isFlipped: Bool { true }
}

private final class SkillNodeButton: NSButton {
    let nodeID: String
    init(nodeID: String) {
        self.nodeID = nodeID
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 8
        setButtonType(.momentaryPushIn)
    }
    required init?(coder: NSCoder) { nil }
}

final class SkillTreeCanvas: NSView {
    var category: SkillTreeCategory = .attack {
        didSet { if category != oldValue { rebuild() } }
    }
    var onNodeSelected: ((SkillTreeNode) -> Void)?
    private var selectedNodeID: String?
    private var buttons: [SkillNodeButton] = []
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        rebuild()
    }
    required init?(coder: NSCoder) { nil }

    private func rebuild() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = SkillTreeData.nodes(for: category).map { node in
            let button = SkillNodeButton(nodeID: node.id)
            button.target = self
            button.action = #selector(nodePressed(_:))
            addSubview(button)
            return button
        }
        refresh()
    }

    func refresh() {
        for button in buttons {
            guard let node = SkillTreeData.node(byID: button.nodeID) else { continue }
            let rank = node.currentLevel
            let text = "\(node.name)\n\(L10n.string(.currentLevel, rank, node.maxLevel))"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byWordWrapping
            button.attributedTitle = NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(node.isUnlocked || rank > 0 ? 1 : 0.62),
                .paragraphStyle: paragraph
            ])
            button.layer?.backgroundColor = category.color.withAlphaComponent(rank > 0 ? 0.32 : 0.10).cgColor
            button.layer?.borderColor = (selectedNodeID == node.id ? NSColor.white : category.color.withAlphaComponent(0.55)).cgColor
            button.layer?.borderWidth = selectedNodeID == node.id ? 2 : 1
            button.toolTip = node.description
            button.setAccessibilityLabel(text)
            button.setAccessibilityValue(selectedNodeID == node.id ? 1 : 0)
        }
        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        for button in buttons {
            guard let node = SkillTreeData.node(byID: button.nodeID) else { continue }
            let center = position(of: node)
            button.frame = NSRect(x: center.x - 66, y: center.y - 28, width: 132, height: 56)
        }
    }

    private func position(of node: SkillTreeNode) -> CGPoint {
        // The original graph positions are preserved, stretched across a usable
        // viewport so every three-way branch has room for readable node names.
        let x = 70 + (node.position.x - 0.3) / 0.4 * max(0, bounds.width - 140)
        let y = 32 + (0.9 - node.position.y) / 0.15 * 67
        return CGPoint(x: x, y: y)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        category.color.withAlphaComponent(0.42).setStroke()
        for node in SkillTreeData.nodes(for: category) {
            for parentID in node.parentIDs {
                guard let parent = SkillTreeData.node(byID: parentID) else { continue }
                let path = NSBezierPath()
                let parentCenter = position(of: parent)
                let childCenter = position(of: node)
                path.move(to: CGPoint(x: parentCenter.x, y: parentCenter.y + 28))
                path.line(to: CGPoint(x: childCenter.x, y: childCenter.y - 28))
                path.lineWidth = 1.5
                path.stroke()
            }
        }
    }

    func selectNode(id: String?) {
        selectedNodeID = id
        refresh()
        if let id, let node = SkillTreeData.node(byID: id) { onNodeSelected?(node) }
    }

    @objc private func nodePressed(_ button: SkillNodeButton) { selectNode(id: button.nodeID) }
}

final class SkillTreeDetailPanel: NSView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let effectLabel = NSTextField(wrappingLabelWithString: "")
    private let requirementLabel = NSTextField(wrappingLabelWithString: "")
    private let refundLabel = NSTextField(wrappingLabelWithString: "")
    let upgradeButton = NSButton()
    let downgradeButton = NSButton()
    private var nodeID: String?
    var onUpgrade: (() -> Void)?
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
        layer?.cornerRadius = 8
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        for label in [nameLabel, descriptionLabel, effectLabel, requirementLabel, refundLabel] {
            label.textColor = .white.withAlphaComponent(label === nameLabel || label === effectLabel ? 1 : 0.74)
            if label !== nameLabel { label.font = .systemFont(ofSize: 11) }
            addSubview(label)
        }
        upgradeButton.bezelStyle = .rounded
        downgradeButton.bezelStyle = .rounded
        upgradeButton.target = self
        downgradeButton.target = self
        upgradeButton.action = #selector(upgradeTapped)
        downgradeButton.action = #selector(downgradeTapped)
        addSubview(upgradeButton)
        addSubview(downgradeButton)
        refresh()
    }
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let width = max(0, bounds.width - 24)
        nameLabel.frame = NSRect(x: 12, y: 10, width: width, height: 18)
        descriptionLabel.frame = NSRect(x: 12, y: 32, width: width, height: 32)
        effectLabel.frame = NSRect(x: 12, y: 68, width: width, height: 36)
        requirementLabel.frame = NSRect(x: 12, y: 110, width: width, height: 44)
        refundLabel.frame = NSRect(x: 12, y: 158, width: width, height: 32)
        downgradeButton.frame = NSRect(x: 12, y: 198, width: 132, height: 30)
        upgradeButton.frame = NSRect(x: 154, y: 198, width: 152, height: 30)
    }

    func showNode(_ node: SkillTreeNode) { nodeID = node.id; refresh() }
    func clear() { nodeID = nil; refresh() }

    func refresh() {
        upgradeButton.title = L10n.text(.nodeUpgrade)
        downgradeButton.title = L10n.text(.nodeDowngrade)
        guard let nodeID, let node = SkillTreeData.node(byID: nodeID) else {
            nameLabel.stringValue = L10n.text(.selectNodePrompt)
            [descriptionLabel, effectLabel, requirementLabel, refundLabel].forEach { $0.stringValue = "" }
            upgradeButton.isEnabled = false
            downgradeButton.isEnabled = false
            return
        }
        let rank = node.currentLevel
        nameLabel.stringValue = "\(node.name) · \(L10n.string(.currentLevel, rank, node.maxLevel))"
        descriptionLabel.stringValue = node.description
        var effects = [L10n.string(.skillCurrentEffect, "\(node.effect.description) \(node.effect.formattedValue(at: rank))")]
        if rank < node.maxLevel {
            effects.append(L10n.string(.skillNextEffect, "\(node.effect.description) \(node.effect.formattedValue(at: rank + 1))"))
        }
        effectLabel.stringValue = effects.joined(separator: "\n")
        var requirements: [String] = []
        if SkillProgress.loadHeroLevel() < node.unlockHeroLevel { requirements.append(L10n.string(.requiresHeroLevel, node.unlockHeroLevel)) }
        for id in node.parentIDs where SkillTreeProgress.level(for: id) == 0 {
            if let parent = SkillTreeData.node(byID: id) { requirements.append(L10n.string(.requiresParent, parent.name)) }
        }
        if rank < node.maxLevel, SkillTreeProgress.availablePoints() == 0 { requirements.append(L10n.text(.skillNoPoints)) }
        requirementLabel.stringValue = requirements.joined(separator: " · ")
        refundLabel.stringValue = SkillTreeProgress.nodeRefundBlockReason(nodeID) ?? L10n.text(.skillRefundAvailable)
        downgradeButton.isEnabled = SkillTreeProgress.canDowngradeNode(nodeID)
        upgradeButton.isEnabled = node.canUpgrade
        if node.isMaxed { upgradeButton.title = L10n.text(.nodeMaxed) }
    }

    @objc private func upgradeTapped() {
        guard let nodeID, SkillTreeProgress.upgradeNode(nodeID) else { return }
        refresh(); onUpgrade?()
    }
    @objc private func downgradeTapped() {
        guard let nodeID, SkillTreeProgress.downgradeNode(nodeID) else { return }
        refresh(); onUpgrade?()
    }
}

private final class ActiveSkillRow: NSView {
    let skill: HeroSkill
    var onChanged: (() -> Void)?
    private let nameLabel = NSTextField(labelWithString: "")
    private let effectLabel = NSTextField(wrappingLabelWithString: "")
    private let castLabel = NSTextField(labelWithString: "")
    private let requirementLabel = NSTextField(wrappingLabelWithString: "")
    private let refundLabel = NSTextField(wrappingLabelWithString: "")
    private let upgradeButton = NSButton()
    private let refundButton = NSButton()
    private let autoCastButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    override var isFlipped: Bool { true }

    init(skill: HeroSkill) {
        self.skill = skill
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        for label in [nameLabel, effectLabel, castLabel, requirementLabel, refundLabel] {
            label.textColor = .white.withAlphaComponent(label === nameLabel || label === effectLabel ? 1 : 0.74)
            if label !== nameLabel { label.font = .systemFont(ofSize: 10.5) }
            addSubview(label)
        }
        for button in [upgradeButton, refundButton] { button.bezelStyle = .rounded; button.target = self; addSubview(button) }
        upgradeButton.action = #selector(upgrade)
        refundButton.action = #selector(refund)
        autoCastButton.target = self
        autoCastButton.action = #selector(toggleAutoCast)
        addSubview(autoCastButton)
        refresh()
    }
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let width = max(0, bounds.width - 24)
        nameLabel.frame = NSRect(x: 12, y: 10, width: width, height: 18)
        effectLabel.frame = NSRect(x: 12, y: 32, width: width, height: 38)
        castLabel.frame = NSRect(x: 12, y: 74, width: width, height: 16)
        requirementLabel.frame = NSRect(x: 12, y: 94, width: width, height: 28)
        refundLabel.frame = NSRect(x: 12, y: 124, width: width, height: 28)
        refundButton.frame = NSRect(x: 12, y: 158, width: 120, height: 28)
        upgradeButton.frame = NSRect(x: 142, y: 158, width: 144, height: 28)
        autoCastButton.frame = NSRect(x: 302, y: 158, width: max(120, width - 290), height: 28)
    }

    func refresh() {
        let rank = SkillProgress.rank(for: skill)
        nameLabel.stringValue = "\(skill.name) · \(L10n.string(.currentLevel, rank, skill.maxRank))"
        let base = rank > 0 ? Int(SkillCombat.baseDamage(for: skill, rank: rank)) : 0
        var lines = [L10n.string(.skillActiveCurrent, Double(CGFloat(rank) * skill.damageBonusPerRank * 100), base.formatted())]
        if rank < skill.maxRank {
            lines.append(L10n.string(.skillActiveNext, Double(CGFloat(rank + 1) * skill.damageBonusPerRank * 100), Int(SkillCombat.baseDamage(for: skill, rank: rank + 1)).formatted()))
        }
        effectLabel.stringValue = lines.joined(separator: "\n")
        let cooldown = skill.castCooldown * Double(SkillTreeProgress.modifiers().cooldownMultiplier)
        castLabel.stringValue = L10n.string(.skillCastDetails, skill.castEnergyRequirement.formatted(), cooldown)
        var reasons = [SkillProgress.missingRequirementText(for: skill)].compactMap { $0 }
        if rank < skill.maxRank, SkillTreeProgress.availablePoints() == 0 { reasons.append(L10n.text(.skillNoPoints)) }
        requirementLabel.stringValue = reasons.joined(separator: " · ")
        refundLabel.stringValue = SkillTreeProgress.activeRefundBlockReason(skill) ?? L10n.text(.skillRefundAvailable)
        upgradeButton.title = L10n.text(rank == skill.maxRank ? .nodeMaxed : .nodeUpgrade)
        refundButton.title = L10n.text(.nodeDowngrade)
        upgradeButton.isEnabled = SkillProgress.canUpgrade(skill)
        refundButton.isEnabled = SkillProgress.canDowngrade(skill)
        autoCastButton.title = L10n.text(.autoCast)
        autoCastButton.isEnabled = rank > 0
        autoCastButton.state = SkillProgress.isAutoCastEnabled(skill) ? .on : .off
    }

    @objc private func upgrade() { if SkillProgress.upgrade(skill) { onChanged?() } }
    @objc private func refund() { if SkillProgress.downgrade(skill) { onChanged?() } }
    @objc private func toggleAutoCast() {
        SkillProgress.setAutoCastEnabled(autoCastButton.state == .on, for: skill)
        onChanged?()
    }
}
