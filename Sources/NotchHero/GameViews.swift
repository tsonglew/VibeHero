import AppKit

final class PixelBarView: NSView {
    var value: CGFloat = 0.5 {
        didSet {
            value = min(max(value, 0), 1)
            needsDisplay = true
        }
    }

    var fillColor = NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1.0) {
        didSet { needsDisplay = true }
    }

    var trackColor = NSColor.white.withAlphaComponent(0.12) {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        trackColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        let fillRect = NSRect(x: 0, y: 0, width: bounds.width * value, height: bounds.height)
        fillColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
    }
}

enum MonsterKind: CaseIterable {
    case promptWraith
    case cacheGolem
    case tokenSlime
    case nullSentinel

    var displayName: String {
        switch self {
        case .promptWraith: L10n.text(.monsterPromptWraith)
        case .cacheGolem: L10n.text(.monsterCacheGolem)
        case .tokenSlime: L10n.text(.monsterTokenSlime)
        case .nullSentinel: L10n.text(.monsterNullSentinel)
        }
    }

    var shortName: String {
        switch self {
        case .promptWraith: L10n.text(.monsterPromptWraithShort)
        case .cacheGolem: L10n.text(.monsterCacheGolemShort)
        case .tokenSlime: L10n.text(.monsterTokenSlimeShort)
        case .nullSentinel: L10n.text(.monsterNullSentinelShort)
        }
    }

    var hpColor: NSColor {
        switch self {
        case .promptWraith:
            NSColor(red: 1.0, green: 0.33, blue: 0.29, alpha: 1.0)
        case .cacheGolem:
            NSColor(red: 0.34, green: 0.82, blue: 0.78, alpha: 1.0)
        case .tokenSlime:
            NSColor(red: 0.58, green: 1.0, blue: 0.35, alpha: 1.0)
        case .nullSentinel:
            NSColor(red: 0.78, green: 0.52, blue: 1.0, alpha: 1.0)
        }
    }

    var maxHP: Int {
        switch self {
        case .promptWraith: 120
        case .cacheGolem: 170
        case .tokenSlime: 95
        case .nullSentinel: 145
        }
    }

    var xpReward: Int {
        switch self {
        case .promptWraith: 45
        case .cacheGolem: 65
        case .tokenSlime: 35
        case .nullSentinel: 55
        }
    }

    var shardColors: [NSColor] {
        switch self {
        case .promptWraith:
            [
                NSColor(red: 0.92, green: 0.23, blue: 0.26, alpha: 1),
                NSColor(red: 1.0, green: 0.69, blue: 0.19, alpha: 1),
                NSColor(red: 0.36, green: 0.08, blue: 0.14, alpha: 1)
            ]
        case .cacheGolem:
            [
                NSColor(red: 0.28, green: 0.34, blue: 0.40, alpha: 1),
                NSColor(red: 0.0, green: 0.88, blue: 0.78, alpha: 1),
                NSColor(red: 0.70, green: 0.78, blue: 0.82, alpha: 1)
            ]
        case .tokenSlime:
            [
                NSColor(red: 0.38, green: 0.90, blue: 0.32, alpha: 1),
                NSColor(red: 0.92, green: 1.0, blue: 0.35, alpha: 1),
                NSColor(red: 0.12, green: 0.42, blue: 0.22, alpha: 1)
            ]
        case .nullSentinel:
            [
                NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1),
                NSColor(red: 0.68, green: 0.44, blue: 1.0, alpha: 1),
                NSColor(red: 0.24, green: 0.30, blue: 0.42, alpha: 1)
            ]
        }
    }

    var next: MonsterKind {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else {
            return .promptWraith
        }
        return allCases[(index + 1) % allCases.count]
    }
}

final class PixelActorView: NSView {
    enum ActorKind {
        case hero
        case monster
    }

    var kind: ActorKind {
        didSet { needsDisplay = true }
    }

    var heroRole: HeroRole = .other {
        didSet { needsDisplay = true }
    }

    var monsterKind: MonsterKind = .promptWraith {
        didSet { needsDisplay = true }
    }

    var poseOffset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var isDefeated: Bool = false {
        didSet {
            setTokenActivity(false)
            needsDisplay = true
        }
    }

    private var isTokenActivityAnimating = false

