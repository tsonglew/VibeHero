import AppKit

// MARK: - Skill Tree View

final class SkillTreeView: NSView {

    // MARK: - Properties

    private var selectedCategory: SkillTreeCategory = .attack
    private let categorySelector = NSSegmentedControl()
    private let scrollView = NSScrollView()
    private let treeCanvas = SkillTreeCanvas()
    private let detailPanel = SkillTreeDetailPanel()
    private let pointsLabel = NSTextField(labelWithString: "")

    var onSkillChanged: (() -> Void)?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).cgColor

        // Category selector
        categorySelector.segmentCount = SkillTreeCategory.allCases.count
        for (index, category) in SkillTreeCategory.allCases.enumerated() {
            categorySelector.setLabel(category.displayName, forSegment: index)
        }
        categorySelector.selectedSegment = 0
        categorySelector.target = self
        categorySelector.action = #selector(categoryChanged)
        categorySelector.segmentStyle = .rounded
        addSubview(categorySelector)

        // Points label
        pointsLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        pointsLabel.textColor = .white
        addSubview(pointsLabel)

        // Scroll view for tree canvas
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = treeCanvas
        addSubview(scrollView)

        // Tree canvas
        treeCanvas.onNodeSelected = { [weak self] node in
            self?.showNodeDetail(node)
        }

        // Detail panel
        detailPanel.onUpgrade = { [weak self] in
            self?.refresh()
            self?.onSkillChanged?()
        }
        addSubview(detailPanel)

        refresh()
    }

    override func layout() {
        super.layout()

        let padding: CGFloat = 16
        let topHeight: CGFloat = 36
        let detailWidth: CGFloat = 240

        // Points label (top left)
        pointsLabel.frame = NSRect(x: padding, y: bounds.height - topHeight + 8, width: 120, height: 20)

        // Category selector (top center)
        let selectorWidth: CGFloat = 320
        categorySelector.frame = NSRect(
            x: (bounds.width - selectorWidth) / 2,
            y: bounds.height - topHeight + 4,
            width: selectorWidth,
            height: 28
        )

        // Detail panel (right side)
        detailPanel.frame = NSRect(
            x: bounds.width - detailWidth - padding,
            y: padding,
            width: detailWidth,
            height: bounds.height - topHeight - padding * 2
        )

        // Scroll view (left side, remaining space)
        scrollView.frame = NSRect(
            x: padding,
            y: padding,
            width: bounds.width - detailWidth - padding * 3,
            height: bounds.height - topHeight - padding * 2
        )

        // Tree canvas size
        treeCanvas.frame = NSRect(x: 0, y: 0, width: 600, height: 700)
    }

    // MARK: - Actions

    @objc private func categoryChanged() {
        let index = categorySelector.selectedSegment
        guard index >= 0, index < SkillTreeCategory.allCases.count else { return }
        selectedCategory = SkillTreeCategory.allCases[index]
        treeCanvas.category = selectedCategory
        detailPanel.clear()
    }

    private func showNodeDetail(_ node: SkillTreeNode) {
        detailPanel.showNode(node)
    }

    func refresh() {
        let points = SkillTreeProgress.availablePoints()
        pointsLabel.stringValue = L10n.string(.availableSkillPoints, points)

        treeCanvas.category = selectedCategory
        treeCanvas.needsDisplay = true
        detailPanel.refresh()
    }
}

// MARK: - Skill Tree Canvas

final class SkillTreeCanvas: NSView {

    var category: SkillTreeCategory = .attack
    var onNodeSelected: ((SkillTreeNode) -> Void)?

