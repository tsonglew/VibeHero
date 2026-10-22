import AppKit

final class NotchContentView: NSView {
    let capsuleLayer = CAShapeLayer()
    let glowLayer = CAGradientLayer()

    let collapsedHUD = NSView()
    let compactHeroView = PixelActorView(kind: .hero)
    let compactLevelLabel = NSTextField(labelWithString: "")
    let compactTokenLabel = NSTextField(labelWithString: "")
    let compactStatusLabel = NSTextField(labelWithString: "")
    let compactHPLabel = NSTextField(labelWithString: "")
    let compactXPLabel = NSTextField(labelWithString: "")
    let compactHPBar = PixelBarView()
    let compactXPBar = PixelBarView()

    let expandedHUD = NSView()
    /// Holds everything that belongs to game mode, so the session list can hide
    /// all of it at once.
    let gameHUD = NSView()
    let battleScene = BattleSceneView()
    let sessionListView = SessionListView()
    let campButton = NSButton()
    let viewToggleButton = NSButton()
    var isShowingSessions = false
    let titleLabel = NSTextField(labelWithString: "")
    let tokenLabel = NSTextField(labelWithString: "")
    let goldLabel = NSTextField(labelWithString: "")
    let rateLabel = NSTextField(labelWithString: "")
    let skillLabel = NSTextField(labelWithString: "")
    let skillEnergyLabel = NSTextField(labelWithString: "")
    let skillEnergyBar = PixelBarView()
    let combatLabel = NSTextField(labelWithString: "")
    let mechanicLabel = NSTextField(labelWithString: "")
    let heroHPLabel = NSTextField(labelWithString: "")
    let heroXPLabel = NSTextField(labelWithString: "")
    let monsterHPLabel = NSTextField(labelWithString: "")
    let heroHPBar = PixelBarView()
    let heroXPBar = PixelBarView()
    let monsterHPBar = PixelBarView()
    let settingsButton = NSButton()
    private(set) var reservedHeaderActionFrame = NSRect.zero

    var trackingArea: NSTrackingArea?
    var collapsedStyle: NotchStyle
    var expandedStyle: NotchStyle
    var style: NotchStyle
    var isExpanded = false
    private(set) var presentationVisible: Bool
    private(set) var reduceMotion: Bool

    var presentationPolicy: HUDPresentationPolicy {
        HUDPresentationPolicy(isVisible: presentationVisible, isExpanded: isExpanded,
                              showsSessions: isShowingSessions, reduceMotion: reduceMotion,
                              isCamping: isCamping)
    }
    let monitorsEnabled: Bool
    var usageTimer: Timer?
    var usageScanInFlight = false
    var usageRefreshWorkItem: DispatchWorkItem?
    var monsterAttackTimer: Timer?
    /// One source per watched root. Held for the view's lifetime, which is the
    /// app's lifetime.
    var fileMonitors: [DispatchSourceFileSystemObject] = []
    var fileMonitorQueue = DispatchQueue(label: "com.vibehero.filemonitor", qos: .utility)
    var heroLevel = SkillProgress.loadHeroLevel()
    var heroExperience = HeroExperience.loadTotalXP()
    var currentXP = 0
    var requiredXP = 1
    var xpProgress: CGFloat = 0
    var heroHealth: CGFloat = 1
    var monsterHealth: CGFloat = 0.74
    var todayTokens = 0
    var xpRate = 0
    var activeSource = ""
    var usageCursor = TokenUsageCursor()
    var lastTokenSpendAt: Date?
    var lastMonsterAttackAt: Date?
    var tokenActivityExpiresAt: Date?
    var tokenActivityExpirationWorkItem: DispatchWorkItem?
    var monsterRespawnWorkItem: DispatchWorkItem?
    var currentMonster = MonsterKind.promptWraith
    var nextMonsterKind = MonsterKind.promptWraith
    var hasRealUsageData = false
    var skillEnergy: CGFloat = 0
    var skillCooldowns: [HeroSkill: Date] = [:]
    var skillModifiers = SkillTreeProgress.modifiers()
    var lastPassiveRecoveryAt = Date()
    var lootMessageExpiresAt: Date?
    var isDefeated = false
    var isCamping = CampProgress.load()
    var monsterMechanics = MonsterMechanicsState()
    var lastMonsterRecoveryAt = Date()
    var selectedRole = HeroRole.load()
    var totalKills = StageTracker.loadTotalKills()
    var currentMonsterStage = 1
    var currentMonsterIsBoss = false
    var comboCount = 0
    var damageBank = CombatDamageBank()
    var tokenAccounting = TokenCombatAccounting()

