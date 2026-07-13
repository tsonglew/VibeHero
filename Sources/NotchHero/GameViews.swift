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

final class PixelActorView: NSView {
    enum ActorKind {
        case hero
        case monster
    }

    var kind: ActorKind {
        didSet { needsDisplay = true }
    }

    var poseOffset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

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

    override func draw(_ dirtyRect: NSRect) {
        switch kind {
        case .hero:
            drawHero()
        case .monster:
            drawMonster()
        }
    }

    private func drawHero() {
        let unit = min(bounds.width, bounds.height) / 16
        let x = (bounds.width - unit * 16) / 2 + poseOffset
        let y = (bounds.height - unit * 16) / 2

        drawRect(x: x + unit * 6, y: y + unit * 2, w: unit * 4, h: unit * 4, color: NSColor(red: 0.98, green: 0.76, blue: 0.35, alpha: 1))
        drawRect(x: x + unit * 5, y: y + unit * 6, w: unit * 6, h: unit * 5, color: NSColor(red: 0.04, green: 0.82, blue: 0.72, alpha: 1))
        drawRect(x: x + unit * 4, y: y + unit * 8, w: unit * 2, h: unit * 3, color: NSColor(red: 0.0, green: 0.55, blue: 0.85, alpha: 1))
        drawRect(x: x + unit * 10, y: y + unit * 8, w: unit * 2, h: unit * 3, color: NSColor(red: 0.0, green: 0.55, blue: 0.85, alpha: 1))
        drawRect(x: x + unit * 6, y: y + unit * 11, w: unit * 2, h: unit * 3, color: NSColor(red: 0.19, green: 0.22, blue: 0.34, alpha: 1))
        drawRect(x: x + unit * 9, y: y + unit * 11, w: unit * 2, h: unit * 3, color: NSColor(red: 0.19, green: 0.22, blue: 0.34, alpha: 1))
        drawRect(x: x + unit * 11, y: y + unit * 5, w: unit * 4, h: unit, color: NSColor(red: 0.97, green: 0.94, blue: 0.78, alpha: 1))
        drawRect(x: x + unit * 14, y: y + unit * 3, w: unit, h: unit * 5, color: NSColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1))
    }

    private func drawMonster() {
        let unit = min(bounds.width, bounds.height) / 16
        let x = (bounds.width - unit * 16) / 2 + poseOffset
        let y = (bounds.height - unit * 16) / 2

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

    private func drawRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: NSColor) {
        color.setFill()
        NSBezierPath(rect: NSRect(x: round(x), y: round(y), width: ceil(w), height: ceil(h))).fill()
    }
}

final class BattleSceneView: NSView {
    private let heroView = PixelActorView(kind: .hero)
    private let monsterView = PixelActorView(kind: .monster)
    private let monsterBar = PixelBarView()
    private let slashLayer = CAShapeLayer()
    private let damageLabel = NSTextField(labelWithString: "")
    private let groundLayer = CALayer()

    var monsterHealth: CGFloat = 1 {
        didSet {
            monsterBar.value = monsterHealth
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

    override func layout() {
        super.layout()

        let actorSize = min(bounds.height - 14, 46)
        heroView.frame = NSRect(x: 16, y: bounds.height - actorSize - 5, width: actorSize, height: actorSize)
        monsterView.frame = NSRect(x: bounds.width - actorSize - 16, y: bounds.height - actorSize - 5, width: actorSize, height: actorSize)
        monsterBar.frame = NSRect(x: bounds.width - actorSize - 24, y: 4, width: actorSize + 16, height: 4)
        groundLayer.frame = NSRect(x: 12, y: bounds.height - 8, width: bounds.width - 24, height: 2)
        damageLabel.frame = NSRect(x: bounds.midX - 22, y: 4, width: 44, height: 16)
    }

    func playAttack(damage: Int) {
        damageLabel.stringValue = "-\(damage)"
        damageLabel.alphaValue = 1
        heroView.poseOffset = 5
        monsterView.poseOffset = -3
        let heroFrame = heroView.frame
        let damageFrame = damageLabel.frame
        var heroLungeFrame = heroFrame
        heroLungeFrame.origin.x += 5
        var raisedDamageFrame = damageFrame
        raisedDamageFrame.origin.y -= 10

        slashLayer.path = slashPath().cgPath
        slashLayer.opacity = 1

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

        let slash = CABasicAnimation(keyPath: "strokeEnd")
        slash.fromValue = 0
        slash.toValue = 1
        slash.duration = 0.18
        slashLayer.add(slash, forKey: "slash")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.slashLayer.opacity = 0
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

    private func setup() {
        layer?.backgroundColor = NSColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 1.0).cgColor
        layer?.cornerRadius = 10
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1

        groundLayer.backgroundColor = NSColor.white.withAlphaComponent(0.16).cgColor
        layer?.addSublayer(groundLayer)

        monsterBar.fillColor = NSColor(red: 1.0, green: 0.33, blue: 0.29, alpha: 1.0)
        monsterBar.trackColor = NSColor.white.withAlphaComponent(0.12)

        slashLayer.strokeColor = NSColor(red: 1.0, green: 0.86, blue: 0.28, alpha: 1.0).cgColor
        slashLayer.fillColor = nil
        slashLayer.lineWidth = 3
        slashLayer.lineCap = .round
        slashLayer.opacity = 0
        layer?.addSublayer(slashLayer)

        damageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        damageLabel.textColor = NSColor(red: 1.0, green: 0.86, blue: 0.28, alpha: 1.0)
        damageLabel.alignment = .center

        addSubview(heroView)
        addSubview(monsterView)
        addSubview(monsterBar)
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
}
