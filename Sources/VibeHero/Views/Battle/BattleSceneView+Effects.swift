import AppKit

extension BattleSceneView {
    func playLootDrop(_ drop: LootDrop) {
        guard rendersCombatEffects else {
            return
        }

        guard animatesCombatEffects else {
            showFloatingText(drop.equipment?.displayName ?? drop.kind.name, color: drop.kind.color, anchor: .center)
            return
        }
        let itemLayer = CAShapeLayer()
        let size: CGFloat = 16
        itemLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        itemLayer.path = lootPath(for: drop, in: itemLayer.bounds)
        itemLayer.fillColor = (drop.equipment?.rarity.color ?? drop.kind.color).cgColor
        itemLayer.strokeColor = NSColor.white.withAlphaComponent(0.82).cgColor
        itemLayer.lineWidth = 1.2
        itemLayer.lineJoin = .miter
        if let rarity = drop.equipment?.rarity, rarity >= .rare {
            itemLayer.shadowColor = rarity.color.cgColor
            itemLayer.shadowOpacity = 0.6
            itemLayer.shadowRadius = 3
        } else {
            itemLayer.shadowOpacity = 0
        }
        itemLayer.position = CGPoint(x: heroView.frame.midX, y: heroView.frame.midY)
        effectsLayer?.addSublayer(itemLayer)

        let start = CGPoint(x: monsterVisualFrame.midX, y: monsterVisualFrame.midY)
        let bounce = CGPoint(x: monsterVisualFrame.midX - 18, y: max(14, monsterVisualFrame.minY - 8))
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

        showFloatingText(L10n.string(.hpHeal, restoredHP), color: healColor, anchor: .hero)
        guard animatesCombatEffects else { return }
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
        effectsLayer?.addSublayer(rays)

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
            effectsLayer?.addSublayer(shard)

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            rays.removeFromSuperlayer()
        }
    }

    func reloadLocalization() {
        // Static feedback can outlive the event that produced it. Clear that
        // text so switching languages cannot leave a persistent mixed HUD.
        for label in floatingTextLabels {
            label.layer?.removeAllAnimations()
            label.alphaValue = 0
        }
        needsDisplay = true
    }

    // MARK: - Floating combat text

    enum FloatingTextAnchor {
        case hero
        case monster
        case center
    }

    enum FloatingTextStyle {
        case normal
        case crit
        case banner
    }

    func showFloatingText(
        _ text: String,
        color: NSColor,
        fontSize: CGFloat = 11,
        anchor: FloatingTextAnchor,
        style: FloatingTextStyle = .normal
    ) {
        guard rendersCombatEffects, bounds.width > 40 else {
            return
        }

        // Reduced motion keeps one stable message per anchor, updated in place.
        let index: Int
        if animatesCombatEffects {
            index = floatingTextIndex
            floatingTextIndex = (floatingTextIndex + 1) % floatingTextLabels.count
        } else {
            switch anchor {
            case .hero: index = 0
            case .monster: index = 1
            case .center: index = 2
            }
        }
        let label = floatingTextLabels[index]
        label.layer?.removeAllAnimations()
        label.removeFromSuperview()
        addSubview(label)

        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        label.stringValue = text
        label.textColor = color
        label.font = font

        let height: CGFloat = fontSize + 6
        // Fit the label to its text. A fixed-width centered label would put the
        // number back on the victim's chest no matter where we move the frame,
        // and the damage has to read as "this actor lost that much HP".
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width) + 6
        let width = min(style == .banner ? 220 : textWidth, max(40, bounds.width - 4))
        let rise: CGFloat = animatesCombatEffects ? (style == .crit ? 20 : style == .banner ? 12 : 15) : 0
        let gap: CGFloat = 3

        let originX: CGFloat
        let originY: CGFloat
        switch anchor {
        case .monster:
            // Beside the monster, on its outer side so the number never hides
            // under the impact art landing on the side facing the hero. If the
            // monster is hugging the right edge, it goes on the near side.
            let outer = monsterVisualFrame.maxX + gap
            originX = outer + width <= bounds.width - 2 ? outer : monsterVisualFrame.minX - gap - width
            originY = monsterVisualFrame.midY - height / 2 + 4
        case .hero:
            // Mirror image: the hero's own damage pops out to its left.
            let outer = heroView.frame.minX - gap - width
            originX = outer >= 2 ? outer : heroView.frame.maxX + gap
            originY = heroView.frame.midY - height / 2 + 4
        case .center:
            originX = bounds.midX - width / 2
            originY = bounds.midY - height / 2
        }

        // Small jitter so two hits in a row don't stack into one blur, kept
        // tight now that the label is glued to the actor's side.
        let jitter: CGFloat = !animatesCombatEffects || style == .banner ? 0 : CGFloat.random(in: -3...3)
        let startFrame = NSRect(
            x: max(2, min(bounds.width - width - 2, originX)),
            // Keep the whole rise inside the scene, or it fades out clipped.
            y: max(1, min(bounds.height - height - rise - 1, originY + jitter)),
            width: width,
            height: height
        )
        label.frame = startFrame
        if !animatesCombatEffects {
            label.alphaValue = 1
            return
        }
        // The fade below runs as a layer keyframe, so the label's resting state
        // is invisible and nothing has to clean it up afterwards.
        label.alphaValue = 0

        guard let textLayer = label.layer else {
            return
        }

        // Pop in from an oversize scale so hits feel punchy.
        let popScale: CGFloat = style == .crit ? 1.7 : style == .banner ? 1.0 : 1.35
        if popScale > 1 {
            let pop = CABasicAnimation(keyPath: "transform")
            pop.fromValue = CATransform3DMakeScale(popScale, popScale, 1)
            pop.toValue = CATransform3DIdentity
            pop.duration = 0.16
            pop.timingFunction = CAMediaTimingFunction(name: .easeOut)
            textLayer.add(pop, forKey: "floatingTextPop")
        }

        let duration: Double = style == .crit ? 0.95 : style == .banner ? 1.15 : 0.7

        // Rise and fade on the layer rather than through `animator().frame`:
        // resizing a text field re-renders its text on every frame of the
        // animation, and a damage number goes up on every single hit.
        let drift = CABasicAnimation(keyPath: "position.y")
        drift.fromValue = textLayer.position.y
        drift.toValue = textLayer.position.y + rise
        drift.duration = duration
        drift.timingFunction = CAMediaTimingFunction(name: .easeOut)
        textLayer.add(drift, forKey: "floatingTextRise")

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.45, 1]
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        textLayer.add(fade, forKey: "floatingTextFade")
    }

    func playCombo(_ count: Int) {
        showFloatingText(
            L10n.string(.comboText, count),
            color: NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1.0),
            fontSize: 10,
            anchor: .center
        )
    }

    func playStageBanner(_ text: String, isBoss: Bool) {
        guard rendersCombatEffects else {
            return
        }
        showFloatingText(
            text,
            color: isBoss
                ? NSColor(red: 1.0, green: 0.42, blue: 0.38, alpha: 1.0)
                : NSColor(red: 1.0, green: 0.86, blue: 0.36, alpha: 1.0),
            fontSize: 13,
            anchor: .center,
            style: .banner
        )
        if isBoss {
            playFlash(color: NSColor(red: 1.0, green: 0.24, blue: 0.2, alpha: 0.30))
        }
    }

    func playLevelUp() {
        guard rendersCombatEffects else {
            return
        }

        let gold = NSColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 1.0)
        playFlash(color: gold.withAlphaComponent(0.24))
        showFloatingText(L10n.text(.levelUpBanner), color: gold, fontSize: 13, anchor: .center, style: .banner)
        guard animatesCombatEffects else { return }

        let center = CGPoint(x: heroView.frame.midX, y: heroView.frame.midY)
        for index in 0..<8 {
            let shard = CALayer()
            shard.backgroundColor = index % 2 == 0 ? gold.cgColor : NSColor.white.withAlphaComponent(0.9).cgColor
            shard.shadowColor = gold.cgColor
            shard.shadowOpacity = 0.3
            shard.shadowRadius = 2
            shard.frame = NSRect(x: 0, y: 0, width: 4, height: 4)
            shard.position = center
            effectsLayer?.addSublayer(shard)

            let angle = CGFloat(index) / 8 * CGFloat.pi * 2
            let distance = CGFloat(16 + (index % 3) * 6)
            let end = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)

            let fly = CABasicAnimation(keyPath: "position")
            fly.fromValue = center
            fly.toValue = end
            fly.duration = 0.45
            fly.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.4
            fade.beginTime = CACurrentMediaTime() + 0.12
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false

            shard.add(fly, forKey: "levelUpShardFly")
            shard.add(fade, forKey: "levelUpShardFade")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                shard.removeFromSuperlayer()
            }
        }

        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1.0, 1.28, 1.0]
        pulse.keyTimes = [0, 0.42, 1]
        pulse.duration = 0.44
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        heroView.layer?.add(pulse, forKey: "levelUpPulse")
    }

    @discardableResult
    func playAttack(
        damageText: String,
        isCrit: Bool = false
    ) -> Bool {
        guard !combatPaused, !heroDefeated, rendersCombatEffects, monsterEngaged, let monster = currentMonster else {
            return false
        }

        enqueueHeroAttack(HeroAttackRequest(monsterID: monster.id, damageText: damageText, isCrit: isCrit))
        return true
    }

    func enqueueHeroAttack(_ request: HeroAttackRequest) {
        guard !combatPaused, rendersCombatEffects, !heroDefeated, request.monsterID == currentMonster?.id else { return }
        if !animatesCombatEffects {
            showHeroAttackText(request)
            return
        }
        if heroAttackQueue.count >= Self.maximumPendingVisualAttacks {
            heroAttackQueue.removeFirst()
        }
        heroAttackQueue.append(request)
        playNextHeroAttackIfNeeded()
    }

    func playNextHeroAttackIfNeeded() {
        guard !isAttackInProgress else {
            return
        }
        guard !heroDefeated, animatesCombatEffects, monsterEngaged else {
            heroAttackQueue.removeAll()
            return
        }
        guard !heroAttackQueue.isEmpty else {
            return
        }

        heroAttackQueue.removeAll { $0.monsterID != currentMonster?.id }
        guard !heroAttackQueue.isEmpty else { return }
        let request = heroAttackQueue.removeFirst()
        isAttackInProgress = true
        playShockwave(isCrit: request.isCrit)
        showHeroAttackText(request)
        let generation = visualGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.heroAttackDuration) { [weak self] in
            self?.finishHeroAttack(generation: generation)
        }
    }

    func finishHeroAttack(generation: UInt64) {
        guard generation == visualGeneration, animatesCombatEffects else { return }
        isAttackInProgress = false
        playNextHeroAttackIfNeeded()
    }

    func showHeroAttackText(_ request: HeroAttackRequest) {
        if let damageText = request.damageText {
            if request.isCrit {
                self.showFloatingText(
                    "\(L10n.text(.critLabel)) -\(damageText)",
                    color: NSColor(red: 1.0, green: 0.84, blue: 0.24, alpha: 1.0),
                    fontSize: 14,
                    anchor: .monster,
                    style: .crit
                )
            } else {
                self.showFloatingText(
                    "-\(damageText)",
                    color: NSColor(red: 0.5, green: 0.85, blue: 1.0, alpha: 1.0),
                    anchor: .monster
                )
            }
        }
    }


    func pulseMonster() {
        guard animatesCombatEffects else { return }
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

    /// Put a reused effect layer exactly where the hit happened. A bare CALayer
    /// animates its own geometry implicitly, so without this the layer spends a
    /// quarter second gliding over from the last hit while the explicit
    /// animation it was moved for is already playing somewhere else.
    func placeEffect(_ layer: CALayer, at point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position = point
        CATransaction.commit()
    }

    func placeEffect(_ layer: CALayer, frame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = frame
        CATransaction.commit()
    }

    func playFlash(color: NSColor) {
        guard animatesCombatEffects else { return }
        flashLayer.attachIfNeeded(to: effectsLayer)
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

    func shakeHero() {
        shake(layer: heroView.layer, distance: -4, duration: 0.24)
    }

    func shake(layer: CALayer?, distance: CGFloat, duration: CFTimeInterval) {
        guard animatesCombatEffects else { return }
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, distance, -distance * 0.65, distance * 0.35, 0]
        shake.duration = duration
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.add(shake, forKey: "shake")
    }

    func lootPath(for drop: LootDrop, in rect: CGRect) -> CGPath {
        switch drop.kind {
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
        case .equipment:
            return equipmentPath(for: drop.equipment?.slot ?? .weapon, in: rect)
        }
    }

    func equipmentPath(for slot: EquipmentSlot, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        switch slot {
        case .weapon:
            path.addRect(CGRect(x: 7, y: 1, width: 2, height: 9))
            path.addRect(CGRect(x: 4, y: 10, width: 8, height: 2))
            path.addRect(CGRect(x: 7, y: 12, width: 2, height: 3))
        case .armor:
            path.addRect(CGRect(x: 3, y: 2, width: 10, height: 3))
            path.addRect(CGRect(x: 4, y: 5, width: 8, height: 8))
            path.addRect(CGRect(x: 7, y: 5, width: 2, height: 3))
        case .charm:
            path.move(to: CGPoint(x: rect.midX, y: 1))
            path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 1))
            path.addLine(to: CGPoint(x: 2, y: rect.midY))
            path.closeSubpath()
            path.addRect(CGRect(x: 7, y: 7, width: 2, height: 2))
        }
        return path
    }

    func reviveRaysPath(center: CGPoint) -> NSBezierPath {
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

}