    private var hoveredNodeID: String?
    private let nodeRadius: CGFloat = 24
    private let nodeSpacing: CGFloat = 80

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0).cgColor

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func layout() {
        super.layout()
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let nodes = SkillTreeData.nodes(for: category)
        let canvasWidth: CGFloat = 600

        // Draw connections first (behind nodes)
        for node in nodes {
            drawConnections(for: node, in: context, canvasWidth: canvasWidth)
        }

        // Draw nodes
        for node in nodes {
            drawNode(node, in: context, canvasWidth: canvasWidth)
        }
    }

    private func drawConnections(for node: SkillTreeNode, in context: CGContext, canvasWidth: CGFloat) {
        let startPoint = nodePosition(node, canvasWidth: canvasWidth)

        for parentID in node.parentIDs {
            guard let parent = SkillTreeData.node(byID: parentID) else { continue }
            let endPoint = nodePosition(parent, canvasWidth: canvasWidth)

            // Determine line color based on parent level
            let parentLevel = SkillTreeProgress.level(for: parentID)
            let lineColor: NSColor
            if parentLevel > 0 {
                lineColor = category.color.withAlphaComponent(0.6)
            } else {
                lineColor = NSColor.gray.withAlphaComponent(0.3)
            }

            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(parentLevel > 0 ? 3 : 2)

            // Draw curved line
            context.move(to: CGPoint(x: startPoint.x, y: startPoint.y - nodeRadius))
            let midY = (startPoint.y + endPoint.y) / 2
            context.addCurve(
                to: CGPoint(x: endPoint.x, y: endPoint.y + nodeRadius),
                control1: CGPoint(x: startPoint.x, y: midY),
                control2: CGPoint(x: endPoint.x, y: midY)
            )
            context.strokePath()
        }
    }

    private func drawNode(_ node: SkillTreeNode, in context: CGContext, canvasWidth: CGFloat) {
        let center = nodePosition(node, canvasWidth: canvasWidth)
        let level = SkillTreeProgress.level(for: node.id)
        let isUnlocked = SkillTreeProgress.isNodeUnlocked(node.id)
        let canUpgrade = SkillTreeProgress.canUpgradeNode(node.id)

        // Determine colors
        let baseColor = category.color
        let nodeColor: NSColor
        let glowColor: NSColor

        if level >= node.maxLevel {
            // Maxed out - gold glow
            nodeColor = NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
            glowColor = NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.5)
        } else if level > 0 {
            // Has points - bright
            nodeColor = baseColor
            glowColor = baseColor.withAlphaComponent(0.4)
        } else if isUnlocked {
            // Unlocked but no points - dim
            nodeColor = baseColor.withAlphaComponent(0.5)
            glowColor = .clear
        } else {
            // Locked - gray
            nodeColor = NSColor.gray.withAlphaComponent(0.4)
            glowColor = .clear
        }

        // Draw glow if has points
        if level > 0 {
            let glowPath = CGMutablePath()
            glowPath.addArc(
                center: center,
                radius: nodeRadius + 6,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: false
            )
            context.addPath(glowPath)
            context.setFillColor(glowColor.cgColor)
            context.fillPath()
        }

        // Draw node circle
        let nodePath = CGMutablePath()
        nodePath.addArc(
            center: center,
            radius: nodeRadius,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: false
        )

        context.addPath(nodePath)
        context.setFillColor(nodeColor.cgColor)
        context.fillPath()

        // Draw border
        let borderColor: NSColor
        if canUpgrade {
            borderColor = .white
        } else if isUnlocked {
            borderColor = baseColor.withAlphaComponent(0.8)
        } else {
            borderColor = NSColor.gray.withAlphaComponent(0.5)
        }
        context.addPath(nodePath)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(canUpgrade ? 3 : 2)
        context.strokePath()

        // Draw level text
        let levelString = "\(level)/\(node.maxLevel)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: level > 0 ? NSColor.white : NSColor.gray
        ]
        let size = levelString.size(withAttributes: attributes)
        let textRect = NSRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        levelString.draw(in: textRect, withAttributes: attributes)
    }

    private func nodePosition(_ node: SkillTreeNode, canvasWidth: CGFloat) -> CGPoint {
        // Convert normalized position (0...1) to canvas coordinates
        let margin: CGFloat = 60
        let usableWidth = canvasWidth - margin * 2
        let usableHeight: CGFloat = 600

        let x = margin + node.position.x * usableWidth
        let y = margin + (1 - node.position.y) * usableHeight

        return CGPoint(x: x, y: y)
    }

    // MARK: - Mouse Handling

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let nodes = SkillTreeData.nodes(for: category)
        let canvasWidth: CGFloat = 600

        hoveredNodeID = nil
        for node in nodes {
            let center = nodePosition(node, canvasWidth: canvasWidth)
            let distance = hypot(location.x - center.x, location.y - center.y)
            if distance <= nodeRadius {
                hoveredNodeID = node.id
                break
            }
        }

        NSCursor.pointingHand.set()
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoveredNodeID = nil
        NSCursor.arrow.set()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let nodes = SkillTreeData.nodes(for: category)
        let canvasWidth: CGFloat = 600

        for node in nodes {
            let center = nodePosition(node, canvasWidth: canvasWidth)
            let distance = hypot(location.x - center.x, location.y - center.y)
            if distance <= nodeRadius {
                onNodeSelected?(node)
                return
            }
        }
    }
}

// MARK: - Skill Tree Detail Panel

final class SkillTreeDetailPanel: NSView {

    private let nameLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")
    private let levelLabel = NSTextField(labelWithString: "")
    private let effectLabel = NSTextField(labelWithString: "")
    private let requirementLabel = NSTextField(labelWithString: "")
    private let upgradeButton = NSButton()
    private let downgradeButton = NSButton()

    private var currentNode: SkillTreeNode?