    var currentStage: Int {
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
    static let sessionListChrome: CGFloat = 53

    var lastRequestedExpandedHeight: CGFloat?

    /// Notch height the expanded panel would like. `nil` in game mode, where the
    /// default expanded size is exactly right.
    var preferredExpandedNotchHeight: CGFloat? {
        guard isShowingSessions else { return nil }
        return sessionListView.preferredContentHeight + Self.sessionListChrome
    }

    init(frame frameRect: NSRect, collapsedStyle: NotchStyle, expandedStyle: NotchStyle, startMonitors: Bool = true,
         presentationVisible: Bool = false, reduceMotion: Bool = false) {
        self.collapsedStyle = collapsedStyle
        self.expandedStyle = expandedStyle
        self.style = collapsedStyle
        self.monitorsEnabled = startMonitors
        self.presentationVisible = presentationVisible
        self.reduceMotion = reduceMotion
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
        initializeCampState()
        updateGameLabels()
        setExpanded(false, animated: false)
        if monitorsEnabled {
            startUsageMonitor()
        }
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
        applyPresentationPolicy()
        compactHeroView.setWalking(!isExpanded && battleScene.worldIsMoving && !isDefeated)
        style = isExpanded ? expandedStyle : collapsedStyle

        let changes = {
            self.collapsedHUD.isHidden = isExpanded
            self.collapsedHUD.alphaValue = isExpanded ? 0 : 1
            self.expandedHUD.alphaValue = isExpanded ? 1 : 0
            self.expandedHUD.isHidden = !isExpanded
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
        }

        if animated && presentationPolicy.animatesWindow {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                changes()
            }
        } else {
            changes()
        }
    }

    /// The window supplies actual visibility and the accessibility preference.
    /// Tests and offline rendering supply these explicitly, without reading the host.
    func setPresentation(visible: Bool, reduceMotion: Bool) {
        presentationVisible = visible
        self.reduceMotion = reduceMotion
        applyPresentationPolicy()
    }

