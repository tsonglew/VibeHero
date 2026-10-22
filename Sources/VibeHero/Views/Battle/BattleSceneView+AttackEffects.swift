import AppKit

// MARK: - Energy laser (hero) and wolf claw (monster) attack effects

extension BattleSceneView {
    func playShockwave(isCrit: Bool) {
        guard animatesCombatEffects else { return }
        monsterHitFlashLayer.attachIfNeeded(to: effectsLayer)
        let heroPos = CGPoint(x: heroView.frame.maxX - 2, y: heroView.frame.midY)
        let monsterPos = CGPoint(x: monsterVisualFrame.minX + 4, y: monsterVisualFrame.midY)
        let now = CACurrentMediaTime()

        heroView.playAttackTell(direction: 1, reach: isCrit ? 9 : 7)

        // Create jagged laser path with energy fluctuation
        let laserPath = CGMutablePath()
        laserPath.move(to: heroPos)

        // Add jagged points for energy feel
        let segments = 6
        let dx = (monsterPos.x - heroPos.x) / CGFloat(segments)
        for i in 1...segments {
            let x = heroPos.x + dx * CGFloat(i)
            let jitter = i == segments ? 0 : CGFloat.random(in: -3...3)
            let y = heroPos.y + (monsterPos.y - heroPos.y) * CGFloat(i) / CGFloat(segments) + jitter
            laserPath.addLine(to: CGPoint(x: x, y: y))
        }

        // 1. Outer glow (thicker, translucent)
        effects.laserGlow.removeAllAnimations()
        effects.laserGlow.path = laserPath
        effects.laserGlow.strokeColor = NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.4).cgColor
        effects.laserGlow.lineWidth = isCrit ? 12 : 8
        effects.laserGlow.lineCap = .round
        effects.laserGlow.shadowColor = NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0).cgColor
        effects.laserGlow.shadowRadius = 10
        effects.laserGlow.shadowOpacity = 0.7
        effects.laserGlow.opacity = 0

        effects.laserGlow.attachIfNeeded(to: effectsLayer)

        // 2. Core beam (bright white-blue)
        effects.laserCore.removeAllAnimations()
        effects.laserCore.path = laserPath
        effects.laserCore.strokeColor = NSColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.95).cgColor
        effects.laserCore.lineWidth = isCrit ? 4 : 3
        effects.laserCore.lineCap = .round
        effects.laserCore.shadowColor = NSColor.white.cgColor
        effects.laserCore.shadowRadius = 4
        effects.laserCore.shadowOpacity = 0.9
        effects.laserCore.opacity = 0

        effects.laserCore.attachIfNeeded(to: effectsLayer)

        // Flash animation for main laser
        let laserFlash = CAKeyframeAnimation(keyPath: "opacity")
        laserFlash.values = [0, 1, 1, 0]
        laserFlash.keyTimes = [0, 0.1, 0.6, 1]
        laserFlash.duration = 0.2

        let glowFlash = CAKeyframeAnimation(keyPath: "opacity")
        glowFlash.values = [0, 0.8, 0.8, 0]
        glowFlash.keyTimes = [0, 0.1, 0.6, 1]
        glowFlash.duration = 0.22

        effects.laserCore.add(laserFlash, forKey: "flash")
        effects.laserGlow.add(glowFlash, forKey: "flash")

        // 3. Energy flickers (short arcs along the beam)
        for (index, flicker) in effects.laserFlickers.enumerated() {
            let t = CGFloat(index + 1) / CGFloat(effects.laserFlickers.count + 1)
            let baseX = heroPos.x + (monsterPos.x - heroPos.x) * t
            let baseY = heroPos.y + (monsterPos.y - heroPos.y) * t

            // Small arc flicker
            let flickerPath = CGMutablePath()
            let arcRadius: CGFloat = 6
            let startAngle = CGFloat.random(in: 0...(2 * .pi))
            flickerPath.addArc(
                center: CGPoint(x: baseX, y: baseY),
                radius: arcRadius,
                startAngle: startAngle,
                endAngle: startAngle + .pi * 0.6,
                clockwise: false
            )

            flicker.removeAllAnimations()
            flicker.path = flickerPath
            flicker.strokeColor = NSColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 0.8).cgColor
            flicker.lineWidth = 2
            flicker.lineCap = .round
            flicker.opacity = 0

        flicker.attachIfNeeded(to: effectsLayer)

            let flickerFlash = CABasicAnimation(keyPath: "opacity")
            flickerFlash.fromValue = 1
            flickerFlash.toValue = 0
            flickerFlash.duration = 0.12
            flickerFlash.beginTime = now + Double(index) * 0.02

            flicker.add(flickerFlash, forKey: "flash")
        }

        // 4. Impact burst at monster
        let burstSize: CGFloat = isCrit ? 18 : 12
        let burstPath = CGMutablePath()
        // Electric spark burst
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 + CGFloat.random(in: -0.2...0.2)
            let r1 = burstSize * CGFloat.random(in: 0.8...1.2)
            let r2 = burstSize * 0.3
            burstPath.move(to: CGPoint(x: r2 * cos(angle), y: r2 * sin(angle)))
            burstPath.addLine(to: CGPoint(x: r1 * cos(angle), y: r1 * sin(angle)))
        }

        effects.impactBurst.removeAllAnimations()
        effects.impactBurst.path = burstPath
        effects.impactBurst.position = monsterPos
        effects.impactBurst.strokeColor = NSColor(red: 0.8, green: 0.95, blue: 1.0, alpha: 0.9).cgColor
        effects.impactBurst.fillColor = nil
        effects.impactBurst.lineWidth = 2
        effects.impactBurst.lineCap = .round
        effects.impactBurst.shadowColor = NSColor(red: 0.5, green: 0.85, blue: 1.0, alpha: 1.0).cgColor
        effects.impactBurst.shadowRadius = 8
        effects.impactBurst.shadowOpacity = 0.9
        effects.impactBurst.opacity = 0

        effects.impactBurst.attachIfNeeded(to: effectsLayer)

        let burstFlash = CABasicAnimation(keyPath: "opacity")
        burstFlash.fromValue = 1
        burstFlash.toValue = 0
        burstFlash.duration = 0.12
        burstFlash.beginTime = now + Self.heroImpactDelay

        let burstScale = CABasicAnimation(keyPath: "transform.scale")
        burstScale.fromValue = 0.6
        burstScale.toValue = 1.2
        burstScale.duration = 0.12
        burstScale.beginTime = now + Self.heroImpactDelay

        effects.impactBurst.add(burstFlash, forKey: "flash")
        effects.impactBurst.add(burstScale, forKey: "scale")

        // 5. Monster hit flash and shake - committed with the damage update.
        placeEffect(monsterHitFlashLayer, frame: monsterVisualFrame.insetBy(dx: -2, dy: -2))
        monsterHitFlashLayer.removeAllAnimations()
        let hitFlash = CAKeyframeAnimation(keyPath: "opacity")
        hitFlash.values = [0.55, 0]
        hitFlash.keyTimes = [0, 1]
        hitFlash.duration = 0.14
        hitFlash.beginTime = now + Self.heroImpactDelay
        hitFlash.timingFunction = CAMediaTimingFunction(name: .easeOut)
        monsterHitFlashLayer.opacity = 0
        monsterHitFlashLayer.add(hitFlash, forKey: "monsterHitWhiteFlash")

        // Monster shake - synchronized
        let shakeDistance: CGFloat = isCrit ? 7 : 4
        let shakeDuration: CFTimeInterval = isCrit ? 0.3 : 0.22
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -shakeDistance, shakeDistance * 0.7, -shakeDistance * 0.4, 0]
        shake.duration = shakeDuration
        shake.beginTime = now + Self.heroImpactDelay
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        monsterView.layer?.add(shake, forKey: "monsterHitShake")

    }

    @discardableResult
    func playMonsterAttack(damage: CGFloat) -> Bool {
        guard !combatPaused, rendersCombatEffects, monsterEngaged else {
            return false
        }
        playWolfClawAttack()
        showFloatingText(
            L10n.string(.hpDamageDecimal, Double(damage)),
            color: NSColor(red: 1.0, green: 0.36, blue: 0.32, alpha: 1.0),
            anchor: .hero
        )
        playFlash(color: NSColor(red: 1.0, green: 0.18, blue: 0.16, alpha: 0.20))
        shakeHero()
        return true
    }

    func playWolfClawAttack() {
        guard animatesCombatEffects else { return }
        heroImpactLayer.attachIfNeeded(to: effectsLayer)
        // Wolf claw slash - fierce energy claw marks raking toward hero
        let clawColor = monsterKind.hpColor
        let now = CACurrentMediaTime()

        // Start from monster's claw position (front paw)
        let clawStart = CGPoint(x: monsterVisualFrame.minX - 2, y: monsterVisualFrame.midY - 4)
        let heroPos = CGPoint(x: heroView.frame.midX, y: heroView.frame.midY)

        // Direction toward hero
        let dx = heroPos.x - clawStart.x
        let dy = heroPos.y - clawStart.y
        let baseAngle = atan2(dy, dx)

        // Three claw slashes with natural spread (like wolf paw)
        let clawSpread: [CGFloat] = [-0.25, 0, 0.25] // Radians spread
        let clawLengths: [CGFloat] = [32, 38, 30]   // Varying lengths

        for index in 0..<3 {
            let angle = baseAngle + clawSpread[index]
            let length = clawLengths[index]

            // Create fierce claw path - jagged, aggressive curve
            let clawPath = CGMutablePath()
            let startPoint = clawStart

            // End point with some randomness for wild feel
            let endPoint = CGPoint(
                x: startPoint.x + length * cos(angle) + CGFloat.random(in: -3...3),
                y: startPoint.y + length * sin(angle) + CGFloat.random(in: -2...2)
            )

            // Control points for aggressive S-curve (like claw raking)
            let ctrl1 = CGPoint(
                x: startPoint.x + length * 0.3 * cos(angle - 0.3),
                y: startPoint.y + length * 0.3 * sin(angle - 0.3)
            )
            let ctrl2 = CGPoint(
                x: startPoint.x + length * 0.7 * cos(angle + 0.2),
                y: startPoint.y + length * 0.7 * sin(angle + 0.2)
            )

            clawPath.move(to: startPoint)
            clawPath.addCurve(to: endPoint, control1: ctrl1, control2: ctrl2)

            // Glow layer (outer, thicker)
            let glow = effects.clawGlows[index]
            glow.removeAllAnimations()
            glow.path = clawPath
            glow.strokeColor = clawColor.withAlphaComponent(0.5).cgColor
            glow.lineWidth = 8 - CGFloat(index)
            glow.lineCap = .round
            glow.shadowColor = clawColor.cgColor
            glow.shadowRadius = 8
            glow.shadowOpacity = 0.8
            glow.opacity = 0

        glow.attachIfNeeded(to: effectsLayer)

            // Core layer (inner, bright)
            let core = effects.clawCores[index]
            core.removeAllAnimations()
            core.path = clawPath
            core.strokeColor = NSColor.white.withAlphaComponent(0.9).cgColor
            core.lineWidth = 3 - CGFloat(index) * 0.5
            core.lineCap = .round
            core.shadowColor = clawColor.cgColor
            core.shadowRadius = 4
            core.shadowOpacity = 0.9
            core.opacity = 0

        core.attachIfNeeded(to: effectsLayer)

            // Animate with staggered timing (claws rake in sequence)
            let delay = Double(index) * 0.05

            let glowStroke = CABasicAnimation(keyPath: "strokeEnd")
            glowStroke.fromValue = 0
            glowStroke.toValue = 1
            glowStroke.duration = 0.1
            glowStroke.beginTime = now + delay
            glowStroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let glowFade = CAKeyframeAnimation(keyPath: "opacity")
            glowFade.values = [0, 1, 1, 0]
            glowFade.keyTimes = [0, 0.2, 0.6, 1]
            glowFade.duration = 0.3
            glowFade.beginTime = now + delay

            let coreStroke = CABasicAnimation(keyPath: "strokeEnd")
            coreStroke.fromValue = 0
            coreStroke.toValue = 1
            coreStroke.duration = 0.08
            coreStroke.beginTime = now + delay + 0.02
            coreStroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let coreFade = CAKeyframeAnimation(keyPath: "opacity")
            coreFade.values = [0, 1, 1, 0]
            coreFade.keyTimes = [0, 0.15, 0.5, 1]
            coreFade.duration = 0.25
            coreFade.beginTime = now + delay + 0.02

            glow.add(glowStroke, forKey: "stroke")
            glow.add(glowFade, forKey: "fade")
            core.add(coreStroke, forKey: "stroke")
            core.add(coreFade, forKey: "fade")
        }

        // Energy sparks flying from claw impact
        for (index, spark) in effects.clawSparks.enumerated() {
            let size = CGFloat.random(in: 2...5)
            let sparkAngle = baseAngle + CGFloat.random(in: -0.5...0.5)
            let sparkDist = CGFloat.random(in: 15...35)

            spark.removeAllAnimations()
            spark.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: size, height: size), transform: nil)
            spark.fillColor = (index % 2 == 0)
                ? NSColor.white.withAlphaComponent(0.9).cgColor
                : clawColor.withAlphaComponent(0.8).cgColor
            spark.shadowColor = clawColor.cgColor
            spark.shadowRadius = 3
            spark.shadowOpacity = 0.7
            spark.opacity = 0

        spark.attachIfNeeded(to: effectsLayer)

            let startPos = CGPoint(
                x: clawStart.x + 10 * cos(baseAngle),
                y: clawStart.y + 10 * sin(baseAngle)
            )
            spark.position = startPos

            let endPos = CGPoint(
                x: startPos.x + sparkDist * cos(sparkAngle),
                y: startPos.y + sparkDist * sin(sparkAngle)
            )

            let moveAnim = CABasicAnimation(keyPath: "position")
            moveAnim.fromValue = startPos
            moveAnim.toValue = endPos
            moveAnim.duration = Double.random(in: 0.15...0.25)
            moveAnim.beginTime = now + Double(index) * 0.02

            let fadeAnim = CAKeyframeAnimation(keyPath: "opacity")
            fadeAnim.values = [0, 1, 0]
            fadeAnim.keyTimes = [0, 0.3, 1]
            fadeAnim.duration = moveAnim.duration
            fadeAnim.beginTime = now + Double(index) * 0.02

            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 1
            scaleAnim.toValue = 0.2
            scaleAnim.duration = moveAnim.duration
            scaleAnim.beginTime = now + Double(index) * 0.02

            spark.add(moveAnim, forKey: "move")
            spark.add(fadeAnim, forKey: "fade")
            spark.add(scaleAnim, forKey: "scale")
        }

        // Impact flash on hero (claw hit)
        heroImpactLayer.removeAllAnimations()
        placeEffect(heroImpactLayer, at: CGPoint(x: heroView.frame.midX, y: heroView.frame.midY))

        let impactFlash = CABasicAnimation(keyPath: "opacity")
        impactFlash.fromValue = 1
        impactFlash.toValue = 0
        impactFlash.duration = 0.15
        impactFlash.beginTime = now + Self.monsterImpactDelay

        let impactScale = CABasicAnimation(keyPath: "transform.scale")
        impactScale.fromValue = 0.6
        impactScale.toValue = 1.4
        impactScale.duration = 0.15
        impactScale.beginTime = now + Self.monsterImpactDelay

        heroImpactLayer.add(impactFlash, forKey: "impactFlash")
        heroImpactLayer.add(impactScale, forKey: "impactScale")
    }

}
