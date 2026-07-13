import AppKit

final class NotchContentView: NSView {
    private let capsuleLayer = CAShapeLayer()
    private let glowLayer = CAGradientLayer()

    private let collapsedHUD = NSView()
    private let compactHeroView = PixelActorView(kind: .hero)
    private let compactLevelLabel = NSTextField(labelWithString: "LV 7")
    private let compactTokenLabel = NSTextField(labelWithString: "184K")
    private let compactHPBar = PixelBarView()
    private let compactXPBar = PixelBarView()

    private let expandedHUD = NSView()
    private let battleScene = BattleSceneView()
    private let titleLabel = NSTextField(labelWithString: "Notch Hero")
    private let tokenLabel = NSTextField(labelWithString: "Today 184K")
    private let rateLabel = NSTextField(labelWithString: "+812 XP/min")
    private let monsterLabel = NSTextField(labelWithString: "Prompt Wraith")
    private let combatLabel = NSTextField(labelWithString: "Codex strike converts tokens into XP")
    private let heroHPBar = PixelBarView()
    private let heroXPBar = PixelBarView()

    private var trackingArea: NSTrackingArea?
    private var collapsedStyle: NotchStyle
    private var expandedStyle: NotchStyle
    private var style: NotchStyle
    private var isExpanded = false
    private var usageTimer: Timer?
    private var heroLevel = 7
    private var xpProgress: CGFloat = 0
    private var heroHealth: CGFloat = 0.58
    private var monsterHealth: CGFloat = 0.74
    private var todayTokens = 0
    private var xpRate = 0
    private var activeSource = "No source"
    private var lastObservedTokens: Int?
    private var hasRealUsageData = false

    var onHoverChanged: ((Bool) -> Void)?

    init(frame frameRect: NSRect, collapsedStyle: NotchStyle, expandedStyle: NotchStyle) {
        self.collapsedStyle = collapsedStyle
        self.expandedStyle = expandedStyle
        self.style = collapsedStyle
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayers()
        setupCollapsedHUD()
        setupExpandedHUD()
        updateGameLabels()
        setExpanded(false, animated: false)
        startUsageMonitor()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let nextArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(nextArea)
        trackingArea = nextArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    func updateStyles(collapsed: NotchStyle, expanded: NotchStyle, animated: Bool) {
        collapsedStyle = collapsed
        expandedStyle = expanded
        style = isExpanded ? expanded : collapsed
        setExpanded(isExpanded, animated: animated)
    }

    func setExpanded(_ isExpanded: Bool, animated: Bool) {
        self.isExpanded = isExpanded
        style = isExpanded ? expandedStyle : collapsedStyle

        let changes = {
            self.collapsedHUD.alphaValue = isExpanded ? 0 : 1
            self.expandedHUD.alphaValue = isExpanded ? 1 : 0
            self.glowLayer.opacity = isExpanded ? 0.72 : 0.0
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                changes()
            }
        } else {
            changes()
        }
    }