    func applyPresentationPolicy() {
        let policy = presentationPolicy
        battleScene.setPresentation(visible: policy.showsBattle, reduceMotion: policy.reduceMotion)
        compactHeroView.animationsEnabled = policy.animatesCompact
        for bar in [compactHPBar, compactXPBar] { bar.animationsEnabled = policy.animatesCompact }
        for bar in [heroHPBar, heroXPBar, monsterHPBar, skillEnergyBar] {
            bar.animationsEnabled = policy.animatesBattle
        }
        if !policy.animatesCompact {
            for view in [compactHeroView as NSView, compactHPBar, compactXPBar] {
                view.layer?.removeAllAnimations()
            }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.removeAllAnimations()
        glowLayer.opacity = policy.animatesBattle ? 0.18 : 0
        CATransaction.commit()
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

        // Lay out only the HUD that is actually on screen. The other one gets a
        // degenerate frame at the current notch size (or worse, the expanded
        // size while collapsed) and its content would otherwise render through
        // on top of the active HUD.
        if isExpanded {
            layoutExpandedHUD(in: notchRect)
        } else {
            layoutCollapsedHUD(in: notchRect)
        }

        CATransaction.commit()
    }

    func setupLayers() {
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


    }

    func setupCollapsedHUD() {
        compactLevelLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        compactLevelLabel.textColor = .white
        compactTokenLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        compactTokenLabel.textColor = .white.withAlphaComponent(0.86)
        compactTokenLabel.alignment = .right
        compactStatusLabel.font = .systemFont(ofSize: 9, weight: .medium)
        compactStatusLabel.textColor = .white.withAlphaComponent(0.70)
        for label in [compactLevelLabel, compactTokenLabel, compactStatusLabel] {
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
        }
        // Keep exact HP/XP in accessibility and the expanded view; these
        // micro labels previously needed 6pt text to fit the hardware notch.
        compactHPLabel.isHidden = true
        compactXPLabel.isHidden = true
        compactXPBar.isHidden = true
        compactHPBar.fillColor = NSColor(red: 0.40, green: 0.78, blue: 0.64, alpha: 1)
        compactHPBar.setAccessibilityElement(true)
        compactHPBar.setAccessibilityRole(.progressIndicator)
        for child in [compactHeroView, compactLevelLabel, compactTokenLabel, compactStatusLabel,
                      compactHPLabel, compactXPLabel, compactHPBar, compactXPBar] {
            collapsedHUD.addSubview(child)
        }
        addSubview(collapsedHUD)
    }

    func setupExpandedHUD() {
        battleScene.onWorldMotionChanged = { [weak self] isMoving in
            guard let self, !self.isExpanded else { return }
            self.compactHeroView.setWalking(isMoving && !self.isDefeated)
        }
        battleScene.onMonsterEngaged = { [weak self] in
            self?.handleMonsterEngaged()
        }

        expandedHUD.appearance = NSAppearance(named: .darkAqua)
        for label in [titleLabel, tokenLabel, goldLabel, rateLabel, skillLabel, skillEnergyLabel,
                      combatLabel, mechanicLabel, heroHPLabel, heroXPLabel, monsterHPLabel] {
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            label.textColor = .white.withAlphaComponent(0.78)
        }
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        tokenLabel.alignment = .left
        goldLabel.alignment = .center
        skillLabel.alignment = .right
        monsterHPLabel.alignment = .right
        combatLabel.font = .systemFont(ofSize: 10, weight: .medium)
        combatLabel.alignment = .left
        mechanicLabel.font = .systemFont(ofSize: 10, weight: .medium)
        mechanicLabel.alignment = .center
        // An opaque sky-colored strip keeps stars and the moon out of text.
        mechanicLabel.drawsBackground = true
        mechanicLabel.backgroundColor = NSColor(red: 0.024, green: 0.05, blue: 0.12, alpha: 1)
        mechanicLabel.wantsLayer = true
        mechanicLabel.layer?.cornerRadius = 3
        mechanicLabel.layer?.masksToBounds = true
        skillEnergyLabel.font = .systemFont(ofSize: 10, weight: .medium)
        skillEnergyLabel.alignment = .left
        rateLabel.isHidden = true
        heroXPLabel.isHidden = true

        heroHPBar.fillColor = NSColor(red: 0.40, green: 0.78, blue: 0.64, alpha: 1)
        heroXPBar.fillColor = NSColor(red: 0.42, green: 0.66, blue: 0.86, alpha: 1)
        monsterHPBar.fillColor = currentMonster.hpColor
        skillEnergyBar.fillColor = NSColor(red: 0.82, green: 0.68, blue: 0.40, alpha: 1)
        for bar in [heroHPBar, heroXPBar, monsterHPBar, skillEnergyBar] {
            bar.trackColor = .white.withAlphaComponent(0.10)
            bar.setAccessibilityElement(true)
            bar.setAccessibilityRole(.progressIndicator)
        }
        battleScene.showsOverheadHealth = false
        for button in [campButton, settingsButton, viewToggleButton] {
            button.imagePosition = .imageOnly
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.contentTintColor = .white.withAlphaComponent(0.82)
            button.refusesFirstResponder = false
            button.focusRingType = .exterior
            button.target = self
        }
        campButton.setButtonType(.toggle)
        campButton.action = #selector(toggleCamp)
        updateCampUI()
        settingsButton.action = #selector(openSettings)
        updateSettingsButton()
        viewToggleButton.action = #selector(toggleView)
        updateViewToggleButton()

        // Game-mode content is grouped in one container so switching to the
        // session list is a single `isHidden`. It used to be a hardcoded array of
        // 12 views in `toggleView()`, which any new HUD element had to be added
        // to or it would render on top of the session list.
        gameHUD.addSubview(battleScene)
        gameHUD.addSubview(skillEnergyBar)
        gameHUD.addSubview(heroHPBar)
        gameHUD.addSubview(heroXPBar)
        gameHUD.addSubview(monsterHPBar)
        gameHUD.addSubview(tokenLabel)
        gameHUD.addSubview(goldLabel)
        gameHUD.addSubview(rateLabel)
        gameHUD.addSubview(skillLabel)
        gameHUD.addSubview(skillEnergyLabel)
        gameHUD.addSubview(heroHPLabel)
        gameHUD.addSubview(heroXPLabel)
        gameHUD.addSubview(monsterHPLabel)
        gameHUD.addSubview(combatLabel)
        gameHUD.addSubview(mechanicLabel)

        // Added once, in final z-order: bars under labels, chrome over the game
        // HUD, session list on top. `layoutExpandedHUD` only sets frames now, so
        // the order no longer depends on a layout pass having run.
        expandedHUD.addSubview(gameHUD)
        expandedHUD.addSubview(titleLabel)
        expandedHUD.addSubview(campButton)
        expandedHUD.addSubview(settingsButton)
        expandedHUD.addSubview(viewToggleButton)
        expandedHUD.addSubview(sessionListView)
        sessionListView.isHidden = true
        addSubview(expandedHUD)

        // Setup session monitoring. Register as an observer (not a single
        // callback) so the settings window's session list can observe in
        // parallel without stealing the HUD's updates.
        if monitorsEnabled {
            SessionMonitor.shared.addObserver(self) { [weak self] sessions in
                Task { @MainActor in
                    guard let self else { return }
                    self.sessionListView.updateSessions(sessions)
                    self.notifyExpandedHeightIfChanged()
                }
            }
        }
    }

    /// Tells the window to resize only when the wanted height actually moved -
    /// scans land every few seconds and most of them change nothing.
    func notifyExpandedHeightIfChanged() {
        let requested = preferredExpandedNotchHeight
        guard requested != lastRequestedExpandedHeight else { return }
        lastRequestedExpandedHeight = requested
        onExpandedHeightChanged?()
    }

    func layoutCollapsedHUD(in notchRect: NSRect) {
        collapsedHUD.frame = notchRect.insetBy(dx: 10, dy: 2)
        let height = collapsedHUD.bounds.height
        let heroSize = min(24, height)
        compactHeroView.frame = NSRect(x: 0, y: (height - heroSize) / 2, width: heroSize, height: heroSize)
        let textX = heroSize + 6
        let textWidth = max(0, collapsedHUD.bounds.width - textX)
        let levelWidth = min(56, textWidth * 0.42)
        compactLevelLabel.frame = NSRect(x: textX, y: height - 13, width: levelWidth, height: 13)
        compactTokenLabel.frame = NSRect(x: textX + levelWidth + 4, y: height - 13,
                                       width: max(0, textWidth - levelWidth - 4), height: 13)
        compactStatusLabel.frame = NSRect(x: textX, y: 2, width: textWidth, height: min(11, height - 15))
        compactHPBar.frame = NSRect(x: textX, y: 0, width: textWidth, height: 2)
        for hidden in [compactHPLabel, compactXPLabel, compactXPBar] { hidden.frame = .zero }
    }

    func layoutExpandedHUD(in notchRect: NSRect) {
        expandedHUD.frame = notchRect.insetBy(dx: 16, dy: 10)
        let width = expandedHUD.bounds.width
        let height = expandedHUD.bounds.height
        gameHUD.frame = expandedHUD.bounds
        // Three dedicated 24pt actions with 6pt gaps keep data out of controls.
        let actionY = height - 24
        reservedHeaderActionFrame = NSRect(x: width - 84, y: actionY, width: 24, height: 24)
        campButton.frame = reservedHeaderActionFrame
        viewToggleButton.frame = NSRect(x: width - 54, y: actionY, width: 24, height: 24)
        settingsButton.frame = NSRect(x: width - 24, y: actionY, width: 24, height: 24)
        titleLabel.frame = NSRect(x: 0, y: height - 21, width: max(0, width - 96), height: 16)
        let resourceY = height - 44
        tokenLabel.frame = NSRect(x: 0, y: resourceY, width: width * 0.43, height: 16)
        goldLabel.frame = NSRect(x: width * 0.43, y: resourceY, width: width * 0.30, height: 16)
        skillLabel.frame = NSRect(x: width * 0.73, y: resourceY, width: width * 0.27, height: 16)
        let statWidth = (width - 20) / 2
        heroHPLabel.frame = NSRect(x: 0, y: height - 62, width: statWidth, height: 13)
        monsterHPLabel.frame = NSRect(x: width - statWidth, y: height - 62, width: statWidth, height: 13)
        heroHPBar.frame = NSRect(x: 0, y: height - 68, width: statWidth, height: 3)
        monsterHPBar.frame = NSRect(x: width - statWidth, y: height - 68, width: statWidth, height: 3)
        battleScene.frame = NSRect(x: 0, y: 48, width: width, height: max(70, height - 120))
        // The scene has sky above its grounded actors. Keep mechanics here,
        // away from transient rewards and the skill-energy status below it.
        mechanicLabel.frame = NSRect(x: 8, y: battleScene.frame.maxY - 17, width: max(0, width - 16), height: 14)
        heroXPBar.frame = NSRect(x: 0, y: 42, width: width, height: 2)
        combatLabel.frame = NSRect(x: 0, y: 23, width: width, height: 14)
        skillEnergyLabel.frame = NSRect(x: 0, y: 5, width: width, height: 13)
        skillEnergyBar.frame = NSRect(x: 0, y: 0, width: width, height: 2)
        rateLabel.frame = .zero
        heroXPLabel.frame = .zero
        let sessionTop = titleLabel.frame.minY - 8
        sessionListView.frame = NSRect(x: 8, y: 4, width: width - 16, height: sessionTop - 4)
    }

    @objc func openSettings() {
        onSettingsRequested?()
    }

    @objc func toggleView() {
        isShowingSessions.toggle()
        applyPresentationPolicy()

        // One flag hides the whole game HUD, so a new HUD element added to
        // `gameHUD` is covered automatically.
        gameHUD.isHidden = isShowingSessions
        sessionListView.isHidden = !isShowingSessions

        updateTitleLabel()
        updateViewToggleButton()

        // Force layout update to ensure sessionListView has correct frame
        needsLayout = true
        layoutSubtreeIfNeeded()

        // Session mode wants a taller panel than the game HUD.
        notifyExpandedHeightIfChanged()

        // Start session monitoring when showing sessions
        if isShowingSessions && monitorsEnabled {
            SessionMonitor.shared.startMonitoring()
        }
    }

    // The session list only scanned once, when the view was toggled on, so it
    // went stale as soon as it was open. SessionMonitor throttles internally.
    func refreshSessionsIfVisible() {
        guard monitorsEnabled, isShowingSessions, isExpanded else { return }
        SessionMonitor.shared.refreshIfNeeded()
    }

    func updateRoleUI() {
        updateTitleLabel()
        compactHeroView.heroRole = selectedRole
        battleScene.heroRole = selectedRole
        battleScene.backdrop = BattleBackdrop.load()
        updateDefeatPresentation()
    }

    func updateTitleLabel() {
        // Combat keeps progressing behind the list; every caller derives the
        // title from the current mode rather than overwriting the session title.
        guard !isShowingSessions else {
            titleLabel.stringValue = L10n.text(.activeSessions)
            return
        }
        let stageTag = currentMonsterIsBoss
            ? L10n.string(.stageTagBoss, currentStage)
            : L10n.string(.stageTag, currentStage)
        titleLabel.stringValue = L10n.string(.hudLevelStage, L10n.string(.hudLevel, heroLevel), stageTag)
    }

    private func updateSettingsButton() {
        let label = L10n.text(.settingsTitle)
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: label)
        settingsButton.toolTip = label
        settingsButton.setAccessibilityLabel(label)
    }

    private func updateViewToggleButton() {
        let label = L10n.text(isShowingSessions ? .showBattle : .showSessions)
        let iconName = isShowingSessions ? "gamecontroller" : "rectangle.stack.person.crop"
        viewToggleButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: label)
        viewToggleButton.toolTip = label
        viewToggleButton.setAccessibilityLabel(label)
    }

    func reloadPreferences() {
        advancePassiveRecovery(now: Date())
        refreshSkillModifiers()
        selectedRole = HeroRole.load()
        reloadLocalizedText()
    }

    @objc func languageChanged() {
        reloadLocalizedText()
    }

    func reloadLocalizedText() {
        updateSettingsButton()
        updateViewToggleButton()
        sessionListView.reloadLocalization()
        battleScene.reloadLocalization()
        updateRoleUI()
        updateGameLabels()
        if !hasRealUsageData {
            applyNoDataLabels()
        }
    }
}
