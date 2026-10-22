import AppKit

struct MonsterInstance {
    let id = UUID()
    let encounter: MonsterEncounter
    let maxHP: CGFloat
    var currentHP: CGFloat
    // Hero-world coordinate at which this monster reaches its fight position.
    var worldX: CGFloat

    init(encounter: MonsterEncounter, worldX: CGFloat) {
        self.encounter = encounter
        self.maxHP = CGFloat(encounter.maxHP)
        self.currentHP = self.maxHP
        self.worldX = worldX
    }

    var kind: MonsterKind { encounter.kind }
    var isBoss: Bool { encounter.isBoss }

    var healthFraction: CGFloat {
        currentHP / maxHP
    }
}

/// Layer-hosting container for the battle scene's combat effects. It draws
/// nothing itself and never takes part in hit testing.
final class EffectOverlayView: NSView {
    init() {
        super.init(frame: .zero)
        layer = CALayer()
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

struct HeroAttackRequest {
    let monsterID: UUID
    let damageText: String?
    let isCrit: Bool
}

final class BattleSceneView: NSView {
    /// Every CALayer effect is hosted here rather than on the scene's own layer.
    /// AppKit keeps subview backing layers at the end of the sublayer array, so
    /// anything added with `layer?.addSublayer` ends up *below* the opaque
    /// backdrop subview - which is why no slash, projectile or impact was ever
    /// visible. This overlay is the last subview, so effects land on top.
    let effectsHost = EffectOverlayView()
    var effectsLayer: CALayer? { effectsHost.layer }
    let heroView = PixelActorView(kind: .hero)
    let monsterView = PixelActorView(kind: .monster)
    let backdropView = BackdropView()
    // Monster queue: multiple monsters waiting to fight, fought in order
    var monsterQueue: [MonsterInstance] = []
    // Current monster index in the queue (-1 if none)
    var currentMonsterIndex: Int = -1
    // Hero's position in world coordinates (advances as the world scrolls).
    var heroWorldX: CGFloat = 0
    /// Reused shape layers for the laser and claw effects.
    let effects = EffectLayerPool()
    let flashLayer = CALayer()
    let monsterHitFlashLayer = CALayer()
    // The flash that lands on the hero is reused for every wolf-claw hit.
    let heroImpactLayer = CAShapeLayer()
    let floatingTextLabels = (0..<6).map { _ in NSTextField(labelWithString: "") }
    let monsterOverheadHPBar = PixelBarView()
    var showsOverheadHealth = true
    var floatingTextIndex = 0

    var displayLink: CADisplayLink?
    var backgroundSimulationTimer: Timer?
    var lastUpdateTime: CFTimeInterval = 0

    private(set) var rendersCombatEffects = false
    private(set) var reduceMotion = false
    private(set) var visualGeneration: UInt64 = 0
    var combatPaused = false {
        didSet {
            guard combatPaused != oldValue else { return }
            cancelVisualEffects()
            applyMotionPolicy()
        }
    }
    var animatesCombatEffects: Bool { rendersCombatEffects && !reduceMotion && !combatPaused }

    func setPresentation(visible: Bool, reduceMotion: Bool) {
        guard visible != rendersCombatEffects || reduceMotion != self.reduceMotion else { return }
        cancelVisualEffects()
        rendersCombatEffects = visible
        self.reduceMotion = reduceMotion
        applyMotionPolicy()
    }

    private func applyMotionPolicy() {
        heroView.animationsEnabled = animatesCombatEffects
        monsterView.animationsEnabled = animatesCombatEffects
        monsterOverheadHPBar.animationsEnabled = animatesCombatEffects
        backdropView.animationsEnabled = animatesCombatEffects
        updateWorldMotion()
        updateMonsterPosition()
        refreshSimulationClock()
    }

    /// Visual cancellation never touches health, world position, or combat budgets.
    /// A generation also prevents an old completion from consuming a newer queue.
    func cancelVisualEffects() {
        visualGeneration &+= 1
        approachWorkItem?.cancel()
        approachWorkItem = nil
        heroAttackQueue.removeAll()
        isAttackInProgress = false
        heroView.layer?.removeAllAnimations()
        monsterView.layer?.removeAllAnimations()
        for effect in effectsLayer?.sublayers ?? [] {
            effect.removeAllAnimations()
            effect.removeFromSuperlayer()
        }
        for label in floatingTextLabels {
            label.layer?.removeAllAnimations()
            label.alphaValue = 0
        }
    }

    func refreshSimulationClock() {
        if animatesCombatEffects {
            stopBackgroundSimulation()
            startGameLoop()
        } else {
            stopGameLoop()
            startBackgroundSimulation()
        }
    }

    // When true the monster is within attack range: the world stops scrolling,
    // hero stands to fight, HP bar is visible, and attacks can be triggered.
    // When false the world scrolls and hero walks toward the monster.
    private(set) var monsterEngaged = false
    private(set) var worldIsMoving = false
    var onWorldMotionChanged: ((Bool) -> Void)?
    var onMonsterEngaged: (() -> Void)?
    var isAttackInProgress = false
    var currentMonsterDefeated = false
    var heroAttackQueue: [HeroAttackRequest] = []
    static let maximumPendingVisualAttacks = 12
    var approachWorkItem: DispatchWorkItem?

    static let heroImpactDelay: TimeInterval = 0
    static let heroAttackDuration: TimeInterval = 0.40
    static let monsterImpactDelay: TimeInterval = 0

    // These world-space distances also define the visual fight positions.
    // Engagement must work before the hidden scene has ever been laid out.
    let fightGap: CGFloat = 22
    let attackRange: CGFloat = 30

    func updateWorldMotion() {
        let moving = !combatPaused && currentMonster != nil && !monsterEngaged && !heroDefeated
        if moving != worldIsMoving {
            worldIsMoving = moving
            onWorldMotionChanged?(moving)
        }
        backdropView.scrollingEnabled = animatesCombatEffects && moving
        heroView.setWalking(moving)
    }

    // The current target monster
    var currentMonster: MonsterInstance? {
        guard currentMonsterIndex >= 0, currentMonsterIndex < monsterQueue.count else { return nil }
        return monsterQueue[currentMonsterIndex]
    }

    // The monster's on-screen frame, honoring an in-flight approach animation.
    var monsterVisualFrame: CGRect {
        monsterView.layer?.presentation()?.frame ?? monsterView.frame
    }

    var monsterKind: MonsterKind {
        get { currentMonster?.kind ?? .promptWraith }
        set { monsterView.monsterKind = newValue }
    }

    var monsterIsBoss: Bool {
        get { currentMonster?.isBoss ?? false }
        set { monsterView.isBoss = newValue }
    }

    var backdrop: BattleBackdrop = .midnightForest {
        didSet {
            guard backdrop != oldValue else {
                return
            }
            backdropView.backdrop = backdrop
        }
    }

    // Monster health fraction (0...1) of the current target
    var monsterHealth: CGFloat {
        get { currentMonster?.healthFraction ?? 1 }
        set {
            guard currentMonsterIndex >= 0, currentMonsterIndex < monsterQueue.count else { return }
            let previousHealth = monsterHealth
            let clampedHealth = min(max(newValue, 0), 1)
            monsterQueue[currentMonsterIndex].currentHP = clampedHealth * monsterQueue[currentMonsterIndex].maxHP
            monsterOverheadHPBar.value = clampedHealth
            if clampedHealth < previousHealth, rendersCombatEffects {
                pulseMonster()
            }
        }
    }

    var heroRole: HeroRole = .other {
        didSet {
            heroView.heroRole = heroRole
        }
    }

    var heroDefeated: Bool = false {
        didSet {
            guard heroDefeated != oldValue else { return }
            heroView.isDefeated = heroDefeated
            if heroDefeated {
                heroAttackQueue.removeAll()
            }
            updateWorldMotion()
        }
    }

    var tokenActivity: Bool = false {
        didSet {
            heroView.setTokenActivity(tokenActivity && !heroDefeated)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setup()
        heroView.animationsEnabled = false
        monsterView.animationsEnabled = false
        monsterOverheadHPBar.animationsEnabled = false
        backdropView.animationsEnabled = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            cancelVisualEffects()
            stopGameLoop()
            stopBackgroundSimulation()
            backdropView.scrollingEnabled = false
            heroView.animationsEnabled = false
            monsterView.animationsEnabled = false
            backdropView.animationsEnabled = false
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        lastUpdateTime = CACurrentMediaTime()
        heroView.animationsEnabled = animatesCombatEffects
        monsterView.animationsEnabled = animatesCombatEffects
        backdropView.animationsEnabled = animatesCombatEffects
        refreshSimulationClock()
        updateWorldMotion()
    }

    var actorSize: CGFloat {
        max(0, min(bounds.height - 14, 46))
    }

    // Fight position is derived from bounds, not from heroView.frame, so it is
    // valid even before the scene has been laid out (e.g. a monster respawns
    // while the HUD is collapsed).
    var monsterFightX: CGFloat {
        max(16, bounds.width * 0.3) + actorSize + fightGap
    }

    override func layout() {
        super.layout()

        backdropView.frame = bounds
        // Same coordinate space as the scene, so effect paths built from actor
        // frames need no conversion.
        effectsHost.frame = bounds
        let actorSize = actorSize
        // The backdrop ground is 10pt from the scene bottom. Hero sprites have
        // one transparent pixel below their feet; align that pixel to the soil.
        let actorY = max(0, 10 - actorSize / 16)
        heroView.frame = NSRect(
            x: max(16, bounds.width * 0.3),
            y: actorY,
            width: actorSize,
            height: actorSize
        )

        monsterView.frame = NSRect(x: monsterView.frame.minX, y: actorY, width: actorSize, height: actorSize)
        // Update HP bar position based on current monster view position
        updateMonsterPosition()
    }

    func playMonsterDeath() {
        approachWorkItem?.cancel()
        heroAttackQueue.removeAll()
        currentMonsterDefeated = true
        monsterEngaged = false
        updateWorldMotion()
        let center = CGPoint(x: monsterVisualFrame.midX, y: monsterVisualFrame.midY)
        monsterView.layer?.removeAllAnimations()
        monsterView.alphaValue = 0
        guard animatesCombatEffects else {
            return
        }
        playFlash(color: monsterKind.hpColor.withAlphaComponent(0.26))

        for index in 0..<8 {
            let shard = CALayer()
            shard.backgroundColor = monsterKind.shardColors[index % monsterKind.shardColors.count].cgColor
            shard.shadowColor = monsterKind.hpColor.cgColor
            shard.shadowOpacity = 0.16
            shard.shadowRadius = 2
            shard.frame = NSRect(
                x: 0,
                y: 0,
                width: CGFloat(4 + index % 3),
                height: CGFloat(4 + (index + 1) % 3)
            )
            shard.position = center
            effectsLayer?.addSublayer(shard)

            let angle = CGFloat(index) / 8 * CGFloat.pi * 2
            let distance = CGFloat(18 + (index % 4) * 7)
            let end = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)

            let fly = CABasicAnimation(keyPath: "position")
            fly.fromValue = center
            fly.toValue = end
            fly.duration = 0.42
            fly.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
            rotate.fromValue = 0
            rotate.toValue = CGFloat.pi * CGFloat(1 + index % 3)
            rotate.duration = 0.42

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.38
            fade.beginTime = CACurrentMediaTime() + 0.10
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false

            shard.add(fly, forKey: "deathShardFly")
            shard.add(rotate, forKey: "deathShardRotate")
            shard.add(fade, forKey: "deathShardFade")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
                shard.removeFromSuperlayer()
            }
        }
    }

    // Generate a batch of monsters with fixed positions in hero-world space.
    // Positions are independent of the current HUD size, so expanding or moving
    // the notch cannot move a monster across the engagement boundary.
    func spawnMonsterBatch(_ encounters: [MonsterEncounter]) {
        approachWorkItem?.cancel()
        monsterQueue.removeAll()
        currentMonsterDefeated = false

        var nextFightWorldX = heroWorldX + CGFloat.random(in: 40...100)
        for (index, encounter) in encounters.enumerated() {
            if index > 0 {
                nextFightWorldX += CGFloat.random(in: 120...180)
            }
            monsterQueue.append(MonsterInstance(encounter: encounter, worldX: nextFightWorldX))
        }

        currentMonsterIndex = encounters.isEmpty ? -1 : 0
        setupCurrentMonster()
    }

    // Setup the current monster view for the monster at currentMonsterIndex
    func setupCurrentMonster() {
        cancelVisualEffects()
        guard let monster = currentMonster else {
            // All monsters defeated, batch complete
            monsterView.alphaValue = 0
            monsterEngaged = false
            updateWorldMotion()
            return
        }

        currentMonsterDefeated = false
        monsterView.layer?.removeAllAnimations()
        monsterView.alphaValue = 1
        monsterView.needsDisplay = true
        monsterView.monsterKind = monster.kind
        monsterView.isBoss = monster.isBoss
        monsterOverheadHPBar.fillColor = monster.kind.hpColor
        monsterEngaged = false

        // Position the monster from its remaining distance to the hero.
        updateMonsterPosition()
        updateWorldMotion()
    }

    // Update monster view position based on world scrolling
    func updateMonsterPosition() {
        guard let monster = currentMonster else { return }
        guard bounds.width > 40, bounds.height > 24 else { return }

        let fightFrame = NSRect(
            x: monsterFightX,
            y: monsterView.frame.minY,
            width: monsterView.frame.width,
            height: monsterView.frame.height
        )

        // `worldX` is the hero-world coordinate where the fight begins. The
        // remaining distance is projected from the current fight position.
        let remainingDistance = max(0, monster.worldX - heroWorldX)
        let screenX = monsterFightX + (reduceMotion ? 0 : remainingDistance)

        // Update monster view position (visual position on screen)
        if screenX <= monsterFightX {
            // Monster has reached fight position
            monsterView.frame = fightFrame
        } else {
            // Monster is still approaching from the right
            monsterView.frame = NSRect(
                x: screenX,
                y: fightFrame.minY,
                width: fightFrame.width,
                height: fightFrame.height
            )
        }

        // Show HP bar only when engaged (within attack range)
        monsterOverheadHPBar.isHidden = !showsOverheadHealth || !monsterEngaged || currentMonsterDefeated

        // Update HP bar position. The scene uses non-flipped coordinates, so
        // "overhead" means above the monster's frame: `maxY + gap`, clamped to
        // the scene top. (`minY - 7` would land the bar under the monster's
        // feet, on the ground.)
        let barFrame = NSRect(
            x: monsterView.frame.minX,
            y: min(monsterView.frame.maxY + 4, bounds.height - 4),
            width: monsterView.frame.width,
            height: 3
        )
        monsterOverheadHPBar.frame = barFrame
        monsterOverheadHPBar.value = monster.healthFraction
    }

    func updateEngagement() {
        guard !combatPaused, let monster = currentMonster, !monsterEngaged,
              !currentMonsterDefeated, !heroDefeated,
              monster.worldX - heroWorldX <= max(0, attackRange - fightGap) else { return }
        monsterEngaged = true
        updateWorldMotion()
        onMonsterEngaged?()
        // The callback can immediately spend banked damage and defeat it.
        if rendersCombatEffects, !currentMonsterDefeated {
            playMonsterArrivalEffects()
        }
    }

    // Play effects when monster arrives at fight position
    func playMonsterArrivalEffects() {
        guard animatesCombatEffects, let monster = currentMonster else { return }

        playFlash(color: monster.kind.hpColor.withAlphaComponent(monster.isBoss ? 0.34 : 0.18))
        if monster.isBoss {
            shake(layer: monsterView.layer, distance: 5, duration: 0.3)
        }

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.15, 1.2, 0.92, 1.0]
        scale.keyTimes = [0, 0.48, 0.78, 1]
        scale.duration = monster.isBoss ? 0.5 : 0.36
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        monsterView.layer?.add(scale, forKey: "monsterRespawnScale")

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 1.0, 0.65, 1.0]
        opacity.keyTimes = [0, 0.42, 0.70, 1]
        opacity.duration = monster.isBoss ? 0.5 : 0.36
        monsterView.layer?.add(opacity, forKey: "monsterRespawnOpacity")
    }

    // Move to next monster in queue after defeating current
    @discardableResult
    func advanceToNextMonster() -> MonsterEncounter? {
        currentMonsterIndex += 1

        if currentMonsterIndex >= monsterQueue.count {
            // All monsters in batch defeated
            monsterView.alphaValue = 0
            monsterEngaged = false
            updateWorldMotion()
            return nil
        } else {
            // Setup next monster
            setupCurrentMonster()
            return currentMonster?.encounter
        }
    }

    // MARK: - Game Loop

    func startGameLoop() {
        guard window != nil, animatesCombatEffects, displayLink == nil else { return }
        displayLink = displayLink(target: self, selector: #selector(gameLoopTick))
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }

    func stopGameLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func startBackgroundSimulation() {
        guard window != nil, backgroundSimulationTimer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceGameClock()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        backgroundSimulationTimer = timer
        lastUpdateTime = CACurrentMediaTime()
    }

    func stopBackgroundSimulation() {
        backgroundSimulationTimer?.invalidate()
        backgroundSimulationTimer = nil
    }

    @objc private func gameLoopTick() {
        advanceGameClock()
    }

    func advanceGameClock() {
        let now = CACurrentMediaTime()
        let dt = min(max(0, now - lastUpdateTime), 0.25)
        lastUpdateTime = now
        updateWorld(dt: dt)
    }

    // Called each frame/tick to update world scrolling and monster positions
    func updateWorld(dt: TimeInterval) {
        guard !combatPaused else { return }
        // Rendering can be paused while the compact HUD is visible, but world
        // progress and engagement remain part of the game simulation.
        let moving = !combatPaused && currentMonster != nil && !monsterEngaged && !heroDefeated
        if moving {
            let delta = BackdropView.groundScrollSpeed * CGFloat(dt)
            if !currentMonsterDefeated, let monster = currentMonster {
                let stopX = monster.worldX - max(0, attackRange - fightGap)
                heroWorldX = max(heroWorldX, min(heroWorldX + delta, stopX))
            } else {
                heroWorldX += delta
            }
        }
        updateMonsterPosition()
        updateEngagement()
        updateMonsterPosition()
    }


    func setup() {
        layer?.backgroundColor = NSColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 1.0).cgColor
        layer?.cornerRadius = 10
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1

        addSubview(backdropView)

        flashLayer.backgroundColor = NSColor.clear.cgColor
        flashLayer.opacity = 0
        effectsLayer?.addSublayer(flashLayer)

        floatingTextLabels.forEach { label in
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
            label.textColor = .white
            label.alignment = .center
            label.alphaValue = 0
            label.wantsLayer = true
            addSubview(label)
        }

        monsterOverheadHPBar.trackColor = NSColor.white.withAlphaComponent(0.14)
        monsterOverheadHPBar.fillColor = monsterKind.hpColor
        monsterOverheadHPBar.value = 1
        addSubview(monsterOverheadHPBar)

        addSubview(heroView)
        addSubview(monsterView)
        // Last, so the effect overlay covers the backdrop and both actors.
        addSubview(effectsHost)

        monsterHitFlashLayer.backgroundColor = NSColor.white.cgColor
        monsterHitFlashLayer.cornerRadius = 6
        monsterHitFlashLayer.opacity = 0
        effectsLayer?.addSublayer(monsterHitFlashLayer)

        // The hit the hero takes: a red ring plus a soft fill, so it reads as a
        // flash on the sprite rather than a dark blotch over it.
        heroImpactLayer.path = CGPath(ellipseIn: CGRect(x: -15, y: -15, width: 30, height: 30), transform: nil)
        heroImpactLayer.fillColor = NSColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 0.22).cgColor
        heroImpactLayer.strokeColor = NSColor(red: 1.0, green: 0.42, blue: 0.34, alpha: 0.95).cgColor
        heroImpactLayer.lineWidth = 2.5
        heroImpactLayer.opacity = 0
        effectsLayer?.addSublayer(heroImpactLayer)
    }

}