    init(kind: ActorKind) {
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    func setTokenActivity(_ active: Bool) {
        guard isTokenActivityAnimating != active else {
            return
        }

        isTokenActivityAnimating = active
        if active {
            startTokenActivityAnimation()
        } else {
            layer?.removeAnimation(forKey: "tokenActivityBob")
            layer?.removeAnimation(forKey: "tokenActivityPulse")
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        switch kind {
        case .hero:
            drawHero()
        case .monster:
            drawMonster()
        }
    }

    private func drawHero() {
        if isDefeated {
            drawSoulHero()
            return
        }

        let unit = min(bounds.width, bounds.height) / 16
        let x = (bounds.width - unit * 16) / 2 + poseOffset
        let y = (bounds.height - unit * 16) / 2
        let palette = heroRole.palette

        drawRect(x: x + unit * 6, y: y + unit * 2, w: unit * 4, h: unit * 4, color: palette.skin)
        drawRect(x: x + unit * 5, y: y + unit * 6, w: unit * 6, h: unit * 5, color: palette.shirt)
        drawRect(x: x + unit * 4, y: y + unit * 8, w: unit * 2, h: unit * 3, color: palette.sleeve)
        drawRect(x: x + unit * 10, y: y + unit * 8, w: unit * 2, h: unit * 3, color: palette.sleeve)
        drawRect(x: x + unit * 6, y: y + unit * 11, w: unit * 2, h: unit * 3, color: palette.pants)
        drawRect(x: x + unit * 9, y: y + unit * 11, w: unit * 2, h: unit * 3, color: palette.pants)
        drawRect(x: x + unit * 6, y: y + unit * 1, w: unit * 4, h: unit, color: palette.hair)
        drawRect(x: x + unit * 5, y: y + unit * 3, w: unit, h: unit * 2, color: palette.hair)
        drawRect(x: x + unit * 7, y: y + unit * 4, w: unit, h: unit, color: .black)
        drawRect(x: x + unit * 9, y: y + unit * 4, w: unit, h: unit, color: .black)
        drawRoleAccessory(unit: unit, x: x, y: y)
    }

    private func drawSoulHero() {
        let unit = min(bounds.width, bounds.height) / 16
        let x = (bounds.width - unit * 16) / 2 + poseOffset
        let y = (bounds.height - unit * 16) / 2
        let body = NSColor(red: 0.78, green: 0.95, blue: 1.0, alpha: 0.72)
        let glow = NSColor(red: 0.42, green: 0.86, blue: 1.0, alpha: 0.42)
        let eye = NSColor(red: 0.05, green: 0.16, blue: 0.24, alpha: 0.88)

        glow.setFill()
        NSBezierPath(ovalIn: NSRect(x: x + unit * 4, y: y + unit * 1, width: unit * 8, height: unit * 12)).fill()
        drawRect(x: x + unit * 5, y: y + unit * 3, w: unit * 6, h: unit * 7, color: body)
        drawRect(x: x + unit * 4, y: y + unit * 6, w: unit * 8, h: unit * 5, color: body)
        drawRect(x: x + unit * 5, y: y + unit * 11, w: unit * 2, h: unit * 2, color: body)
        drawRect(x: x + unit * 8, y: y + unit * 11, w: unit * 2, h: unit * 3, color: body.withAlphaComponent(0.58))
        drawRect(x: x + unit * 11, y: y + unit * 11, w: unit, h: unit * 2, color: body.withAlphaComponent(0.48))
        drawRect(x: x + unit * 6, y: y + unit * 6, w: unit, h: unit, color: eye)
        drawRect(x: x + unit * 9, y: y + unit * 6, w: unit, h: unit, color: eye)
        drawRect(x: x + unit * 7, y: y + unit * 9, w: unit * 3, h: unit, color: eye.withAlphaComponent(0.64))
    }

    private func startTokenActivityAnimation() {
        let bob = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bob.values = [0, -2.2, 0, 1.6, 0]
        bob.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        bob.duration = 0.62
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(bob, forKey: "tokenActivityBob")

        let pulse = CAKeyframeAnimation(keyPath: "opacity")
        pulse.values = [1.0, 0.78, 1.0]
        pulse.keyTimes = [0, 0.5, 1]
        pulse.duration = 0.62
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(pulse, forKey: "tokenActivityPulse")
    }

    private func drawRoleAccessory(unit: CGFloat, x: CGFloat, y: CGFloat) {
        switch heroRole {
        case .pm:
            drawRect(x: x + unit * 7, y: y + unit * 6, w: unit * 2, h: unit * 5, color: NSColor(red: 0.98, green: 0.93, blue: 0.45, alpha: 1))
            drawRect(x: x + unit * 11, y: y + unit * 4, w: unit * 4, h: unit * 7, color: NSColor(red: 0.16, green: 0.20, blue: 0.28, alpha: 1))
            drawRect(x: x + unit * 12, y: y + unit * 5, w: unit * 2, h: unit, color: NSColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 1))
            drawRect(x: x + unit * 12, y: y + unit * 7, w: unit * 2, h: unit, color: NSColor(red: 0.28, green: 0.92, blue: 0.66, alpha: 1))
            drawRect(x: x + unit * 12, y: y + unit * 9, w: unit * 2, h: unit, color: NSColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1))
        case .designer:
            drawRect(x: x + unit * 11, y: y + unit * 4, w: unit * 4, h: unit * 6, color: NSColor(red: 0.80, green: 0.73, blue: 1.0, alpha: 1))
            drawRect(x: x + unit * 12, y: y + unit * 5, w: unit, h: unit, color: NSColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1))
            drawRect(x: x + unit * 14, y: y + unit * 5, w: unit, h: unit, color: NSColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1))
            drawRect(x: x + unit * 13, y: y + unit * 7, w: unit, h: unit, color: NSColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1))
            drawRect(x: x + unit * 12, y: y + unit * 8, w: unit * 3, h: unit, color: NSColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1))
            drawRect(x: x + unit * 3, y: y + unit * 4, w: unit, h: unit * 5, color: NSColor(red: 0.98, green: 0.96, blue: 0.72, alpha: 1))
        case .artist:
            drawRect(x: x + unit * 11, y: y + unit * 3, w: unit * 4, h: unit * 6, color: NSColor(red: 0.96, green: 0.96, blue: 0.86, alpha: 1))
            drawRect(x: x + unit * 12, y: y + unit * 4, w: unit, h: unit, color: NSColor(red: 1.0, green: 0.28, blue: 0.36, alpha: 1))
            drawRect(x: x + unit * 14, y: y + unit * 5, w: unit, h: unit, color: NSColor(red: 0.22, green: 0.66, blue: 1.0, alpha: 1))
            drawRect(x: x + unit * 13, y: y + unit * 7, w: unit, h: unit, color: NSColor(red: 0.98, green: 0.74, blue: 0.22, alpha: 1))
            drawRect(x: x + unit * 3, y: y + unit * 4, w: unit, h: unit * 6, color: NSColor(red: 0.34, green: 0.21, blue: 0.13, alpha: 1))
            drawRect(x: x + unit * 2, y: y + unit * 3, w: unit, h: unit * 2, color: NSColor(red: 0.23, green: 0.93, blue: 0.78, alpha: 1))
        case .engineer:
            drawRect(x: x + unit * 6, y: y + unit * 4, w: unit * 4, h: unit, color: NSColor(red: 0.10, green: 0.14, blue: 0.18, alpha: 1))
            drawRect(x: x + unit * 7, y: y + unit * 4, w: unit, h: unit, color: NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1))
            drawRect(x: x + unit * 9, y: y + unit * 4, w: unit, h: unit, color: NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1))
            drawRect(x: x + unit * 11, y: y + unit * 5, w: unit * 4, h: unit * 4, color: NSColor(red: 0.08, green: 0.12, blue: 0.17, alpha: 1))
            drawRect(x: x + unit * 12, y: y + unit * 6, w: unit * 2, h: unit * 2, color: NSColor(red: 0.0, green: 0.86, blue: 0.88, alpha: 1))
            drawRect(x: x + unit * 10, y: y + unit * 9, w: unit * 5, h: unit, color: NSColor(red: 0.34, green: 0.39, blue: 0.47, alpha: 1))
        case .qa:
            drawRect(x: x + unit * 11, y: y + unit * 4, w: unit * 3, h: unit * 3, color: NSColor(red: 0.84, green: 0.96, blue: 1.0, alpha: 1))
            drawRect(x: x + unit * 12, y: y + unit * 5, w: unit, h: unit, color: NSColor(red: 0.04, green: 0.08, blue: 0.12, alpha: 1))
            drawRect(x: x + unit * 14, y: y + unit * 7, w: unit, h: unit * 3, color: NSColor(red: 0.84, green: 0.96, blue: 1.0, alpha: 1))
            drawRect(x: x + unit * 3, y: y + unit * 4, w: unit * 2, h: unit * 5, color: NSColor(red: 0.13, green: 0.24, blue: 0.23, alpha: 1))
            drawRect(x: x + unit * 4, y: y + unit * 6, w: unit, h: unit, color: NSColor(red: 0.30, green: 1.0, blue: 0.57, alpha: 1))
            drawRect(x: x + unit * 4, y: y + unit * 7, w: unit, h: unit, color: NSColor(red: 0.30, green: 1.0, blue: 0.57, alpha: 1))
        case .other:
            drawRect(x: x + unit * 11, y: y + unit * 5, w: unit * 4, h: unit, color: NSColor(red: 0.97, green: 0.94, blue: 0.78, alpha: 1))
            drawRect(x: x + unit * 14, y: y + unit * 3, w: unit, h: unit * 5, color: NSColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1))
        }
    }

    private func drawMonster() {
        let unit = min(bounds.width, bounds.height) / 16
        let x = (bounds.width - unit * 16) / 2 + poseOffset
        let y = (bounds.height - unit * 16) / 2

        switch monsterKind {
        case .promptWraith:
            drawPromptWraith(unit: unit, x: x, y: y)
        case .cacheGolem:
            drawCacheGolem(unit: unit, x: x, y: y)
        case .tokenSlime:
            drawTokenSlime(unit: unit, x: x, y: y)
        case .nullSentinel:
            drawNullSentinel(unit: unit, x: x, y: y)
        }
    }

    private func drawPromptWraith(unit: CGFloat, x: CGFloat, y: CGFloat) {
        drawRect(x: x + unit * 4, y: y + unit * 4, w: unit * 8, h: unit * 7, color: NSColor(red: 0.92, green: 0.23, blue: 0.26, alpha: 1))
        drawRect(x: x + unit * 3, y: y + unit * 6, w: unit * 2, h: unit * 3, color: NSColor(red: 0.65, green: 0.12, blue: 0.2, alpha: 1))
        drawRect(x: x + unit * 11, y: y + unit * 6, w: unit * 2, h: unit * 3, color: NSColor(red: 0.65, green: 0.12, blue: 0.2, alpha: 1))
        drawRect(x: x + unit * 5, y: y + unit * 3, w: unit * 2, h: unit * 2, color: NSColor(red: 1.0, green: 0.69, blue: 0.19, alpha: 1))
        drawRect(x: x + unit * 9, y: y + unit * 3, w: unit * 2, h: unit * 2, color: NSColor(red: 1.0, green: 0.69, blue: 0.19, alpha: 1))
        drawRect(x: x + unit * 6, y: y + unit * 6, w: unit, h: unit, color: .black)
        drawRect(x: x + unit * 10, y: y + unit * 6, w: unit, h: unit, color: .black)
        drawRect(x: x + unit * 6, y: y + unit * 10, w: unit * 4, h: unit, color: NSColor.white.withAlphaComponent(0.75))
        drawRect(x: x + unit * 5, y: y + unit * 11, w: unit * 2, h: unit * 2, color: NSColor(red: 0.36, green: 0.08, blue: 0.14, alpha: 1))
        drawRect(x: x + unit * 10, y: y + unit * 11, w: unit * 2, h: unit * 2, color: NSColor(red: 0.36, green: 0.08, blue: 0.14, alpha: 1))
    }

    private func drawCacheGolem(unit: CGFloat, x: CGFloat, y: CGFloat) {
        let stone = NSColor(red: 0.30, green: 0.36, blue: 0.42, alpha: 1)
        let dark = NSColor(red: 0.14, green: 0.18, blue: 0.23, alpha: 1)
        let light = NSColor(red: 0.62, green: 0.72, blue: 0.78, alpha: 1)
        let core = NSColor(red: 0.0, green: 0.88, blue: 0.78, alpha: 1)

        drawRect(x: x + unit * 5, y: y + unit * 3, w: unit * 6, h: unit * 3, color: stone)
        drawRect(x: x + unit * 4, y: y + unit * 6, w: unit * 8, h: unit * 6, color: stone)
        drawRect(x: x + unit * 3, y: y + unit * 7, w: unit * 2, h: unit * 4, color: dark)
        drawRect(x: x + unit * 11, y: y + unit * 7, w: unit * 2, h: unit * 4, color: dark)
        drawRect(x: x + unit * 5, y: y + unit * 12, w: unit * 3, h: unit * 2, color: dark)
        drawRect(x: x + unit * 9, y: y + unit * 12, w: unit * 3, h: unit * 2, color: dark)
        drawRect(x: x + unit * 6, y: y + unit * 7, w: unit * 4, h: unit * 3, color: core)
        drawRect(x: x + unit * 6, y: y + unit * 4, w: unit, h: unit, color: light)
        drawRect(x: x + unit * 9, y: y + unit * 4, w: unit, h: unit, color: light)
        drawRect(x: x + unit * 7, y: y + unit * 8, w: unit * 2, h: unit, color: NSColor.white.withAlphaComponent(0.72))
    }

    private func drawTokenSlime(unit: CGFloat, x: CGFloat, y: CGFloat) {
        let body = NSColor(red: 0.38, green: 0.90, blue: 0.32, alpha: 1)
        let dark = NSColor(red: 0.12, green: 0.42, blue: 0.22, alpha: 1)
        let glow = NSColor(red: 0.92, green: 1.0, blue: 0.35, alpha: 1)

        drawRect(x: x + unit * 5, y: y + unit * 5, w: unit * 6, h: unit * 2, color: body)
        drawRect(x: x + unit * 4, y: y + unit * 7, w: unit * 8, h: unit * 5, color: body)
        drawRect(x: x + unit * 3, y: y + unit * 9, w: unit * 10, h: unit * 3, color: body)
        drawRect(x: x + unit * 5, y: y + unit * 12, w: unit * 7, h: unit * 2, color: dark)
        drawRect(x: x + unit * 6, y: y + unit * 8, w: unit, h: unit, color: .black)
        drawRect(x: x + unit * 10, y: y + unit * 8, w: unit, h: unit, color: .black)
        drawRect(x: x + unit * 7, y: y + unit * 10, w: unit * 3, h: unit, color: dark)
        drawRect(x: x + unit * 6, y: y + unit * 4, w: unit * 4, h: unit, color: glow)
        drawRect(x: x + unit * 7, y: y + unit * 3, w: unit * 2, h: unit, color: NSColor(red: 1.0, green: 0.82, blue: 0.26, alpha: 1))
        drawRect(x: x + unit * 12, y: y + unit * 6, w: unit, h: unit * 2, color: glow)
    }

    private func drawNullSentinel(unit: CGFloat, x: CGFloat, y: CGFloat) {
        let armor = NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1)
        let plate = NSColor(red: 0.24, green: 0.30, blue: 0.42, alpha: 1)
        let glow = NSColor(red: 0.68, green: 0.44, blue: 1.0, alpha: 1)

        drawRect(x: x + unit * 5, y: y + unit * 2, w: unit * 6, h: unit * 4, color: armor)
        drawRect(x: x + unit * 4, y: y + unit * 6, w: unit * 8, h: unit * 6, color: plate)
        drawRect(x: x + unit * 3, y: y + unit * 7, w: unit, h: unit * 5, color: armor)
        drawRect(x: x + unit * 12, y: y + unit * 7, w: unit, h: unit * 5, color: armor)
        drawRect(x: x + unit * 6, y: y + unit * 12, w: unit * 2, h: unit * 2, color: armor)
        drawRect(x: x + unit * 9, y: y + unit * 12, w: unit * 2, h: unit * 2, color: armor)
        drawRect(x: x + unit * 6, y: y + unit * 4, w: unit * 4, h: unit, color: glow)
        drawRect(x: x + unit * 7, y: y + unit * 8, w: unit * 2, h: unit * 2, color: glow.withAlphaComponent(0.78))
        drawRect(x: x + unit * 4, y: y + unit * 3, w: unit, h: unit * 3, color: glow)
        drawRect(x: x + unit * 11, y: y + unit * 3, w: unit, h: unit * 3, color: glow)
        drawRect(x: x + unit * 5, y: y + unit * 10, w: unit * 6, h: unit, color: armor)
    }

    private func drawRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: NSColor) {
        color.setFill()
        NSBezierPath(rect: NSRect(x: round(x), y: round(y), width: ceil(w), height: ceil(h))).fill()
    }
}