    override func layout() {
        super.layout()

        let notchRect = NSRect(
            x: (bounds.width - style.notchSize.width) / 2,
            y: bounds.height - style.notchSize.height - style.topInset,
            width: style.notchSize.width,
            height: style.notchSize.height
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        capsuleLayer.frame = notchRect
        capsuleLayer.path = NotchShape.path(in: capsuleLayer.bounds, radius: style.cornerRadius)
        capsuleLayer.shadowRadius = style.shadowRadius
        capsuleLayer.shadowOpacity = style.shadowOpacity

        glowLayer.frame = notchRect.insetBy(dx: -18, dy: -14)
        glowLayer.cornerRadius = style.cornerRadius + 18

        layoutCollapsedHUD(in: notchRect)
        layoutExpandedHUD(in: notchRect)

        CATransaction.commit()
    }

    private func setupLayers() {
        layer?.backgroundColor = NSColor.clear.cgColor

        glowLayer.colors = [
            NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 0.0).cgColor,
            NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 0.30).cgColor,
            NSColor(red: 1.0, green: 0.74, blue: 0.20, alpha: 0.18).cgColor,
            NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 0.0).cgColor
        ]
        glowLayer.locations = [0.0, 0.28, 0.72, 1.0]
        glowLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 0.5)
        glowLayer.opacity = 0
        layer?.addSublayer(glowLayer)

        capsuleLayer.fillColor = NSColor.black.cgColor
        capsuleLayer.shadowColor = NSColor.black.cgColor
        capsuleLayer.shadowOpacity = 0.35
        capsuleLayer.shadowRadius = 14
        capsuleLayer.shadowOffset = CGSize(width: 0, height: -8)
        layer?.addSublayer(capsuleLayer)

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.35
        pulse.toValue = 0.85
        pulse.duration = 1.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        glowLayer.add(pulse, forKey: "battlePulse")
    }

    private func setupCollapsedHUD() {
        compactLevelLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        compactLevelLabel.textColor = .white
        compactLevelLabel.alignment = .left
        compactLevelLabel.lineBreakMode = .byTruncatingTail
        compactLevelLabel.maximumNumberOfLines = 1

        compactTokenLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        compactTokenLabel.textColor = NSColor.white.withAlphaComponent(0.58)
        compactTokenLabel.alignment = .right
        compactTokenLabel.lineBreakMode = .byTruncatingMiddle
        compactTokenLabel.maximumNumberOfLines = 1

        compactHPBar.fillColor = NSColor(red: 0.20, green: 0.95, blue: 0.48, alpha: 1.0)
        compactXPBar.fillColor = NSColor(red: 0.0, green: 0.90, blue: 0.82, alpha: 1.0)

        collapsedHUD.addSubview(compactHeroView)
        collapsedHUD.addSubview(compactLevelLabel)
        collapsedHUD.addSubview(compactTokenLabel)
        collapsedHUD.addSubview(compactHPBar)
        collapsedHUD.addSubview(compactXPBar)
        addSubview(collapsedHUD)
    }

    private func setupExpandedHUD() {
        [titleLabel, tokenLabel, rateLabel, monsterLabel, combatLabel].forEach {
            $0.lineBreakMode = .byTruncatingTail
        }

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .left

        tokenLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        tokenLabel.textColor = NSColor.white.withAlphaComponent(0.68)
        tokenLabel.alignment = .right

        rateLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        rateLabel.textColor = NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1.0)
        rateLabel.alignment = .right

        monsterLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        monsterLabel.textColor = NSColor(red: 1.0, green: 0.55, blue: 0.42, alpha: 1.0)
        monsterLabel.alignment = .center

        combatLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        combatLabel.textColor = NSColor.white.withAlphaComponent(0.58)
        combatLabel.alignment = .center

        heroHPBar.fillColor = NSColor(red: 0.20, green: 0.95, blue: 0.48, alpha: 1.0)
        heroXPBar.fillColor = NSColor(red: 0.0, green: 0.90, blue: 0.82, alpha: 1.0)

        expandedHUD.addSubview(titleLabel)
        expandedHUD.addSubview(tokenLabel)
        expandedHUD.addSubview(rateLabel)
        expandedHUD.addSubview(monsterLabel)
        expandedHUD.addSubview(battleScene)
        expandedHUD.addSubview(heroHPBar)
        expandedHUD.addSubview(heroXPBar)
        expandedHUD.addSubview(combatLabel)
        addSubview(expandedHUD)
    }

    private func layoutCollapsedHUD(in notchRect: NSRect) {
        collapsedHUD.frame = notchRect.insetBy(dx: 11, dy: 3)

        let heroSize = min(22, collapsedHUD.bounds.height - 6)
        compactHeroView.frame = NSRect(x: 4, y: (collapsedHUD.bounds.height - heroSize) / 2, width: heroSize, height: heroSize)

        let textX = compactHeroView.frame.maxX + 8
        let textWidth = collapsedHUD.bounds.width - textX - 8
        let barHeight: CGFloat = 3
        let barGap: CGFloat = 3
        let labelHeight: CGFloat = 9
        let xpY: CGFloat = 3
        let hpY = xpY + barHeight + barGap
        let labelY = collapsedHUD.bounds.height - labelHeight - 1
        let levelWidth = min(48, textWidth * 0.42)
        let tokenX = textX + levelWidth + 6

        compactLevelLabel.frame = NSRect(x: textX, y: labelY, width: levelWidth, height: labelHeight)
        compactTokenLabel.frame = NSRect(x: tokenX, y: labelY, width: max(34, textWidth - levelWidth - 6), height: labelHeight)
        compactHPBar.frame = NSRect(x: textX, y: hpY, width: textWidth, height: barHeight)
        compactXPBar.frame = NSRect(x: textX, y: xpY, width: textWidth, height: barHeight)
    }

    private func layoutExpandedHUD(in notchRect: NSRect) {
        expandedHUD.frame = notchRect.insetBy(dx: 16, dy: 10)

        let width = expandedHUD.bounds.width
        let height = expandedHUD.bounds.height
        titleLabel.frame = NSRect(x: 4, y: height - 18, width: 120, height: 15)
        tokenLabel.frame = NSRect(x: width - 132, y: height - 18, width: 128, height: 15)
        rateLabel.frame = NSRect(x: width - 132, y: height - 34, width: 128, height: 14)
        monsterLabel.frame = NSRect(x: width / 2 - 56, y: height - 34, width: 112, height: 14)

        battleScene.frame = NSRect(x: 8, y: 27, width: width - 16, height: max(44, height - 66))
        heroHPBar.frame = NSRect(x: 8, y: 17, width: width * 0.42, height: 4)
        heroXPBar.frame = NSRect(x: width * 0.50, y: 17, width: width * 0.42, height: 4)
        combatLabel.frame = NSRect(x: 8, y: 2, width: width - 16, height: 13)
    }

    private func startUsageMonitor() {
        refreshUsage()
        usageTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUsage()
            }
        }
    }

    private func refreshUsage() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let snapshot = TokenUsageScanner.scanToday()
            DispatchQueue.main.async {
                self?.applyUsageSnapshot(snapshot)
            }
        }
    }

    private func applyUsageSnapshot(_ snapshot: TokenUsageSnapshot) {
        hasRealUsageData = snapshot.hasRealData
        todayTokens = snapshot.totalTokens
        activeSource = snapshot.dominantSource
        xpRate = snapshot.recentTokens / 10
        heroLevel = level(for: snapshot.totalTokens)
        xpProgress = progressToNextLevel(for: snapshot.totalTokens)
        heroHealth = snapshot.recentTokens > 0 ? 0.88 : 0.58

        let previousTokens = lastObservedTokens
        lastObservedTokens = snapshot.totalTokens

        guard snapshot.hasRealData else {
            compactLevelLabel.stringValue = "NO DATA"
            compactTokenLabel.stringValue = "--"
            tokenLabel.stringValue = "No local usage"
            rateLabel.stringValue = "+0 XP/min"
            monsterLabel.stringValue = "Waiting"
            combatLabel.stringValue = "No local token events found today"
            updateGameLabels()
            return
        }

        if let previousTokens, snapshot.totalTokens > previousTokens {
            tickBattle(tokenDelta: snapshot.totalTokens - previousTokens)
        } else {
            combatLabel.stringValue = "Watching \(activeSource) token logs"
            updateGameLabels()
        }
    }

    private func tickBattle(tokenDelta: Int) {
        let damage = min(999, max(1, tokenDelta / 75))
        let xpGain = min(0.18, CGFloat(tokenDelta) / 80_000)

        monsterHealth -= CGFloat(damage) / 180
        if monsterHealth <= 0.08 {
            monsterHealth = 1
            combatLabel.stringValue = "\(activeSource) defeated Prompt Wraith"
        } else {
            combatLabel.stringValue = "\(activeSource) +\(formatCompact(tokenDelta)) tokens"
        }

        xpProgress += xpGain
        if xpProgress >= 1 {
            xpProgress -= 1
            heroLevel += 1
            combatLabel.stringValue = "Level up from real token XP"
        }

        battleScene.monsterHealth = monsterHealth
        battleScene.playAttack(damage: damage)
        updateGameLabels()
    }

    private func updateGameLabels() {
        if hasRealUsageData {
            compactLevelLabel.stringValue = "LV \(heroLevel)"
            compactTokenLabel.stringValue = formatCompact(todayTokens)
            tokenLabel.stringValue = "Today \(formatCompact(todayTokens))"
            monsterLabel.stringValue = "\(activeSource) Wraith"
        }
        rateLabel.stringValue = "+\(formatCompact(xpRate)) XP/min"
        compactHPBar.value = heroHealth
        compactXPBar.value = xpProgress
        heroHPBar.value = heroHealth
        heroXPBar.value = xpProgress
        battleScene.monsterHealth = monsterHealth
    }

    private func level(for tokens: Int) -> Int {
        max(1, Int(sqrt(Double(max(tokens, 0)) / 1_200.0)) + 1)
    }

    private func progressToNextLevel(for tokens: Int) -> CGFloat {
        let currentLevel = level(for: tokens)
        let currentFloor = pow(Double(currentLevel - 1), 2) * 1_200
        let nextFloor = pow(Double(currentLevel), 2) * 1_200
        guard nextFloor > currentFloor else {
            return 0
        }
        return CGFloat((Double(tokens) - currentFloor) / (nextFloor - currentFloor))
    }

    private func formatCompact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return "\(value / 1_000)K"
        }
        return "\(value)"
    }
}

