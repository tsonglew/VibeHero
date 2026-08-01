import AppKit

private struct PendingHeroStrike {
    let tokenCount: Int
    let comboMultiplier: CGFloat
}

final class NotchContentView: NSView {
    private let capsuleLayer = CAShapeLayer()
    private let glowLayer = CAGradientLayer()

    private let collapsedHUD = NSView()
    private let compactHeroView = PixelActorView(kind: .hero)
    private let compactLevelLabel = NSTextField(labelWithString: "LV 0")
    private let compactTokenLabel = NSTextField(labelWithString: "184K")
    private let compactHPLabel = NSTextField(labelWithString: "H88")
    private let compactXPLabel = NSTextField(labelWithString: "X00")
    private let compactHPBar = PixelBarView()
    private let compactXPBar = PixelBarView()

    private let expandedHUD = NSView()
    private let battleScene = BattleSceneView()
    private let sessionListView = SessionListView()
    private let viewToggleButton = NSButton()
    private var isShowingSessions = false
    private let titleLabel = NSTextField(labelWithString: "Vibe Hero")
    private let tokenLabel = NSTextField(labelWithString: L10n.string(.todayTokens, "184K"))
    private let rateLabel = NSTextField(labelWithString: L10n.string(.xpPerMinute, "812"))
    private let skillLabel = NSTextField(labelWithString: L10n.string(.skillPointsShort, 0))
    private let skillEnergyLabel = NSTextField(labelWithString: L10n.string(.skillEnergyPercent, 0, 100, 0))
    private let skillEnergyBar = PixelBarView()
    private let combatLabel = NSTextField(labelWithString: L10n.text(.tokenStreamStatus))
    private let heroHPLabel = NSTextField(labelWithString: "HP 88%")
    private let heroXPLabel = NSTextField(labelWithString: "XP 0%")
    private let monsterHPLabel = NSTextField(labelWithString: L10n.string(.monsterHP, MonsterKind.promptWraith.shortName, "89", "12K", 74))
    private let heroHPBar = PixelBarView()
    private let heroXPBar = PixelBarView()
    private let monsterHPBar = PixelBarView()
    private let settingsButton = NSButton()

    private var trackingArea: NSTrackingArea?
    private var collapsedStyle: NotchStyle
    private var expandedStyle: NotchStyle
    private var style: NotchStyle
    private var isExpanded = false
    private var usageTimer: Timer?
    private var usageScanInFlight = false
    private var monsterAttackTimer: Timer?
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var fileMonitorQueue = DispatchQueue(label: "com.vibehero.filemonitor", qos: .utility)
    private var heroLevel = SkillProgress.loadHeroLevel()
    private var heroExperience = HeroExperience.loadTotalXP()
    private var currentXP = 0
    private var requiredXP = 1
    private var xpProgress: CGFloat = 0
    private var heroHealth: CGFloat = 1
    private var monsterHealth: CGFloat = 0.74
    private var todayTokens = 0
    private var xpRate = 0
    private var activeSource = "No source"
    private var lastObservedTokens: Int?
    private var lastTokenSpendAt: Date?
    private var lastMonsterAttackAt: Date?
    private var tokenActivityExpiresAt: Date?
    private var tokenActivityExpirationWorkItem: DispatchWorkItem?
    private var monsterRespawnWorkItem: DispatchWorkItem?
    private var currentMonster = MonsterKind.promptWraith
    private var nextMonsterKind = MonsterKind.promptWraith
    private var hasRealUsageData = false
    private var skillEnergy: CGFloat = 0
    private var lootMessageExpiresAt: Date?
    private var isDefeated = false
    private var selectedRole = HeroRole.load()
    private var totalKills = StageTracker.loadTotalKills()
    private var currentMonsterStage = 1
    private var currentMonsterIsBoss = false
    private var comboCount = 0
    private var lastComboAt: Date?
    private var pendingHeroStrikes: [PendingHeroStrike] = []

    private var currentStage: Int {
        currentMonsterStage
    }

    var onHoverChanged: ((Bool) -> Void)?
    var onSettingsRequested: (() -> Void)?
    /// Fires when the expanded panel wants a different height, so the window can
    /// resize while it is already open.
    var onExpandedHeightChanged: (() -> Void)?

    /// Vertical chrome `layoutExpandedHUD` puts around the session list: the
    /// 10pt window inset on both edges, the title row, and the 4pt bottom inset.
    /// Keep in sync with the frames there.
    private static let sessionListChrome: CGFloat = 50

    private var lastRequestedExpandedHeight: CGFloat?

    /// Notch height the expanded panel would like. `nil` in game mode, where the
    /// default expanded size is exactly right.
    var preferredExpandedNotchHeight: CGFloat? {
        guard isShowingSessions else { return nil }
        return sessionListView.preferredContentHeight + Self.sessionListChrome
    }

    init(frame frameRect: NSRect, collapsedStyle: NotchStyle, expandedStyle: NotchStyle) {
        self.collapsedStyle = collapsedStyle
        self.expandedStyle = expandedStyle
        self.style = collapsedStyle
        super.init(frame: frameRect)
        currentMonsterStage = StageProgress.stage(for: totalKills)
        nextMonsterKind = MonsterKind.allCases[totalKills % MonsterKind.allCases.count]
        wantsLayer = true
        setupLayers()
        setupCollapsedHUD()
        setupExpandedHUD()
        applyExperienceState(saveLevel: true)
        spawnNextMonsterBatch()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .notchHeroLanguageChanged,
            object: nil
        )
        updateRoleUI()
        updateGameLabels()
        setExpanded(false, animated: false)
        startUsageMonitor()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func updateStyles(collapsed: NotchStyle, expanded: NotchStyle, animated: Bool) {
        collapsedStyle = collapsed
        expandedStyle = expanded
        style = isExpanded ? expanded : collapsed
        setExpanded(isExpanded, animated: animated)
    }

    func setExpanded(_ isExpanded: Bool, animated: Bool) {
        self.isExpanded = isExpanded
        battleScene.rendersCombatEffects = isExpanded && !isShowingSessions
        compactHeroView.setWalking(!isExpanded && battleScene.worldIsMoving && !isDefeated)
        style = isExpanded ? expandedStyle : collapsedStyle

        let changes = {
            self.collapsedHUD.alphaValue = isExpanded ? 0 : 1
            self.expandedHUD.alphaValue = isExpanded ? 1 : 0
            self.expandedHUD.isHidden = !isExpanded
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

        [compactHPLabel, compactXPLabel].forEach {
            $0.font = NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold)
            $0.textColor = NSColor.white.withAlphaComponent(0.72)
            $0.alignment = .left
            $0.lineBreakMode = .byClipping
            $0.maximumNumberOfLines = 1
        }
        compactHPLabel.textColor = NSColor(red: 0.20, green: 0.95, blue: 0.48, alpha: 1.0)
        compactXPLabel.textColor = NSColor(red: 0.0, green: 0.90, blue: 0.82, alpha: 1.0)

        compactHPBar.fillColor = NSColor(red: 0.20, green: 0.95, blue: 0.48, alpha: 1.0)
        compactXPBar.fillColor = NSColor(red: 0.0, green: 0.90, blue: 0.82, alpha: 1.0)

        collapsedHUD.addSubview(compactHeroView)
        collapsedHUD.addSubview(compactLevelLabel)
        collapsedHUD.addSubview(compactTokenLabel)
        collapsedHUD.addSubview(compactHPLabel)
        collapsedHUD.addSubview(compactXPLabel)
        collapsedHUD.addSubview(compactHPBar)
        collapsedHUD.addSubview(compactXPBar)
        addSubview(collapsedHUD)
    }