final class BattleSceneView: NSView {
    private let heroView = PixelActorView(kind: .hero)
    private let monsterView = PixelActorView(kind: .monster)
    private let slashLayer = CAShapeLayer()
    private let projectileLayer = CAShapeLayer()
    private let impactLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()
    private let novaLayer = CAShapeLayer()
    private let flashLayer = CALayer()
    private let pooledProjectileLayers = (0..<8).map { _ in CAShapeLayer() }
    private let pooledImpactLayers = (0..<4).map { _ in CAShapeLayer() }
    private let damageLabel = NSTextField(labelWithString: "")
    private let groundLayer = CALayer()
    private var tokenAttackTimer: Timer?
    private var lastRingEffectAt: CFTimeInterval = 0
    private var projectilePoolIndex = 0
    private var impactPoolIndex = 0
    private var effectGeneration = 0
    private var layerGenerations: [ObjectIdentifier: Int] = [:]
    var onSustainedHit: ((CGFloat) -> Void)?
    var rendersCombatEffects = false

    var monsterKind: MonsterKind = .promptWraith {
        didSet {
            monsterView.monsterKind = monsterKind
        }
    }

    var monsterHealth: CGFloat = 1 {
        didSet {
            let clampedHealth = min(max(monsterHealth, 0), 1)
            if monsterHealth != clampedHealth {
                monsterHealth = clampedHealth
                return
            }

            if oldValue > monsterHealth, rendersCombatEffects {
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
            heroView.isDefeated = heroDefeated
            if heroDefeated {
                stopSustainedTokenAttack()
            } else if tokenActivity {
                startSustainedTokenAttack()
            }
        }
    }

    var skillLoadout: SkillLoadout = .empty {
        didSet {
            if tokenActivity, oldValue != skillLoadout {
                stopSustainedTokenAttack()
                startSustainedTokenAttack()
            }
        }
    }

    var tokenActivity: Bool = false {
        didSet {
            heroView.setTokenActivity(tokenActivity && !heroDefeated)
            if tokenActivity && !heroDefeated {
                startSustainedTokenAttack()
            } else {
                stopSustainedTokenAttack()
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            stopSustainedTokenAttack()
        }
    }

    override func layout() {
        super.layout()

        let actorSize = min(bounds.height - 14, 46)
        heroView.frame = NSRect(x: 16, y: bounds.height - actorSize - 5, width: actorSize, height: actorSize)
        monsterView.frame = NSRect(x: bounds.width - actorSize - 16, y: bounds.height - actorSize - 5, width: actorSize, height: actorSize)
        groundLayer.frame = NSRect(x: 12, y: bounds.height - 8, width: bounds.width - 24, height: 2)
        damageLabel.frame = NSRect(x: bounds.midX - 22, y: 4, width: 44, height: 16)
    }

    func playMonsterDeath() {
        let center = CGPoint(x: monsterView.frame.midX, y: monsterView.frame.midY)
        monsterView.layer?.removeAllAnimations()
        monsterView.alphaValue = 0
        guard rendersCombatEffects else {
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
            layer?.addSublayer(shard)

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

    func playMonsterRespawn() {
        monsterView.layer?.removeAllAnimations()
        monsterView.alphaValue = 1
        monsterView.needsDisplay = true
        guard rendersCombatEffects else {
            return
        }
        playFlash(color: monsterKind.hpColor.withAlphaComponent(0.18))

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.15, 1.2, 0.92, 1.0]
        scale.keyTimes = [0, 0.48, 0.78, 1]
        scale.duration = 0.36
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        monsterView.layer?.add(scale, forKey: "monsterRespawnScale")

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 1.0, 0.65, 1.0]
        opacity.keyTimes = [0, 0.42, 0.70, 1]
        opacity.duration = 0.36
        monsterView.layer?.add(opacity, forKey: "monsterRespawnOpacity")
    }

    func playLootDrop(_ drop: LootDrop) {
        guard rendersCombatEffects else {
            return
        }

        let itemLayer = CAShapeLayer()
        let size: CGFloat = 16
        itemLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        itemLayer.path = lootPath(for: drop.kind, in: itemLayer.bounds)
        itemLayer.fillColor = drop.kind.color.cgColor
        itemLayer.strokeColor = NSColor.white.withAlphaComponent(0.82).cgColor
        itemLayer.lineWidth = 1.2
        itemLayer.lineJoin = .miter
        itemLayer.shadowOpacity = 0
        itemLayer.position = CGPoint(x: heroView.frame.midX, y: heroView.frame.midY)
        layer?.addSublayer(itemLayer)

        let start = CGPoint(x: monsterView.frame.midX, y: monsterView.frame.midY)
        let bounce = CGPoint(x: monsterView.frame.midX - 18, y: max(14, monsterView.frame.minY - 8))
        let collect = CGPoint(x: heroView.frame.midX + 8, y: heroView.frame.midY)

        let flight = CAKeyframeAnimation(keyPath: "position")
        flight.values = [start, CGPoint(x: bounce.x, y: bounce.y + 18), bounce, collect]
        flight.keyTimes = [0, 0.28, 0.58, 1]
        flight.duration = 0.72
        flight.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.55, 1.18, 1.0, 0.45]
        scale.keyTimes = [0, 0.25, 0.62, 1]
        scale.duration = 0.72

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 0.58
        fade.duration = 0.14
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        itemLayer.add(flight, forKey: "lootFlight")
        itemLayer.add(scale, forKey: "lootScale")
        itemLayer.add(fade, forKey: "lootFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            itemLayer.removeFromSuperlayer()
        }
    }

    func playHeroReviveHeal(restoredHP: Int) {
        guard rendersCombatEffects else {
            return
        }
        let healColor = NSColor(red: 0.24, green: 1.0, blue: 0.58, alpha: 1.0)
        let center = CGPoint(x: heroView.frame.midX, y: heroView.frame.midY)
        let damageFrame = damageLabel.frame
        var raisedDamageFrame = damageFrame
        raisedDamageFrame.origin.x = heroView.frame.midX - 22
        raisedDamageFrame.origin.y = max(4, heroView.frame.minY - 2)

        damageLabel.stringValue = L10n.string(.hpHeal, restoredHP)
        damageLabel.textColor = healColor
        damageLabel.alphaValue = 1
        damageLabel.frame = raisedDamageFrame
        playFlash(color: healColor.withAlphaComponent(0.16))

        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [0.88, 1.18, 1.0]
        pulse.keyTimes = [0, 0.46, 1]
        pulse.duration = 0.42
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        heroView.layer?.add(pulse, forKey: "heroRevivePulse")

        let rays = CAShapeLayer()
        let rayBounds = CGRect(x: 0, y: 0, width: 52, height: 44)
        let path = reviveRaysPath(center: CGPoint(x: rayBounds.midX, y: rayBounds.midY + 3)).cgPath
        rays.frame = rayBounds
        rays.position = center
        rays.fillColor = nil
        rays.strokeColor = healColor.withAlphaComponent(0.86).cgColor
        rays.lineWidth = 2
        rays.lineCap = .square
        rays.shadowOpacity = 0
        rays.path = path
        rays.opacity = 1
        layer?.addSublayer(rays)

        let rise = CABasicAnimation(keyPath: "transform.translation.y")
        rise.fromValue = 7
        rise.toValue = -7
        rise.duration = 0.36
        rise.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let rayFade = CABasicAnimation(keyPath: "opacity")
        rayFade.fromValue = 1
        rayFade.toValue = 0
        rayFade.duration = 0.42
        rayFade.fillMode = .forwards
        rayFade.isRemovedOnCompletion = false

        rays.add(rise, forKey: "heroReviveRise")
        rays.add(rayFade, forKey: "heroReviveFade")

        for index in 0..<5 {
            let shard = CALayer()
            shard.backgroundColor = healColor.withAlphaComponent(0.9).cgColor
            shard.shadowOpacity = 0
            shard.frame = NSRect(x: 0, y: 0, width: 4, height: 7)
            shard.position = CGPoint(
                x: center.x + CGFloat(index - 2) * 8,
                y: heroView.frame.maxY - 6
            )
            layer?.addSublayer(shard)

            let float = CABasicAnimation(keyPath: "position.y")
            float.fromValue = shard.position.y
            float.toValue = shard.position.y - CGFloat(12 + index * 3)
            float.duration = 0.44
            float.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.42
            fade.beginTime = CACurrentMediaTime() + Double(index) * 0.025
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false

            shard.add(float, forKey: "heroHealShardFloat")
            shard.add(fade, forKey: "heroHealShardFade")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                shard.removeFromSuperlayer()
            }
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.54
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            damageLabel.animator().alphaValue = 0
            damageLabel.animator().frame = NSRect(
                x: raisedDamageFrame.origin.x,
                y: raisedDamageFrame.origin.y - 14,
                width: raisedDamageFrame.width,
                height: raisedDamageFrame.height
            )
        } completionHandler: {
            Task { @MainActor in
                self.damageLabel.frame = damageFrame
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            rays.removeFromSuperlayer()
        }
    }

    func reloadLocalization() {
        needsDisplay = true
    }

    func playAttack(damage: Int) {
        guard !heroDefeated, rendersCombatEffects else {
            return
        }

        let attackColor = heroRole.attackColor
        let effectTier = min(max(skillLoadout.effectTier, 0), 14)
        damageLabel.stringValue = "-\(damage)"
        damageLabel.textColor = attackColor
        damageLabel.alphaValue = 1
        heroView.poseOffset = 5
        monsterView.poseOffset = -3
        let heroFrame = heroView.frame
        let damageFrame = damageLabel.frame
        var heroLungeFrame = heroFrame
        heroLungeFrame.origin.x += 5
        var raisedDamageFrame = damageFrame
        raisedDamageFrame.origin.y -= 10

        playProjectile(color: attackColor, tier: effectTier)
        playImpact(color: attackColor, tier: effectTier)
        playFlash(color: attackColor.withAlphaComponent(0.14 + CGFloat(min(effectTier, 6)) * 0.015))
        shakeMonster()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            heroView.animator().frame = heroLungeFrame
        } completionHandler: {
            Task { @MainActor in
                self.heroView.frame = heroFrame
                self.heroView.poseOffset = 0
                self.monsterView.poseOffset = 0
            }
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            damageLabel.animator().alphaValue = 0
            damageLabel.animator().frame = raisedDamageFrame
        } completionHandler: {
            Task { @MainActor in
                self.damageLabel.frame = damageFrame
            }
        }
    }