struct NotchStyle {
    let windowSize: NSSize
    let notchSize: NSSize
    let topInset: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOpacity: Float

    static let fallbackCollapsed = makeCollapsed(topBarHeight: 34)

    static let fallbackExpanded = makeExpanded(collapsed: fallbackCollapsed)

    static func styles(for screen: NSScreen?) -> (collapsed: NotchStyle, expanded: NotchStyle) {
        let topBarHeight = screen.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? fallbackCollapsed.notchSize.height
        let collapsed = makeCollapsed(topBarHeight: topBarHeight)
        return (collapsed, makeExpanded(collapsed: collapsed))
    }

    private static func makeCollapsed(topBarHeight: CGFloat) -> NotchStyle {
        let height = round(min(max(topBarHeight, 28), 42))
        let width = round(height * 5.85)

        return NotchStyle(
            windowSize: NSSize(width: width + 24, height: height),
            notchSize: NSSize(width: width, height: height),
            topInset: 0,
            cornerRadius: round(height * 0.45),
            shadowRadius: 8,
            shadowOpacity: 0.26
        )
    }

    private static func makeExpanded(collapsed: NotchStyle) -> NotchStyle {
        let height = round(collapsed.notchSize.height + 96)
        let width = round(max(468, collapsed.notchSize.width + 260))

        return NotchStyle(
            windowSize: NSSize(width: width + 34, height: height + 18),
            notchSize: NSSize(width: width, height: height),
            topInset: 0,
            cornerRadius: round(min(34, height * 0.28)),
            shadowRadius: 24,
            shadowOpacity: 0.52
        )
    }
}

private enum NotchShape {
    static func path(in rect: CGRect, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let r = min(radius, rect.width / 2, rect.height)
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        path.move(to: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        path.addLine(to: CGPoint(x: maxX, y: minY + r))
        path.addQuadCurve(to: CGPoint(x: maxX - r, y: minY), control: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: minX + r, y: minY))
        path.addQuadCurve(to: CGPoint(x: minX, y: minY + r), control: CGPoint(x: minX, y: minY))
        path.closeSubpath()

        return path
    }
}