    private func setupExpandedHUD() {
        battleScene.onWorldMotionChanged = { [weak self] isMoving in
            guard let self, !self.isExpanded else { return }
            self.compactHeroView.setWalking(isMoving && !self.isDefeated)
        }
        battleScene.onMonsterEngaged = { [weak self] in
            self?.flushPendingHeroStrikes()
        }

        [titleLabel, tokenLabel, rateLabel, skillLabel, skillEnergyLabel, combatLabel].forEach {
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

        skillLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        skillLabel.textColor = NSColor(red: 1.0, green: 0.74, blue: 0.20, alpha: 1.0)
        skillLabel.alignment = .right

        skillEnergyLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
        skillEnergyLabel.textColor = NSColor(red: 1.0, green: 0.74, blue: 0.20, alpha: 1.0)
        skillEnergyLabel.alignment = .left

        combatLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        combatLabel.textColor = NSColor.white.withAlphaComponent(0.58)
        combatLabel.alignment = .center

        [heroHPLabel, heroXPLabel, monsterHPLabel].forEach {
            $0.font = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold)
            $0.textColor = NSColor.white.withAlphaComponent(0.76)
            $0.alignment = .left
            $0.lineBreakMode = .byClipping
        }
        heroHPLabel.textColor = NSColor(red: 0.20, green: 0.95, blue: 0.48, alpha: 1.0)
        heroXPLabel.textColor = NSColor(red: 0.0, green: 0.90, blue: 0.82, alpha: 1.0)
        monsterHPLabel.textColor = currentMonster.hpColor

        heroHPBar.fillColor = NSColor(red: 0.20, green: 0.95, blue: 0.48, alpha: 1.0)
        heroXPBar.fillColor = NSColor(red: 0.0, green: 0.90, blue: 0.82, alpha: 1.0)
        monsterHPBar.fillColor = currentMonster.hpColor
        monsterHPBar.trackColor = NSColor.white.withAlphaComponent(0.12)
        skillEnergyBar.fillColor = NSColor(red: 1.0, green: 0.74, blue: 0.20, alpha: 1.0)
        skillEnergyBar.trackColor = NSColor.white.withAlphaComponent(0.12)

        settingsButton.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: L10n.text(.settingsTitle))
        settingsButton.imagePosition = .imageOnly
        settingsButton.bezelStyle = .regularSquare
        settingsButton.isBordered = false
        settingsButton.contentTintColor = NSColor.white.withAlphaComponent(0.72)
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)

        // View toggle button (game/sessions)
        viewToggleButton.image = NSImage(systemSymbolName: "rectangle.stack.person.crop", accessibilityDescription: "Toggle View")
        viewToggleButton.imagePosition = .imageOnly
        viewToggleButton.bezelStyle = .regularSquare
        viewToggleButton.isBordered = false
        viewToggleButton.contentTintColor = NSColor.white.withAlphaComponent(0.72)
        viewToggleButton.target = self
        viewToggleButton.action = #selector(toggleView)
        viewToggleButton.toolTip = L10n.text(.tabSessions)

        expandedHUD.addSubview(titleLabel)
        expandedHUD.addSubview(tokenLabel)
        expandedHUD.addSubview(rateLabel)
        expandedHUD.addSubview(skillLabel)
        expandedHUD.addSubview(skillEnergyLabel)
        expandedHUD.addSubview(skillEnergyBar)
        expandedHUD.addSubview(battleScene)
        expandedHUD.addSubview(heroHPLabel)
        expandedHUD.addSubview(heroHPBar)
        expandedHUD.addSubview(heroXPLabel)
        expandedHUD.addSubview(heroXPBar)
        expandedHUD.addSubview(monsterHPLabel)
        expandedHUD.addSubview(monsterHPBar)
        expandedHUD.addSubview(combatLabel)
        expandedHUD.addSubview(settingsButton)
        expandedHUD.addSubview(viewToggleButton)
        expandedHUD.addSubview(sessionListView)
        sessionListView.isHidden = true
        addSubview(expandedHUD)

        // Setup session monitoring. Register as an observer (not a single
        // callback) so the settings window's session list can observe in
        // parallel without stealing the HUD's updates.
        SessionMonitor.shared.addObserver(self) { [weak self] sessions in
            Task { @MainActor in
                guard let self else { return }
                self.sessionListView.updateSessions(sessions)
                self.notifyExpandedHeightIfChanged()
            }
        }
    }

    /// Tells the window to resize only when the wanted height actually moved -
    /// scans land every few seconds and most of them change nothing.
    private func notifyExpandedHeightIfChanged() {
        let requested = preferredExpandedNotchHeight
        guard requested != lastRequestedExpandedHeight else { return }
        lastRequestedExpandedHeight = requested
        onExpandedHeightChanged?()
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
        let compactBarLabelWidth: CGFloat = 20
        compactHPLabel.frame = NSRect(x: textX, y: hpY - 2, width: compactBarLabelWidth, height: 7)
        compactXPLabel.frame = NSRect(x: textX, y: xpY - 2, width: compactBarLabelWidth, height: 7)
        compactHPBar.frame = NSRect(x: textX + compactBarLabelWidth, y: hpY, width: max(12, textWidth - compactBarLabelWidth), height: barHeight)
        compactXPBar.frame = NSRect(x: textX + compactBarLabelWidth, y: xpY, width: max(12, textWidth - compactBarLabelWidth), height: barHeight)
    }

    private func layoutExpandedHUD(in notchRect: NSRect) {
        expandedHUD.frame = notchRect.insetBy(dx: 16, dy: 10)

        let width = expandedHUD.bounds.width
        let height = expandedHUD.bounds.height
        let rightColumnWidth: CGFloat = 132
        let rightColumnX = width - rightColumnWidth - 30
        let leftColumnWidth = max(132, min(170, rightColumnX - 14))

        titleLabel.frame = NSRect(x: 4, y: height - 18, width: leftColumnWidth, height: 15)
        settingsButton.frame = NSRect(x: width - 24, y: height - 22, width: 20, height: 20)
        viewToggleButton.frame = NSRect(x: width - 50, y: height - 22, width: 20, height: 20)
        skillEnergyLabel.frame = NSRect(x: 4, y: height - 34, width: leftColumnWidth, height: 11)
        skillEnergyBar.frame = NSRect(x: 4, y: height - 43, width: leftColumnWidth, height: 4)
        tokenLabel.frame = NSRect(x: rightColumnX, y: height - 18, width: rightColumnWidth, height: 15)
        rateLabel.frame = NSRect(x: rightColumnX, y: height - 34, width: rightColumnWidth, height: 14)
        skillLabel.frame = NSRect(x: rightColumnX, y: height - 47, width: rightColumnWidth, height: 12)

        let battleY: CGFloat = 31
        let topStatusBottom = min(skillEnergyBar.frame.minY, skillLabel.frame.minY)
        let battleTop = max(battleY + 44, topStatusBottom - 6)
        battleScene.frame = NSRect(x: 8, y: battleY, width: width - 16, height: battleTop - battleY)

        // Session list takes full available space (from below title to bottom)
        let sessionTop = titleLabel.frame.minY - 8
        sessionListView.frame = NSRect(x: 8, y: 4, width: width - 16, height: sessionTop - 4)

        let statGap: CGFloat = 8
        let statWidth = max(110, (width - 16 - statGap * 2) / 3)
        let leftStatX: CGFloat = 8
        let middleStatX = leftStatX + statWidth + statGap
        let monsterStatX = width - statWidth - 8
        heroHPLabel.frame = NSRect(x: leftStatX, y: 20, width: statWidth, height: 9)
        heroHPBar.frame = NSRect(x: leftStatX, y: 15, width: statWidth, height: 4)
        heroXPLabel.frame = NSRect(x: middleStatX, y: 20, width: statWidth, height: 9)
        heroXPBar.frame = NSRect(x: middleStatX, y: 15, width: statWidth, height: 4)
        monsterHPLabel.frame = NSRect(x: monsterStatX, y: 20, width: statWidth, height: 9)
        monsterHPBar.frame = NSRect(x: monsterStatX, y: 15, width: statWidth, height: 4)
        combatLabel.frame = NSRect(x: 8, y: 2, width: width - 16, height: 13)

        [titleLabel, tokenLabel, rateLabel, skillLabel, skillEnergyLabel, heroHPLabel, heroXPLabel, monsterHPLabel, combatLabel, settingsButton, viewToggleButton].forEach {
            expandedHUD.addSubview($0, positioned: .above, relativeTo: nil)
        }
        expandedHUD.addSubview(skillEnergyBar, positioned: .above, relativeTo: battleScene)
        // Session list should be at the top when visible
        expandedHUD.addSubview(sessionListView, positioned: .above, relativeTo: nil)
    }

    @objc private func openSettings() {
        onSettingsRequested?()
    }

    @objc private func toggleView() {
        isShowingSessions.toggle()
        battleScene.rendersCombatEffects = isExpanded && !isShowingSessions

        // Toggle game UI visibility
        battleScene.isHidden = isShowingSessions
        sessionListView.isHidden = !isShowingSessions

        // Hide all game data UI when showing sessions
        let gameUIElements: [NSView] = [
            heroHPLabel, heroHPBar, heroXPLabel, heroXPBar,
            monsterHPLabel, monsterHPBar, combatLabel,
            skillEnergyLabel, skillEnergyBar, skillLabel,
            tokenLabel, rateLabel
        ]

        for element in gameUIElements {
            element.isHidden = isShowingSessions
        }

        // Update title for session view
        if isShowingSessions {
            titleLabel.stringValue = L10n.text(.activeSessions)
        } else {
            updateTitleLabel()
        }

        // Update button icon
        let iconName = isShowingSessions ? "gamecontroller" : "rectangle.stack.person.crop"
        viewToggleButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Toggle View")
        viewToggleButton.toolTip = isShowingSessions ? L10n.text(.tabGame) : L10n.text(.tabSessions)

        // Force layout update to ensure sessionListView has correct frame
        needsLayout = true
        layoutSubtreeIfNeeded()

        // Session mode wants a taller panel than the game HUD.
        notifyExpandedHeightIfChanged()

        // Start session monitoring when showing sessions
        if isShowingSessions {
            SessionMonitor.shared.startMonitoring()
        }
    }

    // The session list only scanned once, when the view was toggled on, so it
    // went stale as soon as it was open. SessionMonitor throttles internally.
    private func refreshSessionsIfVisible() {
        guard isShowingSessions, isExpanded else { return }
        SessionMonitor.shared.refreshIfNeeded()
    }

    private func updateRoleUI() {
        updateTitleLabel()
        compactHeroView.heroRole = selectedRole
        battleScene.heroRole = selectedRole
        battleScene.backdrop = BattleBackdrop.load()
        updateDefeatPresentation()
    }

    private func updateTitleLabel() {
        let stageTag = currentMonsterIsBoss
            ? L10n.string(.stageTagBoss, currentStage)
            : L10n.string(.stageTag, currentStage)
        titleLabel.stringValue = "\(L10n.string(.appTitleWithRole, selectedRole.label)) · \(stageTag)"
    }

    func reloadPreferences() {
        selectedRole = HeroRole.load()
        reloadLocalizedText()
    }

    @objc private func languageChanged() {
        reloadLocalizedText()
    }

    private func reloadLocalizedText() {
        settingsButton.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: L10n.text(.settingsTitle))
        battleScene.reloadLocalization()
        updateRoleUI()
        updateGameLabels()
        if !hasRealUsageData {
            applyNoDataLabels()
        }
    }

    private func startUsageMonitor() {
        refreshUsage()
        startFileMonitor()

        // Backup timer - less frequent since file monitor handles real-time updates
        usageTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUsage()
                self?.refreshSessionsIfVisible()
            }
        }

        let attackTimer = Timer(timeInterval: CombatTiming.monsterAttackInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickMonsterAttack()
            }
        }
        RunLoop.main.add(attackTimer, forMode: .common)
        monsterAttackTimer = attackTimer
    }

    private func startFileMonitor() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeRoot = home.appendingPathComponent(".claude/projects")
        
        guard FileManager.default.fileExists(atPath: claudeRoot.path) else {
            return
        }
        
        let fd = open(claudeRoot.path, O_EVTONLY)
        guard fd >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename],
            queue: fileMonitorQueue
        )
        
        source.setEventHandler { [weak self] in
            // Debounce: wait 0.5s for write to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refreshUsage()
            }
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        fileMonitor = source
    }

    private func tickMonsterAttack() {
        let now = Date()
        let hasActiveTokens = tokenActivityExpiresAt.map { $0 > now } ?? false
        guard hasRealUsageData, !hasActiveTokens else {
            return
        }
        _ = maybeMonsterAttack(now: now)
        updateGameLabels()
    }

    private func refreshUsage() {
        guard !usageScanInFlight else {
            return
        }
        usageScanInFlight = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let snapshot = TokenUsageScanner.scanToday()
            DispatchQueue.main.async {
                self?.usageScanInFlight = false
                self?.applyUsageSnapshot(snapshot)
            }
        }
    }

    private func applyUsageSnapshot(_ snapshot: TokenUsageSnapshot) {
        let now = snapshot.generatedAt
        hasRealUsageData = snapshot.hasRealData
        todayTokens = snapshot.totalTokens
        activeSource = snapshot.dominantSource
        xpRate = snapshot.recentTokens / 10
        let previousTokens = lastObservedTokens
        lastObservedTokens = snapshot.totalTokens

        guard snapshot.hasRealData else {
            tokenActivityExpiresAt = nil
            setTokenActivity(false)
            applyNoDataLabels()
            updateGameLabels()
            return
        }

        if let previousTokens, snapshot.totalTokens > previousTokens {
            refreshTokenActivity(now: now, didSpendTokens: true, latestEventAt: snapshot.latestEventAt)
            lastTokenSpendAt = now
            lastMonsterAttackAt = nil
            if isDefeated {
                reviveHeroFromTokenSpend()
                updateGameLabels()
                return
            }

            registerComboTick(now: now)
            heroHealth = min(1, heroHealth + 0.08)
            tickBattle(tokenDelta: snapshot.totalTokens - previousTokens)
        } else {
            refreshTokenActivity(now: now, didSpendTokens: false, latestEventAt: snapshot.latestEventAt)
            if lastTokenSpendAt == nil {
                lastTokenSpendAt = snapshot.latestEventAt
            }
            updateGameLabels()
        }
    }

    private func applyNoDataLabels() {
        compactLevelLabel.stringValue = L10n.text(.noData)
        compactTokenLabel.stringValue = "--"
        tokenLabel.stringValue = L10n.text(.noLocalUsage)
        rateLabel.stringValue = L10n.string(.xpPerMinute, "0")
        combatLabel.stringValue = L10n.text(.noLocalTokenEvents)
    }

    private func tickBattle(tokenDelta: Int) {
        guard !isDefeated else {
            combatLabel.stringValue = L10n.text(.heroDefeated)
            return
        }

        // Split each token burst into several staggered strikes so attacks feel
        // frequent; bigger bursts use more strikes of the same energy laser.
        let tier = CombatTiming.attackTier(for: tokenDelta)
        let strikeCount = CombatTiming.burstStrikeCounts[tier]
        let comboMultiplier = 1 + 0.05 * CGFloat(comboCount)
        gainSkillEnergy(by: SkillCharge.tokenAttack)

        if comboCount >= 2 {
            battleScene.playCombo(comboCount)
        }
        combatLabel.stringValue = L10n.string(.sourceUsageTokens, activeSource, formatTokens(tokenDelta))

        let baseTokens = tokenDelta / strikeCount
        let remainder = tokenDelta % strikeCount
        for index in 0..<strikeCount {
            let strikeTokens = baseTokens + (index == strikeCount - 1 ? remainder : 0)
            let delay = CombatTiming.burstStrikeSpacing * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.playBurstStrike(strikeTokens: strikeTokens, comboMultiplier: comboMultiplier)
            }
        }
        // Skill casting disabled - only basic attacks
        updateGameLabels()
    }

    private func playBurstStrike(strikeTokens: Int, comboMultiplier: CGFloat) {
        guard !isDefeated, monsterHealth > 0, strikeTokens > 0 else {
            return
        }
        guard battleScene.monsterEngaged else {
            pendingHeroStrikes.append(
                PendingHeroStrike(tokenCount: strikeTokens, comboMultiplier: comboMultiplier)
            )
            return
        }

        let isCrit = Double.random(in: 0..<1) < CombatTiming.critChance
        let critMultiplier: CGFloat = isCrit ? 2 : 1
        // Tokens are the damage number: what you spent is what you dealt. Every
        // strike also removes at least a sliver of the bar, so even small token
        // bursts show visible progress.
        let maxHP = CGFloat(StageProgress.maxHP(stage: currentStage, monster: currentMonster, isBoss: currentMonsterIsBoss))
        let basePoints = CGFloat(strikeTokens) * SkillProgress.damageMultiplier() * critMultiplier * selectedRole.damageMultiplier
        let comboPoints = min(maxHP * 0.42, basePoints) * comboMultiplier
        let damagePoints = min(maxHP * 0.5, max(comboPoints, maxHP * CombatTiming.minimumStrikeFraction))

        // Apply item multipliers to get actual damage (same as damageMonster)
        let actualDamagePoints = damagePoints * ItemSystem.damageMultiplier() * ItemSystem.attackDamageMultiplier()
        let shownDamage = max(1, Int(actualDamagePoints.rounded()))
        let damageFraction = damagePoints / maxHP

        let resolveImpact: () -> Void = { [weak self] in
            self?.applyHeroStrikeImpact(damageFraction)
        }
        let isAnimated = battleScene.playAttack(
            damageText: formatCompact(shownDamage),
            isCrit: isCrit,
            onImpact: resolveImpact
        )
        if !isAnimated {
            resolveImpact()
        }
    }

    private func flushPendingHeroStrikes() {
        guard !isDefeated, battleScene.monsterEngaged, !pendingHeroStrikes.isEmpty else {
            return
        }

        let strikes = pendingHeroStrikes
        pendingHeroStrikes.removeAll(keepingCapacity: true)
        for strike in strikes {
            playBurstStrike(
                strikeTokens: strike.tokenCount,
                comboMultiplier: strike.comboMultiplier
            )
        }
    }

    private func applyHeroStrikeImpact(_ damageFraction: CGFloat) {
        guard !isDefeated, monsterHealth > 0 else {
            return
        }
        if let reward = damageMonster(by: damageFraction) {
            combatLabel.stringValue = defeatText(for: reward)
        }
        playCompactHeroAttack()
        updateGameLabels()
    }

    private func registerComboTick(now: Date) {
        if let lastComboAt, now.timeIntervalSince(lastComboAt) <= CombatTiming.comboWindow {
            comboCount = min(comboCount + 1, CombatTiming.maxCombo)
        } else {
            comboCount = 1
        }
        lastComboAt = now
    }

    @discardableResult
    private func damageMonster(by damageFraction: CGFloat) -> DefeatReward? {
        guard !isDefeated, monsterHealth > 0 else {
            return nil
        }

        monsterRespawnWorkItem?.cancel()
        let boostedDamage = max(0, damageFraction)
            * ItemSystem.damageMultiplier()
            * ItemSystem.attackDamageMultiplier()
        monsterHealth = max(0, monsterHealth - boostedDamage)
        battleScene.monsterHealth = monsterHealth

        guard monsterHealth <= 0 else {
            return nil
        }

        let wasBoss = currentMonsterIsBoss
        let killStage = currentStage
        totalKills += 1
        StageTracker.saveTotalKills(totalKills)
        var reward = grantExperience(for: currentMonster, isBoss: wasBoss, stage: killStage)
        if wasBoss {
            let bossGold = Int.random(in: 20...40)
            ItemSystem.addGold(bossGold)
            reward.bossGold = bossGold
        }
        battleScene.playMonsterDeath()
        reward.loot = awardLoot(isBoss: wasBoss)
        if reward.didLevelUp {
            battleScene.playLevelUp()
        }
        let nextStage = StageProgress.stage(for: totalKills)
        if nextStage > killStage {
            battleScene.playStageBanner(
                L10n.string(.stageReached, nextStage),
                isBoss: StageProgress.isBossEncounter(totalKills: totalKills)
            )
        }
        scheduleMonsterRespawn()
        updateTitleLabel()
        return reward
    }

    // Spawn a new batch without crossing a stage boundary. A boss stage starts
    // with one boss encounter; the rest of that stage returns to regular waves.
    private func spawnNextMonsterBatch() {
        let plan = MonsterEncounterPlanner.makeBatch(
            totalKills: totalKills,
            startingKind: nextMonsterKind,
            requestedCount: Int.random(in: 5...8)
        )
        guard let firstEncounter = plan.encounters.first else { return }

        nextMonsterKind = plan.nextKind
        battleScene.spawnMonsterBatch(plan.encounters)
        activateMonster(firstEncounter, announce: true)
    }

    private func activateMonster(_ encounter: MonsterEncounter, announce: Bool) {
        currentMonster = encounter.kind
        currentMonsterStage = encounter.stage
        currentMonsterIsBoss = encounter.isBoss
        monsterHealth = 1

        monsterHPLabel.textColor = currentMonster.hpColor
        monsterHPBar.fillColor = currentMonster.hpColor
        compactHeroView.monsterKind = currentMonster
        compactHeroView.isBoss = currentMonsterIsBoss

        if announce, currentMonsterIsBoss {
            combatLabel.stringValue = L10n.string(.bossAppears, currentMonster.displayName)
            battleScene.playStageBanner(L10n.string(.bossAppears, currentMonster.shortName), isBoss: true)
        } else if announce, hasRealUsageData, lootMessageExpiresAt.map({ $0 <= Date() }) != false {
            combatLabel.stringValue = L10n.string(.monsterRespawned, currentMonster.displayName)
        }
        updateTitleLabel()
        updateGameLabels()
    }

    // Called when a single monster in the batch is defeated
    private func scheduleMonsterRespawn() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            if let nextEncounter = self.battleScene.advanceToNextMonster() {
                self.activateMonster(nextEncounter, announce: true)
            } else {
                self.spawnNextMonsterBatch()
            }
        }
        monsterRespawnWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: workItem)
    }

    private func maybeMonsterAttack(now: Date) -> Bool {
        guard !isDefeated else {
            combatLabel.stringValue = L10n.text(.heroDefeated)
            return true
        }
        guard monsterHealth > 0 else {
            return false
        }
        guard battleScene.monsterEngaged else {
            return false
        }

        if let lastMonsterAttackAt,
           now.timeIntervalSince(lastMonsterAttackAt) < CombatTiming.idleAttackCooldown {
            combatLabel.stringValue = L10n.string(.monsterAttackingNoTokens, currentMonster.shortName)
            return true
        }

        lastMonsterAttackAt = now
        comboCount = 0
        lastComboAt = nil
        let damageFraction = CombatTiming.monsterDamagePerHit
            * selectedRole.idleDamageMultiplier
            * ItemSystem.idleDamageTakenMultiplier()
        let damagePoints = CombatTiming.monsterDamagePoints(for: damageFraction)
        let resolveImpact: () -> Void = { [weak self] in
            self?.applyMonsterStrikeImpact(damageFraction)
        }
        let isAnimated = battleScene.playMonsterAttack(damage: damagePoints, onImpact: resolveImpact)
        if !isAnimated {
            resolveImpact()
        }
        return true
    }

    private func applyMonsterStrikeImpact(_ damageFraction: CGFloat) {
        guard !isDefeated else {
            return
        }
        heroHealth = max(0, heroHealth - damageFraction)
        combatLabel.stringValue = L10n.string(.monsterAttackingNoTokens, currentMonster.shortName)
        playCompactMonsterAttack()
        if heroHealth <= 0 {
            enterDefeatedState()
        }
        updateGameLabels()
    }

    private func updateGameLabels() {
        if hasRealUsageData {
            compactLevelLabel.stringValue = "LV \(heroLevel)"
            compactTokenLabel.stringValue = formatTokens(todayTokens)
            tokenLabel.stringValue = L10n.string(.todayTokensGold, formatTokens(todayTokens), ItemSystem.gold)
        }
        let boostRemaining = ItemSystem.powerBoostRemaining()
        rateLabel.stringValue = boostRemaining > 0
            ? L10n.string(.tokenRateBuff, formatTokens(xpRate), boostRemaining)
            : L10n.string(.xpPerMinute, formatTokens(xpRate))
        updateSkillUI()
        updateStatLabels()
        compactHPBar.value = heroHealth
        compactXPBar.value = xpProgress
        heroHPBar.value = heroHealth
        heroXPBar.value = xpProgress
        monsterHPBar.value = monsterHealth
        battleScene.monsterHealth = monsterHealth
        let lowHPWarning = heroHealth <= 0.3 && !isDefeated
        heroHPBar.isWarning = lowHPWarning
        compactHPBar.isWarning = lowHPWarning
        updateDefeatPresentation()
    }

    private func refreshTokenActivity(now: Date, didSpendTokens: Bool, latestEventAt _: Date?) {
        if didSpendTokens {
            let expiration = now.addingTimeInterval(TokenActivity.activeDuration)
            tokenActivityExpiresAt = expiration
            scheduleTokenActivityExpiration(at: expiration)
        }

        let isActive = tokenActivityExpiresAt.map { $0 > now } ?? false
        if !isActive {
            tokenActivityExpiresAt = nil
        }
        setTokenActivity(isActive)
    }

    private func scheduleTokenActivityExpiration(at expiration: Date) {
        tokenActivityExpirationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let currentExpiration = self.tokenActivityExpiresAt,
                  currentExpiration <= Date() else {
                return
            }
            self.tokenActivityExpiresAt = nil
            self.tokenActivityExpirationWorkItem = nil
            self.setTokenActivity(false)
        }
        tokenActivityExpirationWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, expiration.timeIntervalSinceNow),
            execute: workItem
        )
    }

    private func playCompactMonsterAttack() {
        guard !isExpanded else {
            return
        }

        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -3, 2, -1, 0]
        shake.duration = 0.24
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        compactHeroView.layer?.add(shake, forKey: "compactMonsterHit")

        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [1.0, 0.42, 1.0]
        flash.duration = 0.24
        compactHPBar.layer?.add(flash, forKey: "compactMonsterHitFlash")
    }

    // Collapsed-mode feedback for hero strikes: a tiny forward jab plus a
    // pulse on the XP bar, so attacks are visible without expanding.
    private func playCompactHeroAttack() {
        guard !isExpanded else {
            return
        }

        let jab = CAKeyframeAnimation(keyPath: "transform.translation.x")
        jab.values = [0, 2.5, -1, 0]
        jab.duration = 0.2
        jab.timingFunction = CAMediaTimingFunction(name: .easeOut)
        compactHeroView.layer?.add(jab, forKey: "compactHeroJab")

        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [1.0, 0.35, 1.0]
        flash.duration = 0.22
        compactXPBar.layer?.add(flash, forKey: "compactHeroAttackFlash")
    }

    private func setTokenActivity(_ active: Bool) {
        if !active {
            tokenActivityExpiresAt = nil
            tokenActivityExpirationWorkItem?.cancel()
            tokenActivityExpirationWorkItem = nil
        }
        let effectiveActive = active && !isDefeated
        compactHeroView.setTokenActivity(effectiveActive)
        battleScene.tokenActivity = effectiveActive
    }

    private func updateSkillUI() {
        let loadout = SkillProgress.loadout()
        let points = SkillProgress.availablePoints(heroLevel: heroLevel)
        skillLabel.stringValue = points == 1 ? L10n.text(.skillPointShort) : L10n.string(.skillPointsShort, points)
        skillEnergyBar.value = skillEnergy

        guard !isDefeated else {
            skillEnergyLabel.stringValue = L10n.text(.heroDefeated)
            return
        }

        let unlockedSkillCount = HeroSkill.allCases.filter { loadout.rank(for: $0) > 0 }.count
        let castCandidates = SkillProgress.autoCastCandidates(loadout: loadout)
        guard !castCandidates.isEmpty else {
            skillEnergyLabel.stringValue = unlockedSkillCount == 0 ? L10n.text(.noSkillEquipped) : L10n.text(.noSkillEnabled)
            return
        }

        if skillEnergy >= 1 {
            skillEnergyLabel.stringValue = L10n.string(.skillReadyStatus, "\(castCandidates.count)")
        } else {
            let energy = percentValue(skillEnergy)
            skillEnergyLabel.stringValue = L10n.string(.skillEnergyPercent, energy, 100, energy)
        }
    }

    private func gainSkillEnergy(by amount: CGFloat) {
        guard !isDefeated else {
            return
        }

        let loadout = SkillProgress.loadout()
        guard loadout.totalRanks > 0 else {
            return
        }

        let treeBonus = min(0.05, CGFloat(loadout.totalRanks) * 0.004)
        let overclockBonus = CGFloat(loadout.overclockCore) * 0.01
        skillEnergy = min(1, skillEnergy + (amount + treeBonus + overclockBonus) * ItemSystem.skillChargeMultiplier())
    }

    private func applyExperienceState(saveLevel: Bool) {
        let state = ExperienceCurve.state(for: heroExperience)
        heroLevel = state.level
        currentXP = state.currentXP
        requiredXP = state.requiredXP
        xpProgress = state.progress
        if saveLevel {
            SkillProgress.saveHeroLevel(heroLevel)
        }
    }

    private func grantExperience(for monster: MonsterKind, isBoss: Bool, stage: Int) -> DefeatReward {
        let previousLevel = heroLevel
        let rewardXP = max(1, Int((CGFloat(monster.xpReward) * StageProgress.xpMultiplier(stage: stage, isBoss: isBoss)).rounded()))
        heroExperience += rewardXP
        HeroExperience.saveTotalXP(heroExperience)
        applyExperienceState(saveLevel: true)
        return DefeatReward(
            monsterName: monster.displayName,
            xpGained: rewardXP,
            didLevelUp: heroLevel > previousLevel,
            level: heroLevel,
            loot: nil
        )
    }

    private func defeatText(for reward: DefeatReward) -> String {
        var summaryParts: [String] = []
        if let loot = reward.loot {
            summaryParts.append(lootSummary(for: loot))
        }
        if reward.bossGold > 0 {
            summaryParts.append(L10n.string(.lootGoldSummary, reward.bossGold))
        }
        if !summaryParts.isEmpty {
            lootMessageExpiresAt = Date().addingTimeInterval(4)
            return L10n.string(.defeatedMonsterXPAndLoot, reward.monsterName, reward.xpGained, summaryParts.joined(separator: " · "))
        }
        if reward.didLevelUp {
            return L10n.string(.levelUpFromMonsterXP, reward.monsterName, reward.xpGained, reward.level)
        }
        return L10n.string(.defeatedMonsterXP, reward.monsterName, reward.xpGained)
    }

    private func awardLoot(isBoss: Bool) -> LootDrop? {
        guard let drop = ItemSystem.rollDrop(isBoss: isBoss) else {
            return nil
        }

        let awardedDrop: LootDrop
        switch drop.kind {
        case .healthPotion:
            let previousHP = statValue(heroHealth, maxValue: GameStats.heroMaxHP)
            heroHealth = min(1, heroHealth + CGFloat(drop.amount) / CGFloat(GameStats.heroMaxHP))
            let healedHP = max(0, statValue(heroHealth, maxValue: GameStats.heroMaxHP) - previousHP)
            awardedDrop = LootDrop(kind: .healthPotion, amount: healedHP)
        case .powerBoost:
            ItemSystem.activatePowerBoost()
            awardedDrop = drop
        case .gold:
            ItemSystem.addGold(drop.amount)
            awardedDrop = drop
        case .equipment:
            guard let equipment = drop.equipment else {
                return nil
            }
            switch ItemSystem.awardEquipment(equipment) {
            case .equipped(let awarded):
                battleScene.showFloatingText(
                    awarded.summary,
                    color: awarded.rarity.color,
                    fontSize: 10,
                    anchor: .center
                )
            case .salvaged(let awarded, let gold):
                battleScene.showFloatingText(
                    L10n.string(.equipmentSalvaged, awarded.displayName, gold),
                    color: awarded.rarity.color,
                    fontSize: 10,
                    anchor: .center
                )
            }
            awardedDrop = drop
        }

        battleScene.playLootDrop(awardedDrop)
        return awardedDrop
    }

    private func lootSummary(for drop: LootDrop) -> String {
        switch drop.kind {
        case .healthPotion:
            L10n.string(.lootPotionSummary, drop.kind.name, drop.amount)
        case .powerBoost:
            L10n.string(.lootBuffSummary, drop.kind.name, drop.amount)
        case .gold:
            L10n.string(.lootGoldSummary, drop.amount)
        case .equipment:
            drop.equipment?.summary ?? drop.kind.name
        }
    }

    private func updateStatLabels() {
        let hpPercent = percentValue(heroHealth)
        let xpPercent = percentValue(xpProgress)
        let heroHP = preciseStatValue(heroHealth, maxValue: GameStats.heroMaxHP)
        let heroHPText = formatHealth(heroHP)
        let monsterMaxHP = StageProgress.maxHP(stage: currentStage, monster: currentMonster, isBoss: currentMonsterIsBoss)
        let monsterHP = statValue(monsterHealth, maxValue: monsterMaxHP)
        compactHPLabel.stringValue = heroHPText
        compactXPLabel.stringValue = "\(formatCompact(currentXP))"
        heroHPLabel.stringValue = L10n.string(.hpPercent, heroHPText, GameStats.heroMaxHP, hpPercent)
        heroXPLabel.stringValue = L10n.string(.xpPercent, formatCompact(currentXP), formatCompact(requiredXP), xpPercent)
        let monsterName = currentMonsterIsBoss
            ? L10n.string(.bossMonsterName, currentMonster.shortName)
            : currentMonster.shortName
        monsterHPLabel.stringValue = L10n.string(.monsterHP, monsterName, formatCompact(monsterHP), formatCompact(monsterMaxHP), percentValue(monsterHealth))
    }

    private func enterDefeatedState() {
        guard !isDefeated else {
            return
        }

        isDefeated = true
        pendingHeroStrikes.removeAll()
        heroHealth = 0
        setTokenActivity(false)
        combatLabel.stringValue = L10n.text(.heroDefeated)
        updateDefeatPresentation()
        updateGameLabels()
    }

    private func reviveHeroFromTokenSpend() {
        isDefeated = false
        heroHealth = CombatTiming.reviveHealth
        lastMonsterAttackAt = nil
        comboCount = 0
        lastComboAt = nil
        combatLabel.stringValue = L10n.text(.heroReviving)
        updateDefeatPresentation()
        playReviveEffects(restoredHP: statValue(CombatTiming.reviveHealth, maxValue: GameStats.heroMaxHP))
        setTokenActivity(false)
    }

    private func playReviveEffects(restoredHP: Int) {
        battleScene.playHeroReviveHeal(restoredHP: restoredHP)

        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [0.82, 1.22, 1.0]
        pulse.keyTimes = [0, 0.48, 1]
        pulse.duration = 0.42
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        compactHeroView.layer?.add(pulse, forKey: "compactHeroRevivePulse")

        let glow = CAKeyframeAnimation(keyPath: "opacity")
        glow.values = [0.45, 1.0, 0.72]
        glow.keyTimes = [0, 0.44, 1]
        glow.duration = 0.42
        glow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        compactHPBar.layer?.add(glow, forKey: "compactHPReviveGlow")
    }

    private func updateDefeatPresentation() {
        compactHeroView.monsterKind = currentMonster
        compactHeroView.isBoss = currentMonsterIsBoss
        if isDefeated {
            compactHeroView.kind = .monster
            compactHeroView.setTokenActivity(false)
            compactHeroView.setWalking(false)
        } else {
            compactHeroView.kind = .hero
            compactHeroView.setWalking(!isExpanded && battleScene.worldIsMoving)
        }
        battleScene.heroDefeated = isDefeated
    }

    private func percentValue(_ value: CGFloat) -> Int {
        min(100, max(0, Int(round(value * 100))))
    }

    private func statValue(_ value: CGFloat, maxValue: Int) -> Int {
        min(maxValue, max(0, Int(round(value * CGFloat(maxValue)))))
    }

    private func preciseStatValue(_ value: CGFloat, maxValue: Int) -> CGFloat {
        min(CGFloat(maxValue), max(0, value * CGFloat(maxValue)))
    }

    private func formatHealth(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    // Token counts: abbreviated with K/M
    private func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    // Game values (HP, damage, XP): full number
    private func formatCompact(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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

    static func styles(for screen: NSScreen?, expandedNotchHeight: CGFloat? = nil) -> (collapsed: NotchStyle, expanded: NotchStyle) {
        let topBarHeight = screen.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? fallbackCollapsed.notchSize.height
        let collapsed = makeCollapsed(topBarHeight: topBarHeight)
        return (collapsed, makeExpanded(collapsed: collapsed, requestedHeight: expandedNotchHeight, screen: screen))
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

    /// `requestedHeight` lets the session list ask for a taller panel than the
    /// game HUD needs, so a long list is readable instead of clipped to three
    /// rows. It only ever grows the panel, and never past `heightCap`.
    private static func makeExpanded(
        collapsed: NotchStyle,
        requestedHeight: CGFloat? = nil,
        screen: NSScreen? = nil
    ) -> NotchStyle {
        let base = round(collapsed.notchSize.height + 112)
        let height = min(max(base, requestedHeight.map { round($0) } ?? base), heightCap(for: screen, base: base))
        let width = round(max(468, collapsed.notchSize.width + 260))

        return NotchStyle(
            windowSize: NSSize(width: width + 34, height: height + 18),
            notchSize: NSSize(width: width, height: height),
            topInset: 0,
            cornerRadius: round(min(34, base * 0.28)),
            shadowRadius: 24,
            shadowOpacity: 0.52
        )
    }

    /// However many sessions are open, the panel stops at 45% of the display so
    /// it stays an overlay rather than a window; past that the list scrolls.
    private static func heightCap(for screen: NSScreen?, base: CGFloat) -> CGFloat {
        guard let screenHeight = screen?.frame.height else {
            return base
        }
        // The window adds 18pt of shadow padding below the notch shape.
        return max(base, round(screenHeight * 0.45) - 18)
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

enum CombatTiming {
    static let monsterAttackInterval: TimeInterval = 2
    static let idleAttackCooldown: TimeInterval = 1.8
    static let monsterDamagePerHit: CGFloat = 1 / 900
    static let reviveHealth: CGFloat = 0.28
    static let comboWindow: TimeInterval = 12
    static let maxCombo = 10
    static let critChance = 0.12
    // Every burst strike removes at least this fraction of the monster's HP
    // bar, so even tiny token bursts read on the bar.
    static let minimumStrikeFraction: CGFloat = 0.02

    // Attack intensity tiers keyed by tokens per scan burst. Higher tiers get
    // more staggered strikes and stronger visuals.
    static let burstStrikeCounts = [1, 2, 3, 5]
    static let burstStrikeSpacing: TimeInterval = 0.32

    static func monsterDamagePoints(for damageFraction: CGFloat) -> CGFloat {
        max(0, damageFraction) * CGFloat(GameStats.heroMaxHP)
    }

    static func attackTier(for tokenDelta: Int) -> Int {
        switch tokenDelta {
        case ..<60:
            return 0
        case 60..<250:
            return 1
        case 250..<900:
            return 2
        default:
            return 3
        }
    }
}

private enum TokenActivity {
    // Longer duration to cover refresh intervals (file monitor debounce + scan time)
    static let activeDuration: TimeInterval = 15
}

private enum SkillCharge {
    static let tokenAttack: CGFloat = 0.18
}

private struct LevelState {
    let level: Int
    let progress: CGFloat
    let currentXP: Int
    let requiredXP: Int
}

private struct DefeatReward {
    let monsterName: String
    let xpGained: Int
    let didLevelUp: Bool
    let level: Int
    var loot: LootDrop?
    var bossGold = 0
}

private enum GameStats {
    static let heroMaxHP = 100
}

private enum StageTracker {
    private static let totalKillsKey = "VibeHero.totalKills"

    static func loadTotalKills() -> Int {
        max(0, UserDefaults.standard.integer(forKey: totalKillsKey))
    }

    static func saveTotalKills(_ kills: Int) {
        UserDefaults.standard.set(max(0, kills), forKey: totalKillsKey)
    }
}

enum StageProgress {
    static let killsPerStage = 8
    static let bossStageInterval = 5

    static func stage(for totalKills: Int) -> Int {
        max(0, totalKills) / killsPerStage + 1
    }

    static func isBossStage(_ stage: Int) -> Bool {
        stage > 0 && stage % bossStageInterval == 0
    }

    static func killsIntoStage(for totalKills: Int) -> Int {
        max(0, totalKills) % killsPerStage
    }

    // A boss is the first encounter of every boss stage. Deriving this from the
    // persisted kill count makes it survive relaunches without separate flags.
    static func isBossEncounter(totalKills: Int) -> Bool {
        let stage = stage(for: totalKills)
        return isBossStage(stage) && killsIntoStage(for: totalKills) == 0
    }

    // Absolute HP pool: the monster's stat scaled into token-sized units, then
    // deepened by stage and boss factors. These factors used to divide incoming
    // damage instead — same overall pace, but folded into max HP so the bar
    // always moves visibly.
    static func maxHP(stage: Int, monster: MonsterKind, isBoss: Bool) -> Int {
        let stageFactor = 1 + 0.10 * CGFloat(max(1, stage) - 1)
        let bossFactor: CGFloat = isBoss ? 2.2 : 1
        return max(1, Int((CGFloat(monster.maxHP) * 100 * stageFactor * bossFactor).rounded()))
    }

    static func xpMultiplier(stage: Int, isBoss: Bool) -> CGFloat {
        let stageFactor = 1 + 0.08 * CGFloat(max(1, stage) - 1)
        return stageFactor * (isBoss ? 2 : 1)
    }
}

struct MonsterBatchPlan: Equatable {
    let encounters: [MonsterEncounter]
    let nextKind: MonsterKind
}

enum MonsterEncounterPlanner {
    static func makeBatch(
        totalKills: Int,
        startingKind: MonsterKind,
        requestedCount: Int
    ) -> MonsterBatchPlan {
        let completedKills = max(0, totalKills)
        let stage = StageProgress.stage(for: completedKills)
        let killsIntoStage = StageProgress.killsIntoStage(for: completedKills)
        let remainingInStage = StageProgress.killsPerStage - killsIntoStage
        let count = StageProgress.isBossEncounter(totalKills: completedKills)
            ? 1
            : min(max(1, requestedCount), remainingInStage)

        var nextKind = startingKind
        var encounters: [MonsterEncounter] = []
        encounters.reserveCapacity(count)

        for offset in 0..<count {
            let encounterKills = completedKills + offset
            encounters.append(
                MonsterEncounter(
                    kind: nextKind,
                    stage: stage,
                    isBoss: StageProgress.isBossEncounter(totalKills: encounterKills)
                )
            )
            nextKind = nextKind.next
        }

        return MonsterBatchPlan(encounters: encounters, nextKind: nextKind)
    }
}

private enum HeroExperience {
    private static let totalXPKey = "VibeHero.heroTotalXP"
    private static let migrationKey = "VibeHero.heroXPInitializedFromLevel"

    static func loadTotalXP() -> Int {
        if UserDefaults.standard.object(forKey: totalXPKey) != nil {
            return max(0, UserDefaults.standard.integer(forKey: totalXPKey))
        }

        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return 0
        }

        let migratedXP = ExperienceCurve.totalXPRequired(toReach: SkillProgress.loadHeroLevel())
        saveTotalXP(migratedXP)
        UserDefaults.standard.set(true, forKey: migrationKey)
        return migratedXP
    }

    static func saveTotalXP(_ totalXP: Int) {
        UserDefaults.standard.set(max(0, totalXP), forKey: totalXPKey)
    }
}

private enum ExperienceCurve {
    private static let nextLevelRequirements = [
        120,
        260,
        450,
        700,
        1_000,
        1_360,
        1_780,
        2_260,
        2_800,
        3_400,
        4_060,
        4_780
    ]

    static func state(for totalXP: Int) -> LevelState {
        var remainingXP = max(0, totalXP)
        var level = 0
        var nextRequirement = requirementForNextLevel(from: level)

        while remainingXP >= nextRequirement {
            remainingXP -= nextRequirement
            level += 1
            nextRequirement = requirementForNextLevel(from: level)
        }

        let progress = CGFloat(remainingXP) / CGFloat(max(1, nextRequirement))
        return LevelState(
            level: level,
            progress: min(max(progress, 0), 1),
            currentXP: remainingXP,
            requiredXP: nextRequirement
        )
    }

    static func totalXPRequired(toReach level: Int) -> Int {
        guard level > 0 else {
            return 0
        }

        return (0..<level).reduce(0) { total, currentLevel in
            total + requirementForNextLevel(from: currentLevel)
        }
    }

    private static func requirementForNextLevel(from level: Int) -> Int {
        if level < nextLevelRequirements.count {
            return nextLevelRequirements[level]
        }

        let extraLevel = level - nextLevelRequirements.count + 1
        return (nextLevelRequirements.last ?? 4_780) + extraLevel * 820
    }
}

enum ScreenPinning {
    private static let defaultsKey = "VibeHero.pinnedDisplayID"

    static func load() -> Int? {
        let value = UserDefaults.standard.integer(forKey: defaultsKey)
        return value == 0 ? nil : value
    }

    static func save(_ displayID: Int?) {
        if let displayID {
            UserDefaults.standard.set(displayID, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    static func preferredScreen() -> NSScreen? {
        if let displayID = load(),
           let screen = NSScreen.screens.first(where: { $0.notchDisplayID == displayID }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

extension NSScreen {
    var notchDisplayID: Int? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue
    }

    var notchDisplayName: String {
        let size = frame.size
        return "\(localizedName) (\(Int(size.width)) x \(Int(size.height)))"
    }
}

enum HeroRole: String, CaseIterable {
    case pm
    case designer
    case artist
    case engineer
    case qa
    case other

    private static let defaultsKey = "VibeHero.selectedRole"

    var label: String {
        switch self {
        case .pm: L10n.text(.rolePMLabel)
        case .designer: L10n.text(.roleDesignerLabel)
        case .artist: L10n.text(.roleArtistLabel)
        case .engineer: L10n.text(.roleEngineerLabel)
        case .qa: L10n.text(.roleQALabel)
        case .other: L10n.text(.roleOtherLabel)
        }
    }

    var detail: String {
        switch self {
        case .pm: L10n.text(.rolePMDetail)
        case .designer: L10n.text(.roleDesignerDetail)
        case .artist: L10n.text(.roleArtistDetail)
        case .engineer: L10n.text(.roleEngineerDetail)
        case .qa: L10n.text(.roleQADetail)
        case .other: L10n.text(.roleOtherDetail)
        }
    }

    var perk: String {
        switch self {
        case .pm: L10n.text(.rolePMPerk)
        case .designer: L10n.text(.roleDesignerPerk)
        case .artist: L10n.text(.roleArtistPerk)
        case .engineer: L10n.text(.roleEngineerPerk)
        case .qa: L10n.text(.roleQAPerk)
        case .other: L10n.text(.roleOtherPerk)
        }
    }

    var damageMultiplier: CGFloat {
        switch self {
        case .engineer: 1.15
        case .pm: 1.04
        default: 1.0
        }
    }

    var idleDamageMultiplier: CGFloat {
        switch self {
        case .qa: 0.75
        case .artist: 0.82
        case .pm: 0.92
        default: 1.0
        }
    }

    static func load() -> HeroRole {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
              let role = HeroRole(rawValue: rawValue) else {
            return .other
        }
        return role
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
        NotificationCenter.default.post(name: .vibeHeroRoleChanged, object: self)
    }
}

extension Notification.Name {
    static let vibeHeroRoleChanged = Notification.Name("VibeHero.roleChanged")
}