    func playSkillCast(skill: HeroSkill, rank: Int, damage: Int) {
        guard !heroDefeated, rendersCombatEffects else {
            return
        }

        let color = skillCastColor(for: skill)
        let tier = min(18, max(skillLoadout.effectTier + skill.treeTier + rank, skill.treeTier * 2))
        let projectileCount = min(6, max(3, skillLoadout.projectileCount + rank + skill.treeTier / 2))
        let arcCount = min(4, max(2, skillLoadout.arcCount + rank + skill.treeTier / 2))
        let damageFrame = damageLabel.frame
        var raisedDamageFrame = damageFrame
        raisedDamageFrame.origin.y -= 14

        damageLabel.stringValue = "-\(damage)"
        damageLabel.textColor = color
        damageLabel.alphaValue = 1
        heroView.poseOffset = 7
        monsterView.poseOffset = -5
        playFlash(color: color.withAlphaComponent(0.26 + CGFloat(min(rank, 3)) * 0.04))
        playSkillBeam(color: color, tier: tier)

        switch skill {
        case .pulseBlade:
            playSkillSlash(color: color, tier: tier, rank: rank)
            playImpact(color: color, tier: tier)
        case .tokenVolley:
            for index in 0..<projectileCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.035) {
                    self.launchShard(color: color, tier: tier, index: index, count: projectileCount, isSustained: false)
                }
            }
            playSkillShockwave(color: color, tier: tier, rings: 1)
        case .arcBurst:
            playArcBurst(color: color, tier: tier, count: arcCount)
            playSkillShockwave(color: color, tier: tier, rings: 2)
        case .wraithMark:
            playWraithMark(color: color, tier: tier)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.playSkillRift(color: color, tier: tier)
                self.playImpact(color: color, tier: tier)
            }
        case .novaStorm:
            playNovaStorm(color: color, tier: tier)
            playOrbitSparks(color: color, tier: tier)
            playSkillShockwave(color: color, tier: tier, rings: 3)
        case .overclockCore:
            playOrbitSparks(color: color, tier: tier)
            playNovaStorm(color: color, tier: tier)
            playArcBurst(color: color, tier: tier, count: min(4, arcCount + 1))
            let overclockProjectileCount = min(6, projectileCount + 2)
            for index in 0..<overclockProjectileCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.028) {
                    self.launchShard(color: color, tier: tier, index: index, count: overclockProjectileCount, isSustained: false)
                }
            }
        }

        shakeMonster()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.heroView.poseOffset = 0
            self.monsterView.poseOffset = 0
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.62
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            damageLabel.animator().alphaValue = 0
            damageLabel.animator().frame = raisedDamageFrame
        } completionHandler: {
            Task { @MainActor in
                self.damageLabel.frame = damageFrame
            }
        }
    }

    func playMonsterAttack(damage: Double) {
        guard rendersCombatEffects else {
            return
        }
        damageLabel.stringValue = L10n.string(.hpDamageDecimal, damage)
        damageLabel.textColor = NSColor(red: 1.0, green: 0.36, blue: 0.32, alpha: 1.0)
        damageLabel.alphaValue = 1
        heroView.poseOffset = -3
        monsterView.poseOffset = -5
        playFlash(color: NSColor(red: 1.0, green: 0.18, blue: 0.16, alpha: 0.20))
        playMonsterProjectile()
        shakeHero()
        let monsterFrame = monsterView.frame
        let damageFrame = damageLabel.frame
        var monsterLungeFrame = monsterFrame
        monsterLungeFrame.origin.x -= 6
        var raisedDamageFrame = damageFrame
        raisedDamageFrame.origin.y -= 10

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            monsterView.animator().frame = monsterLungeFrame
        } completionHandler: {
            Task { @MainActor in
                self.monsterView.frame = monsterFrame
                self.heroView.poseOffset = 0
                self.monsterView.poseOffset = 0
            }
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.55
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            damageLabel.animator().alphaValue = 0
            damageLabel.animator().frame = raisedDamageFrame
        } completionHandler: {
            Task { @MainActor in
                self.damageLabel.frame = damageFrame
            }
        }
    }

    private func playMonsterProjectile() {
        let projectile = CATextLayer()
        projectile.string = "💩"
        projectile.fontSize = 15
        projectile.alignmentMode = .center
        projectile.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        projectile.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        projectile.position = CGPoint(x: heroView.frame.midX + 8, y: heroView.frame.midY)
        projectile.opacity = 1
        layer?.addSublayer(projectile)

        let start = CGPoint(x: monsterView.frame.minX - 4, y: monsterView.frame.midY)
        let end = CGPoint(x: heroView.frame.midX + 8, y: heroView.frame.midY)

        let flight = CABasicAnimation(keyPath: "position")
        flight.fromValue = start
        flight.toValue = end
        flight.duration = 0.36
        flight.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = -CGFloat.pi * 1.5
        spin.duration = 0.36

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 0.30
        fade.duration = 0.08
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        projectile.add(flight, forKey: "monsterProjectileFlight")
        projectile.add(spin, forKey: "monsterProjectileSpin")
        projectile.add(fade, forKey: "monsterProjectileFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            projectile.removeFromSuperlayer()
        }
    }

    private func setup() {
        layer?.backgroundColor = NSColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 1.0).cgColor
        layer?.cornerRadius = 10
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1

        groundLayer.backgroundColor = NSColor.white.withAlphaComponent(0.16).cgColor
        layer?.addSublayer(groundLayer)

        flashLayer.backgroundColor = NSColor.clear.cgColor
        flashLayer.opacity = 0
        layer?.addSublayer(flashLayer)

        slashLayer.strokeColor = HeroRole.other.attackColor.cgColor
        slashLayer.fillColor = nil
        slashLayer.lineWidth = 4
        slashLayer.lineCap = .round
        slashLayer.opacity = 0
        slashLayer.shadowOpacity = 0.2
        slashLayer.shadowRadius = 3
        layer?.addSublayer(slashLayer)

        projectileLayer.opacity = 0
        projectileLayer.shadowOpacity = 0.16
        projectileLayer.shadowRadius = 2
        layer?.addSublayer(projectileLayer)

        impactLayer.fillColor = nil
        impactLayer.lineWidth = 3
        impactLayer.lineCap = .square
        impactLayer.opacity = 0
        impactLayer.shadowOpacity = 0.18
        impactLayer.shadowRadius = 2
        layer?.addSublayer(impactLayer)

        arcLayer.fillColor = nil
        arcLayer.lineCap = .round
        arcLayer.lineJoin = .round
        arcLayer.opacity = 0
        arcLayer.shadowOpacity = 0.18
        arcLayer.shadowRadius = 2
        layer?.addSublayer(arcLayer)

        novaLayer.fillColor = nil
        novaLayer.lineCap = .round
        novaLayer.opacity = 0
        novaLayer.shadowOpacity = 0
        layer?.addSublayer(novaLayer)

        pooledProjectileLayers.forEach { projectile in
            projectile.opacity = 0
            projectile.shadowOpacity = 0
            layer?.addSublayer(projectile)
        }
        pooledImpactLayers.forEach { impact in
            impact.fillColor = nil
            impact.lineCap = .round
            impact.opacity = 0
            impact.shadowOpacity = 0
            layer?.addSublayer(impact)
        }

        damageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        damageLabel.textColor = NSColor(red: 1.0, green: 0.86, blue: 0.28, alpha: 1.0)
        damageLabel.alignment = .center

        addSubview(heroView)
        addSubview(monsterView)
        addSubview(damageLabel)
    }

    private func slashPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.midX - 18, y: bounds.midY + 12))
        path.curve(
            to: NSPoint(x: bounds.midX + 26, y: bounds.midY - 16),
            controlPoint1: NSPoint(x: bounds.midX - 4, y: bounds.midY + 4),
            controlPoint2: NSPoint(x: bounds.midX + 14, y: bounds.midY - 8)
        )
        return path
    }

    private func playProjectile(color: NSColor, tier: Int) {
        projectileLayer.removeAllAnimations()
        projectileLayer.fillColor = color.cgColor
        projectileLayer.shadowColor = color.cgColor
        projectileLayer.opacity = 1
        let diameter = 8 + CGFloat(min(tier, 5)) * 1.2
        projectileLayer.frame = NSRect(
            x: 0,
            y: 0,
            width: diameter,
            height: diameter
        )
        projectileLayer.path = CGPath(
            ellipseIn: projectileLayer.bounds,
            transform: nil
        )

        let y = heroView.frame.midY - 2
        let start = CGPoint(x: heroView.frame.maxX + 10, y: y)
        let end = CGPoint(x: monsterView.frame.midX - 8, y: y)
        projectileLayer.position = end

        let fly = CABasicAnimation(keyPath: "position")
        fly.fromValue = start
        fly.toValue = end
        fly.duration = max(0.11, 0.18 - Double(min(tier, 5)) * 0.012)
        fly.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.08
        fade.beginTime = CACurrentMediaTime() + 0.14
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        projectileLayer.add(fly, forKey: "projectileFly")
        projectileLayer.add(fade, forKey: "projectileFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            self.projectileLayer.opacity = 0
            self.projectileLayer.removeAllAnimations()
        }
    }

    private func playVolley(color: NSColor, tier: Int, count: Int) {
        guard count > 1 else {
            return
        }

        for index in 1..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.045) {
                self.launchShard(color: color, tier: tier, index: index, count: count, isSustained: false)
            }
        }
    }

    private func playSkillSlash(color: NSColor, tier: Int, rank: Int) {
        slashLayer.removeAllAnimations()
        slashLayer.path = skillSlashPath().cgPath
        slashLayer.strokeColor = color.cgColor
        slashLayer.shadowColor = color.cgColor
        slashLayer.lineWidth = 6 + CGFloat(min(tier, 8)) * 0.55 + CGFloat(rank)
        slashLayer.opacity = 1

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.24
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.28
        fade.beginTime = CACurrentMediaTime() + 0.16
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        slashLayer.add(stroke, forKey: "skillSlashStroke")
        slashLayer.add(fade, forKey: "skillSlashFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            self.slashLayer.opacity = 0
            self.slashLayer.removeAllAnimations()
        }
    }

    private func playSkillBeam(color: NSColor, tier: Int) {
        let beam = CAShapeLayer()
        beam.fillColor = nil
        beam.strokeColor = color.withAlphaComponent(0.92).cgColor
        beam.lineWidth = 3 + CGFloat(min(tier, 8)) * 0.25
        beam.lineCap = .round
        beam.shadowColor = color.cgColor
        beam.shadowOpacity = 0.18
        beam.shadowRadius = 2
        beam.opacity = 1

        let path = NSBezierPath()
        path.move(to: NSPoint(x: heroView.frame.maxX + 4, y: heroView.frame.midY - 2))
        path.curve(
            to: NSPoint(x: monsterView.frame.midX - 6, y: monsterView.frame.midY - 5),
            controlPoint1: NSPoint(x: bounds.midX - 34, y: bounds.midY - 20),
            controlPoint2: NSPoint(x: bounds.midX + 24, y: bounds.midY + 14)
        )
        let cgPath = path.cgPath
        beam.path = cgPath
        beam.shadowPath = cgPath
        layer?.addSublayer(beam)

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.18
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.24
        fade.beginTime = CACurrentMediaTime() + 0.10
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        beam.add(stroke, forKey: "skillBeamStroke")
        beam.add(fade, forKey: "skillBeamFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            beam.removeFromSuperlayer()
        }
    }

    private func playSkillShockwave(color: NSColor, tier: Int, rings: Int) {
        guard shouldPlayRingEffect(minimumInterval: 0.22) else {
            return
        }

        let flare = CAShapeLayer()
        let center = CGPoint(x: monsterView.frame.midX - 5, y: monsterView.frame.midY - 5)
        let width = 56 + CGFloat(min(tier, 8)) * 2
        let height = 30 + CGFloat(min(tier, 6))
        let flareBounds = CGRect(x: 0, y: 0, width: width, height: height)
        let localCenter = CGPoint(x: flareBounds.midX, y: flareBounds.midY)
        let path = shockFlarePath(center: localCenter, width: width - 8, bands: min(max(2, rings + 1), 4)).cgPath
        flare.fillColor = nil
        flare.strokeColor = color.withAlphaComponent(0.88).cgColor
        flare.lineWidth = 2.0 + CGFloat(min(tier, 5)) * 0.15
        flare.lineCap = .square
        flare.lineJoin = .miter
        flare.shadowOpacity = 0
        flare.frame = flareBounds
        flare.position = center
        flare.path = path
        flare.opacity = 1
        layer?.addSublayer(flare)

        let slide = CABasicAnimation(keyPath: "transform.translation.x")
        slide.fromValue = -5
        slide.toValue = 5
        slide.duration = 0.2
        slide.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.16
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.22
        fade.beginTime = CACurrentMediaTime() + 0.08
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        flare.add(slide, forKey: "skillShockwaveSlide")
        flare.add(stroke, forKey: "skillShockwaveStroke")
        flare.add(fade, forKey: "skillShockwaveFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            flare.removeFromSuperlayer()
        }
    }

    private func playSkillRift(color: NSColor, tier: Int) {
        let rift = CAShapeLayer()
        rift.fillColor = color.withAlphaComponent(0.16).cgColor
        rift.strokeColor = color.cgColor
        rift.lineWidth = 2.5 + CGFloat(min(tier, 7)) * 0.25
        rift.lineJoin = .round
        rift.shadowColor = color.cgColor
        rift.shadowOpacity = 0.16
        rift.shadowRadius = 2
        let path = skillRiftPath(center: CGPoint(x: monsterView.frame.midX - 5, y: monsterView.frame.midY - 5), radius: 18 + CGFloat(min(tier, 8))).cgPath
        rift.path = path
        rift.shadowPath = path
        rift.opacity = 1
        layer?.addSublayer(rift)

        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.fromValue = -0.18
        rotate.toValue = 0.22
        rotate.duration = 0.22
        rotate.autoreverses = true

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.32
        fade.beginTime = CACurrentMediaTime() + 0.16
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        rift.add(rotate, forKey: "skillRiftRotate")
        rift.add(fade, forKey: "skillRiftFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            rift.removeFromSuperlayer()
        }
    }

    private func startSustainedTokenAttack() {
        guard tokenAttackTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: skillLoadout.sustainedInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fireSustainedProjectile()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tokenAttackTimer = timer
        DispatchQueue.main.async { [weak self, weak timer] in
            guard let self, let timer, self.tokenAttackTimer === timer, self.tokenActivity else {
                return
            }
            self.fireSustainedProjectile()
        }
    }

    private func stopSustainedTokenAttack() {
        tokenAttackTimer?.invalidate()
        tokenAttackTimer = nil
    }

    private func fireSustainedProjectile() {
        guard !heroDefeated, bounds.width > 40, bounds.height > 24 else {
            return
        }

        let color = heroRole.attackColor
        let tier = min(max(skillLoadout.effectTier, 0), 14)
        let count = skillLoadout.sustainedProjectileCount
        guard rendersCombatEffects else {
            for _ in 0..<count {
                onSustainedHit?(sustainedChipDamage(tier: tier))
            }
            return
        }

        heroView.poseOffset = 3
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.heroView.poseOffset = 0
        }

        for index in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.055) {
                self.launchShard(color: color, tier: tier, index: index, count: count, isSustained: true)
            }
        }
    }

    private func launchShard(color: NSColor, tier: Int, index: Int, count: Int, isSustained: Bool) {
        guard bounds.width > 40, bounds.height > 24 else {
            return
        }

        let projectile = nextProjectileLayer()
        projectile.removeAllAnimations()
        projectile.fillColor = color.cgColor
        projectile.strokeColor = color.withAlphaComponent(0.85).cgColor
        projectile.lineWidth = 1
        projectile.opacity = 0

        let diameter = 7 + CGFloat(min(tier, 5)) * 1.1
        let projectileSize = CGSize(width: diameter, height: diameter)
        projectile.frame = NSRect(origin: .zero, size: projectileSize)
        projectile.path = CGPath(ellipseIn: projectile.bounds, transform: nil)

        let laneOffset = CGFloat(index - max(0, count - 1) / 2) * 5
        let y = heroView.frame.midY - 3 + laneOffset
        let start = CGPoint(x: heroView.frame.maxX + 8, y: y)
        let end = CGPoint(x: monsterView.frame.midX - 9, y: y)
        projectile.position = end
        let generation = markLayerInUse(projectile)

        let fly = CABasicAnimation(keyPath: "position")
        fly.fromValue = start
        fly.toValue = end
        fly.duration = isSustained ? 0.34 : 0.24
        fly.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.06

        projectile.opacity = 1
        projectile.add(fly, forKey: "tokenProjectileFly")
        projectile.add(fadeIn, forKey: "tokenProjectileFadeIn")

        DispatchQueue.main.asyncAfter(deadline: .now() + (isSustained ? 0.30 : 0.22)) {
            self.playSustainedImpact(at: end, color: color, tier: tier)
            if isSustained {
                self.onSustainedHit?(self.sustainedChipDamage(tier: tier))
            }
            self.shakeMonster()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (isSustained ? 0.42 : 0.34)) {
            self.hideLayer(projectile, generation: generation)
        }
    }

    private func playSustainedImpact(at point: CGPoint, color: NSColor, tier: Int) {
        let impact = nextImpactLayer()
        impact.removeAllAnimations()
        impact.fillColor = nil
        impact.strokeColor = color.cgColor
        impact.lineWidth = 1.8 + CGFloat(min(tier, 5)) * 0.25
        impact.lineCap = .round
        let path = miniImpactPath(center: point, radius: 6 + CGFloat(min(tier, 5))).cgPath
        impact.path = path
        impact.opacity = 1
        let generation = markLayerInUse(impact)

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.12
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.18
        fade.beginTime = CACurrentMediaTime() + 0.08
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        impact.add(stroke, forKey: "sustainedImpactStroke")
        impact.add(fade, forKey: "sustainedImpactFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            self.hideLayer(impact, generation: generation)
        }
    }

    private func nextProjectileLayer() -> CAShapeLayer {
        let projectile = pooledProjectileLayers[projectilePoolIndex]
        projectilePoolIndex = (projectilePoolIndex + 1) % pooledProjectileLayers.count
        return projectile
    }

    private func nextImpactLayer() -> CAShapeLayer {
        let impact = pooledImpactLayers[impactPoolIndex]
        impactPoolIndex = (impactPoolIndex + 1) % pooledImpactLayers.count
        return impact
    }

    private func markLayerInUse(_ layer: CALayer) -> Int {
        effectGeneration &+= 1
        layerGenerations[ObjectIdentifier(layer)] = effectGeneration
        return effectGeneration
    }

    private func hideLayer(_ layer: CALayer, generation: Int) {
        guard layerGenerations[ObjectIdentifier(layer)] == generation else {
            return
        }
        layer.opacity = 0
        layer.removeAllAnimations()
    }

    private func sustainedChipDamage(tier: Int) -> CGFloat {
        0.0012 + CGFloat(min(max(tier, 0), 14)) * 0.00008
    }

    private func pulseMonster() {
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale.y")
        pulse.values = [1.0, 1.16, 1.0]
        pulse.keyTimes = [0, 0.35, 1]
        pulse.duration = 0.18
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        monsterView.layer?.add(pulse, forKey: "monsterHitPulse")

        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [1.0, 0.45, 1.0]
        flash.keyTimes = [0, 0.35, 1]
        flash.duration = 0.18
        monsterView.layer?.add(flash, forKey: "monsterHitFlash")
    }

    private func playImpact(color: NSColor, tier: Int) {
        impactLayer.removeAllAnimations()
        impactLayer.strokeColor = color.cgColor
        impactLayer.shadowColor = color.cgColor
        impactLayer.lineWidth = 3 + CGFloat(min(tier, 4)) * 0.45
        impactLayer.opacity = 1
        impactLayer.path = impactPath(center: CGPoint(x: monsterView.frame.midX - 4, y: monsterView.frame.midY - 3)).cgPath

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.16
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.75
        scale.toValue = 1.25 + CGFloat(min(tier, 5)) * 0.08
        scale.duration = 0.18
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.2
        fade.beginTime = CACurrentMediaTime() + 0.12
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        impactLayer.add(stroke, forKey: "impactStroke")
        impactLayer.add(scale, forKey: "impactScale")
        impactLayer.add(fade, forKey: "impactFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            self.impactLayer.opacity = 0
            self.impactLayer.removeAllAnimations()
        }
    }

    private func playFlash(color: NSColor) {
        flashLayer.removeAllAnimations()
        flashLayer.frame = bounds
        flashLayer.backgroundColor = color.cgColor
        flashLayer.opacity = 0

        let flash = CABasicAnimation(keyPath: "opacity")
        flash.fromValue = 0.45
        flash.toValue = 0
        flash.duration = 0.24
        flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
        flashLayer.add(flash, forKey: "flash")
    }

    private func playArcBurst(color: NSColor, tier: Int, count: Int) {
        arcLayer.removeAllAnimations()
        arcLayer.strokeColor = color.withAlphaComponent(0.92).cgColor
        arcLayer.shadowColor = color.cgColor
        arcLayer.lineWidth = 2.2 + CGFloat(min(tier, 5)) * 0.35
        arcLayer.opacity = 1
        arcLayer.path = arcBurstPath(center: CGPoint(x: monsterView.frame.midX - 6, y: monsterView.frame.midY - 4), count: count).cgPath

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.22
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.26
        fade.beginTime = CACurrentMediaTime() + 0.14
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        arcLayer.add(stroke, forKey: "arcStroke")
        arcLayer.add(fade, forKey: "arcFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            self.arcLayer.opacity = 0
            self.arcLayer.removeAllAnimations()
        }
    }

    private func playNovaStorm(color: NSColor, tier: Int) {
        guard shouldPlayRingEffect(minimumInterval: 0.14) else {
            playImpact(color: color, tier: tier)
            return
        }

        novaLayer.removeAllAnimations()
        novaLayer.strokeColor = color.cgColor
        novaLayer.shadowColor = color.cgColor
        novaLayer.shadowOpacity = 0
        novaLayer.lineWidth = 2.5 + CGFloat(min(tier, 6)) * 0.3
        novaLayer.opacity = 1
        let center = CGPoint(x: monsterView.frame.midX - 5, y: monsterView.frame.midY - 4)
        let radius = 16 + CGFloat(min(tier, 7)) * 2
        let padding: CGFloat = 8
        let diameter = (radius + padding) * 2
        novaLayer.frame = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        novaLayer.position = center
        let localCenter = CGPoint(x: diameter / 2, y: diameter / 2)
        let path = novaPath(center: localCenter, radius: radius).cgPath
        novaLayer.path = path

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.24
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.28
        fade.beginTime = CACurrentMediaTime() + 0.16
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        novaLayer.add(stroke, forKey: "novaStroke")
        novaLayer.add(fade, forKey: "novaFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.novaLayer.opacity = 0
            self.novaLayer.removeAllAnimations()
        }
    }

    private func playWraithMark(color: NSColor, tier: Int) {
        let mark = CAShapeLayer()
        let center = CGPoint(x: monsterView.frame.midX - 5, y: monsterView.frame.midY - 5)
        let radius = 11 + CGFloat(skillLoadout.wraithMark) * 2
        let padding: CGFloat = 4
        let diameter = (radius + padding) * 2
        mark.fillColor = color.withAlphaComponent(0.18).cgColor
        mark.strokeColor = color.withAlphaComponent(0.95).cgColor
        mark.lineWidth = 1.6 + CGFloat(min(tier, 5)) * 0.18
        mark.lineCap = .round
        mark.shadowColor = color.cgColor
        mark.shadowOpacity = 0.22
        mark.shadowRadius = 3
        mark.frame = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        mark.position = center
        let localCenter = CGPoint(x: diameter / 2, y: diameter / 2)
        let path = markPath(center: localCenter, radius: radius).cgPath
        mark.path = path
        mark.shadowPath = path
        mark.opacity = 1
        layer?.addSublayer(mark)

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.18
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.32
        fade.beginTime = CACurrentMediaTime() + 0.12
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        mark.add(stroke, forKey: "markStroke")
        mark.add(fade, forKey: "markFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            mark.removeFromSuperlayer()
        }
    }

    private func playOrbitSparks(color: NSColor, tier: Int) {
        let center = CGPoint(x: monsterView.frame.midX - 5, y: monsterView.frame.midY - 5)
        let sparkCount = min(5, 3 + skillLoadout.overclockCore)

        for index in 0..<sparkCount {
            let spark = CALayer()
            spark.backgroundColor = color.cgColor
            spark.shadowOpacity = 0
            spark.frame = NSRect(x: 0, y: 0, width: 7, height: 2)
            spark.position = center
            spark.opacity = 1
            layer?.addSublayer(spark)

            let angle = CGFloat(index) / CGFloat(max(1, sparkCount)) * CGFloat.pi * 2
            let radius = 18 + CGFloat(min(tier, 8)) * 1.4
            let end = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)

            let fly = CABasicAnimation(keyPath: "position")
            fly.fromValue = center
            fly.toValue = end
            fly.duration = 0.26
            fly.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
            rotate.fromValue = angle
            rotate.toValue = angle + 0.7
            rotate.duration = 0.26
            rotate.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.28
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false

            spark.add(fly, forKey: "orbitSparkFly")
            spark.add(rotate, forKey: "orbitSparkRotate")
            spark.add(fade, forKey: "orbitSparkFade")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                spark.removeFromSuperlayer()
            }
        }
    }

    private func shakeMonster() {
        shake(layer: monsterView.layer, distance: 4, duration: 0.22)
    }

    private func shakeHero() {
        shake(layer: heroView.layer, distance: -4, duration: 0.24)
    }

    private func shake(layer: CALayer?, distance: CGFloat, duration: CFTimeInterval) {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, distance, -distance * 0.65, distance * 0.35, 0]
        shake.duration = duration
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.add(shake, forKey: "shake")
    }

    private func shouldPlayRingEffect(minimumInterval: CFTimeInterval) -> Bool {
        let now = CACurrentMediaTime()
        guard now - lastRingEffectAt >= minimumInterval else {
            return false
        }

        lastRingEffectAt = now
        return true
    }

    private func impactPath(center: CGPoint) -> NSBezierPath {
        let path = NSBezierPath()
        let rays: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-12, 0, -5, 0),
            (5, 0, 13, 0),
            (0, -11, 0, -4),
            (0, 5, 0, 12),
            (-8, -8, -3, -3),
            (4, 4, 10, 10)
        ]

        for ray in rays {
            path.move(to: NSPoint(x: center.x + ray.0, y: center.y + ray.1))
            path.line(to: NSPoint(x: center.x + ray.2, y: center.y + ray.3))
        }

        return path
    }

    private func lootPath(for kind: LootKind, in rect: CGRect) -> CGPath {
        switch kind {
        case .healthPotion:
            let path = CGMutablePath()
            path.addRect(CGRect(x: 6, y: 1, width: 4, height: 3))
            path.addRect(CGRect(x: 4, y: 4, width: 8, height: 10))
            path.addRect(CGRect(x: 6, y: 7, width: 4, height: 1.5))
            path.addRect(CGRect(x: 7.25, y: 5.75, width: 1.5, height: 4))
            return path
        case .powerBoost:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.midX, y: 1))
            path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 1))
            path.addLine(to: CGPoint(x: 1, y: rect.midY))
            path.closeSubpath()
            return path
        case .gold:
            return CGPath(ellipseIn: rect.insetBy(dx: 2, dy: 2), transform: nil)
        }
    }

    private func sustainedProjectilePath(in rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.midY))
        path.line(to: NSPoint(x: rect.midX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        path.line(to: NSPoint(x: rect.midX, y: rect.maxY))
        path.close()
        return path
    }

    private func miniImpactPath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - radius, y: center.y))
        path.line(to: NSPoint(x: center.x - radius * 0.25, y: center.y))
        path.move(to: NSPoint(x: center.x + radius * 0.25, y: center.y))
        path.line(to: NSPoint(x: center.x + radius, y: center.y))
        path.move(to: NSPoint(x: center.x, y: center.y - radius))
        path.line(to: NSPoint(x: center.x, y: center.y - radius * 0.25))
        path.move(to: NSPoint(x: center.x, y: center.y + radius * 0.25))
        path.line(to: NSPoint(x: center.x, y: center.y + radius))
        return path
    }

    private func arcBurstPath(center: CGPoint, count: Int) -> NSBezierPath {
        let path = NSBezierPath()
        let arcCount = max(1, count)
        for index in 0..<arcCount {
            let offset = CGFloat(index) * 6
            let flip: CGFloat = index % 2 == 0 ? 1 : -1
            path.move(to: NSPoint(x: center.x - 22 + offset * 0.35, y: center.y - 8 * flip))
            path.curve(
                to: NSPoint(x: center.x + 20 - offset * 0.25, y: center.y - 12 * flip),
                controlPoint1: NSPoint(x: center.x - 12, y: center.y - (24 - offset) * flip),
                controlPoint2: NSPoint(x: center.x + 8, y: center.y + (6 + offset) * flip)
            )
        }
        return path
    }

    private func reviveRaysPath(center: CGPoint) -> NSBezierPath {
        let path = NSBezierPath()
        let rays: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-18, 10, -18, -10),
            (-8, 15, -8, -12),
            (0, 19, 0, -15),
            (9, 14, 9, -11),
            (19, 9, 19, -8)
        ]

        for ray in rays {
            path.move(to: NSPoint(x: center.x + ray.0, y: center.y + ray.1))
            path.line(to: NSPoint(x: center.x + ray.2, y: center.y + ray.3))
        }

        path.move(to: NSPoint(x: center.x - 12, y: center.y))
        path.line(to: NSPoint(x: center.x - 3, y: center.y))
        path.move(to: NSPoint(x: center.x + 3, y: center.y))
        path.line(to: NSPoint(x: center.x + 12, y: center.y))
        path.move(to: NSPoint(x: center.x, y: center.y - 9))
        path.line(to: NSPoint(x: center.x, y: center.y + 9))
        return path
    }

    private func shockFlarePath(center: CGPoint, width: CGFloat, bands: Int) -> NSBezierPath {
        let path = NSBezierPath()
        let bandCount = max(2, bands)
        let left = center.x - width / 2
        let right = center.x + width / 2

        for index in 0..<bandCount {
            let spread = CGFloat(index) * 4
            let y = center.y + CGFloat(index - (bandCount - 1) / 2) * 7
            path.move(to: NSPoint(x: left + spread, y: y))
            path.line(to: NSPoint(x: center.x - 6, y: y - 3))
            path.line(to: NSPoint(x: center.x + 3, y: y + 4))
            path.line(to: NSPoint(x: right - spread, y: y))
        }

        path.move(to: NSPoint(x: center.x - 12, y: center.y - 13))
        path.line(to: NSPoint(x: center.x + 10, y: center.y + 13))
        path.move(to: NSPoint(x: center.x - 10, y: center.y + 12))
        path.line(to: NSPoint(x: center.x + 14, y: center.y - 12))
        return path
    }

    private func markPath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x, y: center.y - radius))
        path.line(to: NSPoint(x: center.x + radius * 0.82, y: center.y))
        path.line(to: NSPoint(x: center.x, y: center.y + radius))
        path.line(to: NSPoint(x: center.x - radius * 0.82, y: center.y))
        path.close()
        path.move(to: NSPoint(x: center.x - radius * 0.6, y: center.y))
        path.line(to: NSPoint(x: center.x + radius * 0.6, y: center.y))
        path.move(to: NSPoint(x: center.x, y: center.y - radius * 0.6))
        path.line(to: NSPoint(x: center.x, y: center.y + radius * 0.6))
        return path
    }

    private func novaPath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - radius - 4, y: center.y))
        path.line(to: NSPoint(x: center.x + radius + 4, y: center.y))
        path.move(to: NSPoint(x: center.x, y: center.y - radius - 4))
        path.line(to: NSPoint(x: center.x, y: center.y + radius + 4))
        path.move(to: NSPoint(x: center.x - radius * 0.72, y: center.y - radius * 0.72))
        path.line(to: NSPoint(x: center.x + radius * 0.72, y: center.y + radius * 0.72))
        path.move(to: NSPoint(x: center.x - radius * 0.72, y: center.y + radius * 0.72))
        path.line(to: NSPoint(x: center.x + radius * 0.72, y: center.y - radius * 0.72))
        path.move(to: NSPoint(x: center.x - radius * 0.32, y: center.y - radius))
        path.line(to: NSPoint(x: center.x + radius * 0.32, y: center.y + radius))
        path.move(to: NSPoint(x: center.x + radius * 0.32, y: center.y - radius))
        path.line(to: NSPoint(x: center.x - radius * 0.32, y: center.y + radius))
        return path
    }

    private func skillSlashPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.midX - 34, y: bounds.midY + 20))
        path.curve(
            to: NSPoint(x: bounds.midX + 40, y: bounds.midY - 22),
            controlPoint1: NSPoint(x: bounds.midX - 18, y: bounds.midY - 5),
            controlPoint2: NSPoint(x: bounds.midX + 24, y: bounds.midY + 8)
        )
        path.move(to: NSPoint(x: bounds.midX - 20, y: bounds.midY - 18))
        path.curve(
            to: NSPoint(x: bounds.midX + 34, y: bounds.midY + 16),
            controlPoint1: NSPoint(x: bounds.midX - 4, y: bounds.midY - 2),
            controlPoint2: NSPoint(x: bounds.midX + 16, y: bounds.midY + 2)
        )
        return path
    }

    private func skillRiftPath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x, y: center.y - radius))
        path.line(to: NSPoint(x: center.x + radius * 0.42, y: center.y - radius * 0.24))
        path.line(to: NSPoint(x: center.x + radius, y: center.y))
        path.line(to: NSPoint(x: center.x + radius * 0.36, y: center.y + radius * 0.30))
        path.line(to: NSPoint(x: center.x, y: center.y + radius))
        path.line(to: NSPoint(x: center.x - radius * 0.42, y: center.y + radius * 0.24))
        path.line(to: NSPoint(x: center.x - radius, y: center.y))
        path.line(to: NSPoint(x: center.x - radius * 0.36, y: center.y - radius * 0.30))
        path.close()
        return path
    }

    private func skillCastColor(for skill: HeroSkill) -> NSColor {
        switch skill {
        case .pulseBlade:
            heroRole.attackColor
        case .tokenVolley:
            NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1)
        case .arcBurst:
            NSColor(red: 0.34, green: 0.68, blue: 1.0, alpha: 1)
        case .wraithMark:
            NSColor(red: 0.92, green: 0.36, blue: 1.0, alpha: 1)
        case .novaStorm:
            NSColor(red: 1.0, green: 0.74, blue: 0.20, alpha: 1)
        case .overclockCore:
            NSColor(red: 1.0, green: 0.38, blue: 0.22, alpha: 1)
        }
    }
}