    var onUpgrade: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1.0).cgColor
        layer?.cornerRadius = 8
        layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        layer?.borderWidth = 1

        // Name label
        nameLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = .white
        addSubview(nameLabel)

        // Description
        descriptionLabel.font = NSFont.systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        addSubview(descriptionLabel)

        // Level
        levelLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        levelLabel.textColor = .white
        addSubview(levelLabel)

        // Effect
        effectLabel.font = NSFont.systemFont(ofSize: 12)
        effectLabel.textColor = .white
        addSubview(effectLabel)

        // Requirements
        requirementLabel.font = NSFont.systemFont(ofSize: 11)
        requirementLabel.textColor = .secondaryLabelColor
        addSubview(requirementLabel)

        // Upgrade button
        upgradeButton.title = L10n.text(.nodeUpgrade)
        upgradeButton.target = self
        upgradeButton.action = #selector(upgradeTapped)
        upgradeButton.bezelStyle = .rounded
        addSubview(upgradeButton)

        // Downgrade button
        downgradeButton.title = L10n.text(.nodeDowngrade)
        downgradeButton.target = self
        downgradeButton.action = #selector(downgradeTapped)
        downgradeButton.bezelStyle = .rounded
        addSubview(downgradeButton)

        clear()
    }

    override func layout() {
        super.layout()

        let padding: CGFloat = 16
        let spacing: CGFloat = 12
        let buttonHeight: CGFloat = 32

        var y: CGFloat = padding

        // Buttons at bottom
        let buttonWidth = (bounds.width - padding * 2 - 8) / 2
        downgradeButton.frame = NSRect(x: padding, y: y, width: buttonWidth, height: buttonHeight)
        upgradeButton.frame = NSRect(x: padding + buttonWidth + 8, y: y, width: buttonWidth, height: buttonHeight)
        y += buttonHeight + spacing * 2

        // Requirements
        requirementLabel.frame = NSRect(x: padding, y: y, width: bounds.width - padding * 2, height: 16)
        y += 20 + spacing

        // Effect
        effectLabel.frame = NSRect(x: padding, y: y, width: bounds.width - padding * 2, height: 40)
        y += 44 + spacing

        // Level
        levelLabel.frame = NSRect(x: padding, y: y, width: bounds.width - padding * 2, height: 18)
        y += 22 + spacing

        // Description
        let descHeight: CGFloat = 60
        descriptionLabel.frame = NSRect(x: padding, y: y, width: bounds.width - padding * 2, height: descHeight)
        y += descHeight + spacing

        // Name
        nameLabel.frame = NSRect(x: padding, y: y, width: bounds.width - padding * 2, height: 22)
    }

    func showNode(_ node: SkillTreeNode) {
        currentNode = node
        refresh()
    }

    func clear() {
        currentNode = nil
        nameLabel.stringValue = L10n.text(.selectNodePrompt)
        descriptionLabel.stringValue = ""
        levelLabel.stringValue = ""
        effectLabel.stringValue = ""
        requirementLabel.stringValue = ""
        upgradeButton.isEnabled = false
        downgradeButton.isEnabled = false
    }

    func refresh() {
        guard let node = currentNode else {
            clear()
            return
        }

        let level = SkillTreeProgress.level(for: node.id)
        let isUnlocked = SkillTreeProgress.isNodeUnlocked(node.id)
        let canUpgrade = SkillTreeProgress.canUpgradeNode(node.id)

        nameLabel.stringValue = node.name
        descriptionLabel.stringValue = node.description
        levelLabel.stringValue = L10n.string(.currentLevel, level, node.maxLevel)

        // Effect value
        let effectValue = node.effect.value(at: level)
        effectLabel.stringValue = "\(node.effect.description): \(Int(effectValue * 100))%"

        // Requirements
        var requirements: [String] = []
        if node.unlockHeroLevel > 1 {
            let heroLevel = SkillProgress.loadHeroLevel()
            let req = L10n.string(.requiresHeroLevel, node.unlockHeroLevel)
            requirements.append(heroLevel >= node.unlockHeroLevel ? "✓ \(req)" : "✗ \(req)")
        }
        for parentID in node.parentIDs {
            if let parent = SkillTreeData.node(byID: parentID) {
                let parentLevel = SkillTreeProgress.level(for: parentID)
                let req = L10n.string(.requiresParent, parent.name)
                requirements.append(parentLevel > 0 ? "✓ \(req)" : "✗ \(req)")
            }
        }
        requirementLabel.stringValue = requirements.joined(separator: "\n")

        // Buttons
        upgradeButton.isEnabled = canUpgrade
        upgradeButton.title = level >= node.maxLevel ? L10n.text(.nodeMaxed) : L10n.text(.nodeUpgrade)
        downgradeButton.isEnabled = level > 0 && isUnlocked
    }

    @objc private func upgradeTapped() {
        guard let node = currentNode else { return }
        if SkillTreeProgress.upgradeNode(node.id) {
            refresh()
            onUpgrade?()
        }
    }

    @objc private func downgradeTapped() {
        guard let node = currentNode else { return }
        if SkillTreeProgress.downgradeNode(node.id) {
            refresh()
            onUpgrade?()
        }
    }
}
