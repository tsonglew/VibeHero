import AppKit

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

    var isBoss: Bool = false {
        didSet { needsDisplay = true }
    }

    var isDefeated: Bool = false {
        didSet {
            if isDefeated { setTokenActivity(false) }
            needsDisplay = true
        }
    }

    var animationsEnabled = true {
        didSet {
            guard animationsEnabled != oldValue else { return }
            layer?.removeAllAnimations()
            updateActivityAnimation()
        }
    }

    private var isTokenActivityAnimating = false
    private var isWalking = false

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

    // Perpetual walk-cycle bob. Token-activity bounce takes precedence while
    // active; the walk resumes when it ends.
    func setWalking(_ walking: Bool) {
        guard isWalking != walking else {
            return
        }

        isWalking = walking
        updateActivityAnimation()
    }

    func setTokenActivity(_ active: Bool) {
        guard isTokenActivityAnimating != active else {
            return
        }

        isTokenActivityAnimating = active
        updateActivityAnimation()
    }

    private func updateActivityAnimation() {
        for key in ["walkBob", "tokenActivityBob", "tokenActivityPulse"] {
            layer?.removeAnimation(forKey: key)
        }
        guard animationsEnabled, !isDefeated else { return }
        if isTokenActivityAnimating {
            startTokenActivityAnimation()
        } else if isWalking {
            startWalkAnimation()
        }
    }

    func playAttackTell(direction: CGFloat, reach: CGFloat = 7) {
        guard animationsEnabled, !isDefeated, let layer else { return }

        let lunge = CAKeyframeAnimation(keyPath: "transform.translation.x")
        lunge.values = [0, -reach * 0.25, reach, reach * 0.35, 0]
        lunge.keyTimes = [0, 0.16, 0.42, 0.70, 1]
        lunge.duration = 0.28
        lunge.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(lunge, forKey: "attackLunge")

        let recoil = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        recoil.values = [0, 0.08 * direction, -0.13 * direction, 0]
        recoil.keyTimes = [0, 0.18, 0.46, 1]
        recoil.duration = 0.28
        recoil.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(recoil, forKey: "attackRecoil")
    }

    private func startWalkAnimation() {
        let bob = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bob.values = [0, -2.0, 0, -1.0, 0]
        bob.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        bob.duration = 0.36
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .linear)
        layer?.add(bob, forKey: "walkBob")
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

    override func draw(_ dirtyRect: NSRect) {
        switch kind {
        case .hero:
            drawHero()
        case .monster:
            drawMonster()
        }
    }

    /// Sprites are authored on a 16x16 unit grid and centered in the view, so a
    /// single origin + unit size drives every cell.
    private func drawSprite(_ sprite: PixelSprite, scale: CGFloat = 1) {
        let unit = min(bounds.width, bounds.height) / 16 * scale
        PixelSpriteRenderer.draw(
            sprite,
            unit: unit,
            originX: (bounds.width - unit * 16) / 2,
            originY: (bounds.height - unit * 16) / 2
        )
    }

    private func drawHero() {
        if isDefeated {
            drawSprite(PixelSprites.soulHero)
            return
        }

        let spec = heroRole.spec
        drawSprite(PixelSprites.heroBody(palette: spec.palette) + spec.accessory)
    }

    private func drawMonster() {
        // Bosses are drawn 22% larger than the grid would give, so they read as
        // bigger without needing their own sprite.
        let sprite = isBoss
            ? monsterKind.spec.sprite + PixelSprites.bossCrown
            : monsterKind.spec.sprite
        drawSprite(sprite, scale: isBoss ? 1.22 : 1)
    }
}