private struct HeroPalette {
    let skin: NSColor
    let hair: NSColor
    let shirt: NSColor
    let sleeve: NSColor
    let pants: NSColor
}

private extension HeroRole {
    var attackColor: NSColor {
        switch self {
        case .pm:
            NSColor(red: 0.32, green: 0.68, blue: 1.0, alpha: 1)
        case .designer:
            NSColor(red: 0.78, green: 0.52, blue: 1.0, alpha: 1)
        case .artist:
            NSColor(red: 1.0, green: 0.42, blue: 0.52, alpha: 1)
        case .engineer:
            NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1)
        case .qa:
            NSColor(red: 0.42, green: 1.0, blue: 0.58, alpha: 1)
        case .other:
            NSColor(red: 1.0, green: 0.86, blue: 0.28, alpha: 1)
        }
    }

    var palette: HeroPalette {
        switch self {
        case .pm:
            HeroPalette(
                skin: NSColor(red: 0.98, green: 0.75, blue: 0.48, alpha: 1),
                hair: NSColor(red: 0.18, green: 0.12, blue: 0.10, alpha: 1),
                shirt: NSColor(red: 0.14, green: 0.42, blue: 0.95, alpha: 1),
                sleeve: NSColor(red: 0.08, green: 0.28, blue: 0.78, alpha: 1),
                pants: NSColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1)
            )
        case .designer:
            HeroPalette(
                skin: NSColor(red: 0.96, green: 0.74, blue: 0.48, alpha: 1),
                hair: NSColor(red: 0.58, green: 0.38, blue: 0.86, alpha: 1),
                shirt: NSColor(red: 0.62, green: 0.37, blue: 1.0, alpha: 1),
                sleeve: NSColor(red: 0.82, green: 0.62, blue: 1.0, alpha: 1),
                pants: NSColor(red: 0.18, green: 0.15, blue: 0.34, alpha: 1)
            )
        case .artist:
            HeroPalette(
                skin: NSColor(red: 0.98, green: 0.76, blue: 0.52, alpha: 1),
                hair: NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1),
                shirt: NSColor(red: 1.0, green: 0.34, blue: 0.46, alpha: 1),
                sleeve: NSColor(red: 0.98, green: 0.73, blue: 0.23, alpha: 1),
                pants: NSColor(red: 0.10, green: 0.28, blue: 0.48, alpha: 1)
            )
        case .engineer:
            HeroPalette(
                skin: NSColor(red: 0.95, green: 0.74, blue: 0.48, alpha: 1),
                hair: NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1),
                shirt: NSColor(red: 0.0, green: 0.72, blue: 0.78, alpha: 1),
                sleeve: NSColor(red: 0.0, green: 0.48, blue: 0.56, alpha: 1),
                pants: NSColor(red: 0.14, green: 0.18, blue: 0.25, alpha: 1)
            )
        case .qa:
            HeroPalette(
                skin: NSColor(red: 0.98, green: 0.77, blue: 0.48, alpha: 1),
                hair: NSColor(red: 0.54, green: 0.35, blue: 0.12, alpha: 1),
                shirt: NSColor(red: 0.22, green: 0.78, blue: 0.42, alpha: 1),
                sleeve: NSColor(red: 0.10, green: 0.52, blue: 0.32, alpha: 1),
                pants: NSColor(red: 0.12, green: 0.24, blue: 0.22, alpha: 1)
            )
        case .other:
            HeroPalette(
                skin: NSColor(red: 0.98, green: 0.76, blue: 0.35, alpha: 1),
                hair: NSColor(red: 0.30, green: 0.17, blue: 0.08, alpha: 1),
                shirt: NSColor(red: 0.04, green: 0.82, blue: 0.72, alpha: 1),
                sleeve: NSColor(red: 0.0, green: 0.55, blue: 0.85, alpha: 1),
                pants: NSColor(red: 0.19, green: 0.22, blue: 0.34, alpha: 1)
            )
        }
    }
}
