import AppKit

final class PixelBarView: NSView {
    var value: CGFloat = 0.5 {
        didSet {
            let clamped = min(max(value, 0), 1)
            if clamped != value {
                value = clamped
                return
            }
            updateFillLayers(oldValue: oldValue)
        }
    }

    var fillColor = NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1.0) {
        didSet {
            fillLayer.backgroundColor = fillColor.cgColor
            ghostLayer.backgroundColor = ghostFillColor().cgColor
            damageFlashLayer.backgroundColor = damageFlashColor().cgColor
        }
    }

    var trackColor = NSColor.white.withAlphaComponent(0.12) {
        didSet {
            trackLayer.backgroundColor = trackColor.cgColor
        }
    }

    var isWarning = false {
        didSet {
            guard isWarning != oldValue else {
                return
            }
            updateWarningPulse()
        }
    }

    private let trackLayer = CALayer()
    private let ghostLayer = CALayer()
    private let fillLayer = CALayer()
    private let damageFlashLayer = CALayer()
    private static let minimumDamageFlashWidth: CGFloat = 3

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        trackLayer.backgroundColor = trackColor.cgColor
        ghostLayer.backgroundColor = ghostFillColor().cgColor
        fillLayer.backgroundColor = fillColor.cgColor
        damageFlashLayer.backgroundColor = damageFlashColor().cgColor
        damageFlashLayer.opacity = 0

        for barLayer in [trackLayer, ghostLayer, fillLayer] {
            barLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
            layer?.addSublayer(barLayer)
        }
        layer?.addSublayer(damageFlashLayer)
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = bounds.height / 2
        for barLayer in [trackLayer, ghostLayer, fillLayer] {
            barLayer.position = CGPoint(x: 0, y: bounds.midY)
            barLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
            barLayer.cornerRadius = radius
        }
        damageFlashLayer.cornerRadius = radius
        fillLayer.transform = CATransform3DMakeScale(value, 1, 1)
        ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
        CATransaction.commit()
    }

    private func updateFillLayers(oldValue: CGFloat) {
        let presentedGhostValue = (ghostLayer.presentation()?.value(forKeyPath: "transform.scale.x") as? NSNumber)
            .map { CGFloat(truncating: $0) }
        let visibleGhostValue = min(1, max(value, presentedGhostValue ?? oldValue))

        fillLayer.removeAllAnimations()
        ghostLayer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.transform = CATransform3DMakeScale(value, 1, 1)
        CATransaction.commit()

        guard value < oldValue else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
            CATransaction.commit()
            updateWarningPulse()
            return
        }

        let drain = CABasicAnimation(keyPath: "transform.scale.x")
        drain.fromValue = visibleGhostValue
        drain.toValue = value
        drain.beginTime = CACurrentMediaTime() + 0.04
        drain.duration = 0.24
        drain.timingFunction = CAMediaTimingFunction(name: .easeOut)
        drain.fillMode = .backwards
        drain.isRemovedOnCompletion = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
        CATransaction.commit()
        ghostLayer.add(drain, forKey: "ghostDrain")
        playDamageFlash(oldValue: oldValue)
        updateWarningPulse()
    }

    static func visibleDamageWidth(oldValue: CGFloat, newValue: CGFloat, barWidth: CGFloat) -> CGFloat {
        guard oldValue > newValue, barWidth > 0 else {
            return 0
        }
        let actualWidth = (oldValue - newValue) * barWidth
        return min(barWidth, max(actualWidth, minimumDamageFlashWidth))
    }

    private func playDamageFlash(oldValue: CGFloat) {
        let flashWidth = Self.visibleDamageWidth(oldValue: oldValue, newValue: value, barWidth: bounds.width)
        guard flashWidth > 0, bounds.height > 0 else {
            return
        }

        let oldTrailingEdge = min(bounds.width, max(0, oldValue * bounds.width))
        let originX = min(bounds.width - flashWidth, max(0, oldTrailingEdge - flashWidth))
        damageFlashLayer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        damageFlashLayer.frame = CGRect(x: originX, y: 0, width: flashWidth, height: bounds.height)
        damageFlashLayer.opacity = 0
        CATransaction.commit()

        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0.95, 0.75, 0]
        flash.keyTimes = [0, 0.35, 1]
        flash.duration = 0.36
        flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
        damageFlashLayer.add(flash, forKey: "damageFlash")
    }

    private func ghostFillColor() -> NSColor {
        guard let blended = fillColor.blended(withFraction: 0.5, of: .white) else {
            return fillColor.withAlphaComponent(0.55)
        }
        return blended.withAlphaComponent(0.55)
    }

    private func damageFlashColor() -> NSColor {
        fillColor.blended(withFraction: 0.78, of: .white) ?? .white
    }

    private func updateWarningPulse() {
        fillLayer.removeAnimation(forKey: "lowHPPulse")
        guard isWarning else {
            return
        }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.5
        pulse.duration = 0.5
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fillLayer.add(pulse, forKey: "lowHPPulse")
    }
}

enum BattleBackdrop: String, CaseIterable {
    case midnightForest
    case crystalCave
    case sunsetDunes
    case neonCity

    private static let defaultsKey = "VibeHero.backdrop"

    var name: String {
        switch self {
        case .midnightForest: L10n.text(.backdropMidnightForest)
        case .crystalCave: L10n.text(.backdropCrystalCave)
        case .sunsetDunes: L10n.text(.backdropSunsetDunes)
        case .neonCity: L10n.text(.backdropNeonCity)
        }
    }

    var accentColor: CGColor {
        switch self {
        case .midnightForest:
            NSColor(red: 0.16, green: 0.52, blue: 0.44, alpha: 0.5).cgColor
        case .crystalCave:
            NSColor(red: 0.48, green: 0.34, blue: 0.78, alpha: 0.5).cgColor
        case .sunsetDunes:
            NSColor(red: 0.85, green: 0.52, blue: 0.28, alpha: 0.5).cgColor
        case .neonCity:
            NSColor(red: 0.20, green: 0.44, blue: 0.85, alpha: 0.5).cgColor
        }
    }

    static func load() -> BattleBackdrop {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
              let backdrop = BattleBackdrop(rawValue: rawValue) else {
            return .midnightForest
        }
        return backdrop
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}

final class BackdropView: NSView {
    // Ground-layer scroll speed in points/second; BattleSceneView uses the same
    // value so world-anchored monsters slide with the ground under them.
    static let groundScrollSpeed: CGFloat = 54

    var backdrop: BattleBackdrop = .midnightForest {
        didSet {
            rebuildScrollingLayers()
            needsDisplay = true
        }
    }

    // World scrolling is paused while the HUD is collapsed or the window is hidden.
    var scrollingEnabled = false {
        didSet {
            guard scrollingEnabled != oldValue else {
                return
            }
            applyScrollingState()
        }
    }

    private var scrollLayers: [CALayer] = []
    private var lastTileSize: CGSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func layout() {
        super.layout()
        if bounds.size != lastTileSize {
            rebuildScrollingLayers()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        switch backdrop {
        case .midnightForest:
            drawMidnightForest()
        case .crystalCave:
            drawCrystalCave()
        case .sunsetDunes:
            drawSunsetDunes()
        case .neonCity:
            drawNeonCity()
        }
    }

    private var groundTop: CGFloat {
        max(bounds.height - 10, bounds.height * 0.72)
    }

    private func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
        color.setFill()
        NSBezierPath(rect: NSRect(x: round(x), y: round(y), width: ceil(w), height: ceil(h))).fill()
    }

    private func drawSkyBands(_ colors: [NSColor], groundY: CGFloat) {
        let bandHeight = groundY / CGFloat(colors.count)
        for (index, color) in colors.enumerated() {
            px(0, CGFloat(index) * bandHeight, bounds.width, bandHeight + 1, color)
        }
    }

    private func drawGround(base: NSColor, edge: NSColor) {
        px(0, groundTop, bounds.width, bounds.height - groundTop, base)
        px(0, groundTop, bounds.width, 1.5, edge)
    }

    // MARK: - Scrolling world layers

    // Painter receives (period, stripWidth, groundY) and draws one period's
    // worth of silhouettes repeated across the strip, in y-down coordinates.
    private struct ScrollSpec {
        let period: CGFloat
        let speed: CGFloat
        let painter: (CGFloat, CGFloat, CGFloat) -> Void
    }

    private func rebuildScrollingLayers() {
        scrollLayers.forEach { $0.removeFromSuperlayer() }
        scrollLayers = []
        lastTileSize = bounds.size

        let width = bounds.width
        let height = bounds.height
        guard width > 40, height > 24, let rootLayer = layer else {
            return
        }

        for spec in scrollSpecs(for: backdrop) {
            let stripWidth = width + spec.period
            guard let image = renderTile(width: stripWidth, height: height, spec: spec) else {
                continue
            }

            let tile = CALayer()
            tile.frame = NSRect(x: 0, y: 0, width: stripWidth, height: height)
            tile.contents = image
            tile.contentsScale = backingScale
            tile.contentsGravity = .resize
            rootLayer.addSublayer(tile)

            let scroll = CABasicAnimation(keyPath: "transform.translation.x")
            scroll.fromValue = 0
            scroll.toValue = -spec.period
            scroll.duration = CFTimeInterval(spec.period / spec.speed)
            scroll.repeatCount = .infinity
            scroll.timingFunction = CAMediaTimingFunction(name: .linear)
            tile.add(scroll, forKey: "backdropScroll")

            scrollLayers.append(tile)
        }
        applyScrollingState()
    }

    private var backingScale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func applyScrollingState() {
        for tile in scrollLayers {
            if scrollingEnabled {
                resumeScroll(tile)
            } else {
                pauseScroll(tile)
            }
        }
    }

    /// Freeze a parallax tile on the frame that is currently on screen.
    ///
    /// `speed = 0` alone is not a pause: it drops the layer's local time to
    /// `timeOffset`, which is 0, so the scroll animation snaps back to the start
    /// of its period. Parking the current local time in `timeOffset` first keeps
    /// the tile exactly where it is.
    private func pauseScroll(_ tile: CALayer) {
        guard tile.speed != 0 else { return }
        let paused = tile.convertTime(CACurrentMediaTime(), from: nil)
        tile.speed = 0
        tile.timeOffset = paused
    }

    /// Restart a frozen tile from the frame it was frozen on.
    ///
    /// Without rebasing `beginTime`, the tile jumps to wherever the scroll would
    /// have reached had it never stopped — up to a full parallax period (over
    /// 200pt for the far layers) of instant sideways motion. The hero is drawn
    /// at a fixed spot, so that jump reads as the hero teleporting.
    private func resumeScroll(_ tile: CALayer) {
        guard tile.speed == 0 else { return }
        let paused = tile.timeOffset
        tile.speed = 1
        tile.timeOffset = 0
        tile.beginTime = 0
        tile.beginTime = tile.convertTime(CACurrentMediaTime(), from: nil) - paused
    }

    private func renderTile(width: CGFloat, height: CGFloat, spec: ScrollSpec) -> CGImage? {
        let scale = backingScale
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((width * scale).rounded()),
            pixelsHigh: Int((height * scale).rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        // Draw in y-down point coordinates, matching the view's flipped space.
        let cgContext = context.cgContext
        cgContext.translateBy(x: 0, y: height * scale)
        cgContext.scaleBy(x: scale, y: -scale)

        spec.painter(spec.period, width, groundTop)

        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    private func scrollSpecs(for backdrop: BattleBackdrop) -> [ScrollSpec] {
        switch backdrop {
        case .midnightForest:
            return [
                ScrollSpec(period: 170, speed: 14, painter: forestFarTile),
                ScrollSpec(period: 230, speed: 30, painter: forestNearTile),
                ScrollSpec(period: 26, speed: Self.groundScrollSpeed, painter: groundMarksTile(
                    color: NSColor(red: 0.14, green: 0.38, blue: 0.28, alpha: 1), dashWidth: 7))
            ]
        case .crystalCave:
            return [
                ScrollSpec(period: 150, speed: 14, painter: caveFarTile),
                ScrollSpec(period: 190, speed: 30, painter: caveNearTile),
                ScrollSpec(period: 30, speed: Self.groundScrollSpeed, painter: groundMarksTile(
                    color: NSColor(red: 0.26, green: 0.16, blue: 0.42, alpha: 1), dashWidth: 5))
            ]
        case .sunsetDunes:
            return [
                ScrollSpec(period: 240, speed: 14, painter: dunesFarTile),
                ScrollSpec(period: 200, speed: 30, painter: dunesNearTile),
                ScrollSpec(period: 34, speed: Self.groundScrollSpeed, painter: groundMarksTile(
                    color: NSColor(red: 0.78, green: 0.52, blue: 0.28, alpha: 1), dashWidth: 8))
            ]
        case .neonCity:
            return [
                ScrollSpec(period: 190, speed: 14, painter: cityFarTile),
                ScrollSpec(period: 230, speed: 30, painter: cityNearTile),
                ScrollSpec(period: 24, speed: Self.groundScrollSpeed, painter: groundMarksTile(
                    color: NSColor(red: 0.14, green: 0.30, blue: 0.52, alpha: 1), dashWidth: 6))
            ]
        }
    }

    private func groundMarksTile(color: NSColor, dashWidth: CGFloat) -> (CGFloat, CGFloat, CGFloat) -> Void {
        { period, stripWidth, groundY in
            var x: CGFloat = 0
            while x < stripWidth {
                self.px(x, groundY + 2, dashWidth, 1.5, color)
                x += period
            }
        }
    }

    // MARK: - Scene tile painters (periodic, y-down)

    private func forestFarTile(period: CGFloat, stripWidth: CGFloat, groundY: CGFloat) {
        let green = NSColor(red: 0.04, green: 0.11, blue: 0.10, alpha: 1)
        let trees: [(CGFloat, CGFloat)] = [(12, 12), (60, 9), (108, 14), (146, 10)]
        var base: CGFloat = 0
        while base < stripWidth {
            for (dx, height) in trees {
                let x = base + dx
                let top = groundY - height
                px(x - 0.75, top + 3, 1.5, height - 3, green)
                px(x - 2.5, top + 1, 5, 3.5, green)
                px(x - 4, top + 4, 8, height - 4, green)
            }
            base += period
        }
    }

    private func forestNearTile(period: CGFloat, stripWidth: CGFloat, groundY: CGFloat) {
        let trees: [(CGFloat, CGFloat, Bool)] = [(24, 22, true), (96, 16, false), (168, 24, true)]
        var base: CGFloat = 0
        while base < stripWidth {
            for (dx, height, back) in trees {
                let x = base + dx
                let green = back
                    ? NSColor(red: 0.05, green: 0.14, blue: 0.12, alpha: 1)
                    : NSColor(red: 0.07, green: 0.19, blue: 0.15, alpha: 1)
                let top = groundY - height
                px(x - 1, top + 4, 2, height - 4, green)
                px(x - 2.5, top + 2, 5, 4, green)
                px(x - 4, top + 5, 8, 5, green)
                px(x - 5.5, top + 9, 11, height - 9, green)
            }
            base += period
        }
    }

    private func caveFarTile(period: CGFloat, stripWidth: CGFloat, groundY: CGFloat) {
        let rock = NSColor(red: 0.05, green: 0.03, blue: 0.09, alpha: 1)
        let stalactites: [(CGFloat, CGFloat)] = [(10, 9), (58, 13), (102, 7), (138, 11)]
        var base: CGFloat = 0
        while base < stripWidth {
            for (dx, length) in stalactites {
                let x = base + dx
                px(x - 3, 0, 6, length - 4, rock)
                px(x - 2, length - 4, 4, 2.5, rock)
                px(x - 1, length - 1.5, 2, 1.5, rock)
            }
            base += period
        }
    }

    private func caveNearTile(period: CGFloat, stripWidth: CGFloat, groundY: CGFloat) {
        let teal = NSColor(red: 0.20, green: 0.88, blue: 0.82, alpha: 1)
        let violet = NSColor(red: 0.62, green: 0.36, blue: 1.0, alpha: 1)
        let rock = NSColor(red: 0.07, green: 0.05, blue: 0.12, alpha: 1)
        let crystals: [(CGFloat, NSColor)] = [(20, teal), (110, violet), (160, teal)]
        var base: CGFloat = 0
        while base < stripWidth {
            for (dx, color) in crystals {
                let x = base + dx
                px(x - 3, groundY - 7, 6, 7, color.withAlphaComponent(0.25))
                px(x - 1.5, groundY - 6, 3, 6, color)
                px(x - 3.5, groundY - 3, 2, 3, color.withAlphaComponent(0.75))
            }
            // small stalagmite
            let sx = base + 62
            px(sx - 2.5, groundY - 5, 5, 5, rock)
            px(sx - 1.5, groundY - 7, 3, 3, rock)
            base += period
        }
    }

    private func dunesFarTile(period: CGFloat, stripWidth: CGFloat, groundY: CGFloat) {
        let backDune = NSColor(red: 0.42, green: 0.22, blue: 0.14, alpha: 1)
        var base: CGFloat = 0
        while base < stripWidth {
            px(base, groundY - 7, 130, 7, backDune)
            px(base + 150, groundY - 5, 90, 5, backDune)
            base += period
        }
    }

    private func dunesNearTile(period: CGFloat, stripWidth: CGFloat, groundY: CGFloat) {
        let frontDune = NSColor(red: 0.55, green: 0.30, blue: 0.16, alpha: 1)
        var base: CGFloat = 0
        while base < stripWidth {
            px(base + 30, groundY - 4, 110, 4, frontDune)
            px(base + 150, groundY - 3, 60, 3, frontDune)
            base += period
        }
    }

    private func cityFarTile(period: CGFloat, stripWidth: CGFloat, groundY: CGFloat) {
        let buildings: [(CGFloat, CGFloat, CGFloat)] = [
            (4, 30, 18), (44, 24, 26), (78, 34, 14), (122, 28, 22), (158, 26, 16)
        ]
        var base: CGFloat = 0
        while base < stripWidth {
            for (index, building) in buildings.enumerated() {
                let dark = index % 2 == 0
                    ? NSColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1)
                    : NSColor(red: 0.05, green: 0.07, blue: 0.16, alpha: 1)
                px(base + building.0, groundY - building.2, building.1, building.2, dark)
            }
            base += period
        }
    }

    private func cityNearTile(period: CGFloat, stripWidth: CGFloat, groundY: CGFloat) {
        let buildings: [(CGFloat, CGFloat, CGFloat)] = [
            (10, 34, 12), (60, 28, 17), (104, 38, 10), (158, 30, 15), (200, 24, 12)
        ]
        var base: CGFloat = 0
        while base < stripWidth {
            for (index, building) in buildings.enumerated() {
                let x = base + building.0
                let width = building.1
                let height = building.2
                let dark = index % 2 == 0
                    ? NSColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1)
                    : NSColor(red: 0.06, green: 0.08, blue: 0.19, alpha: 1)
                px(x, groundY - height, width, height, dark)

                let windowColor = index % 2 == 0
                    ? NSColor(red: 1.0, green: 0.84, blue: 0.36, alpha: 0.9)
                    : NSColor(red: 0.24, green: 0.85, blue: 1.0, alpha: 0.85)
                var windowY = groundY - height + 3
                while windowY < groundY - 3 {
                    var windowX = x + 2
                    while windowX < x + width - 2 {
                        if Int(windowX + windowY) % 3 != 0 {
                            px(windowX, windowY, 1.5, 1.5, windowColor.withAlphaComponent(0.75))
                        }
                        windowX += 4
                    }
                    windowY += 4
                }
            }
            base += period
        }
    }

    // MARK: - Static sky (never scrolls)

    private func drawMidnightForest() {
        let groundY = groundTop
        drawSkyBands([
            NSColor(red: 0.024, green: 0.05, blue: 0.12, alpha: 1),
            NSColor(red: 0.03, green: 0.07, blue: 0.15, alpha: 1),
            NSColor(red: 0.04, green: 0.10, blue: 0.19, alpha: 1),
            NSColor(red: 0.05, green: 0.13, blue: 0.22, alpha: 1)
        ], groundY: groundY)

        // stars
        let starPositions: [(CGFloat, CGFloat)] = [
            (0.06, 0.10), (0.16, 0.28), (0.28, 0.08), (0.38, 0.22),
            (0.50, 0.12), (0.60, 0.30), (0.74, 0.26), (0.88, 0.10), (0.95, 0.30)
        ]
        for (index, position) in starPositions.enumerated() {
            let alpha: CGFloat = index % 3 == 0 ? 0.85 : 0.5
            px(position.0 * bounds.width, position.1 * groundY, 1.5, 1.5, NSColor.white.withAlphaComponent(alpha))
        }

        // moon
        px(bounds.width * 0.66, 5, 7, 7, NSColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 0.9))
        px(bounds.width * 0.66 + 2, 7, 3, 2, NSColor(red: 0.70, green: 0.78, blue: 0.92, alpha: 0.9))

        drawGround(
            base: NSColor(red: 0.04, green: 0.10, blue: 0.08, alpha: 1),
            edge: NSColor(red: 0.10, green: 0.28, blue: 0.20, alpha: 1)
        )
    }

    private func drawCrystalCave() {
        let groundY = groundTop
        drawSkyBands([
            NSColor(red: 0.07, green: 0.04, blue: 0.12, alpha: 1),
            NSColor(red: 0.09, green: 0.05, blue: 0.15, alpha: 1),
            NSColor(red: 0.11, green: 0.06, blue: 0.19, alpha: 1),
            NSColor(red: 0.14, green: 0.08, blue: 0.23, alpha: 1)
        ], groundY: groundY)

        drawGround(
            base: NSColor(red: 0.08, green: 0.05, blue: 0.13, alpha: 1),
            edge: NSColor(red: 0.20, green: 0.12, blue: 0.32, alpha: 1)
        )
    }

    private func drawSunsetDunes() {
        let groundY = groundTop
        drawSkyBands([
            NSColor(red: 0.17, green: 0.06, blue: 0.19, alpha: 1),
            NSColor(red: 0.29, green: 0.10, blue: 0.24, alpha: 1),
            NSColor(red: 0.48, green: 0.18, blue: 0.24, alpha: 1),
            NSColor(red: 0.72, green: 0.33, blue: 0.20, alpha: 1)
        ], groundY: groundY)

        // low sun
        px(bounds.width * 0.48 - 5, groundY - 15, 11, 11, NSColor(red: 1.0, green: 0.72, blue: 0.30, alpha: 0.95))
        px(bounds.width * 0.48 - 3, groundY - 13, 3, 3, NSColor(red: 1.0, green: 0.86, blue: 0.52, alpha: 0.95))

        drawGround(
            base: NSColor(red: 0.30, green: 0.16, blue: 0.10, alpha: 1),
            edge: NSColor(red: 0.66, green: 0.42, blue: 0.22, alpha: 1)
        )
    }

    private func drawNeonCity() {
        let groundY = groundTop
        drawSkyBands([
            NSColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1),
            NSColor(red: 0.03, green: 0.04, blue: 0.09, alpha: 1),
            NSColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1),
            NSColor(red: 0.05, green: 0.08, blue: 0.19, alpha: 1)
        ], groundY: groundY)

        drawGround(
            base: NSColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1),
            edge: NSColor(red: 0.10, green: 0.20, blue: 0.36, alpha: 1)
        )
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

    var isBoss: Bool = false {
        didSet { needsDisplay = true }
    }

    var isDefeated: Bool = false {
        didSet {
            setTokenActivity(false)
            needsDisplay = true
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
        if walking {
            if !isTokenActivityAnimating {
                startWalkAnimation()
            }
        } else {
            layer?.removeAnimation(forKey: "walkBob")
        }
    }

    func setTokenActivity(_ active: Bool) {
        guard isTokenActivityAnimating != active else {
            return
        }

        isTokenActivityAnimating = active
        if active {
            layer?.removeAnimation(forKey: "walkBob")
            startTokenActivityAnimation()
        } else {
            layer?.removeAnimation(forKey: "tokenActivityBob")
            layer?.removeAnimation(forKey: "tokenActivityPulse")
            if isWalking {
                startWalkAnimation()
            }
        }
    }

    func playAttackTell(direction: CGFloat, reach: CGFloat = 7) {
        guard !isDefeated, let layer else { return }

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
        let x = (bounds.width - unit * 16) / 2
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
        let x = (bounds.width - unit * 16) / 2
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
        let bossScale: CGFloat = isBoss ? 1.22 : 1
        let unit = min(bounds.width, bounds.height) / 16 * bossScale
        let x = (bounds.width - unit * 16) / 2
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

        if isBoss {
            drawBossCrown(unit: unit, x: x, y: y)
        }
    }

    private func drawBossCrown(unit: CGFloat, x: CGFloat, y: CGFloat) {
        let gold = NSColor(red: 1.0, green: 0.80, blue: 0.24, alpha: 1)
        drawRect(x: x + unit * 5, y: y + unit * 1.2, w: unit * 6, h: unit * 1.2, color: gold)
        drawRect(x: x + unit * 5, y: y + unit * 0.2, w: unit, h: unit, color: gold)
        drawRect(x: x + unit * 7.5, y: y + unit * 0.2, w: unit, h: unit, color: gold)
        drawRect(x: x + unit * 10, y: y + unit * 0.2, w: unit, h: unit, color: gold)
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

struct MonsterEncounter: Equatable {
    let kind: MonsterKind
    let stage: Int
    let isBoss: Bool

    var maxHP: Int {
        StageProgress.maxHP(stage: stage, monster: kind, isBoss: isBoss)
    }
}

// Represents a single monster instance in the world queue.
private struct MonsterInstance {
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
private final class EffectOverlayView: NSView {
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

private struct HeroAttackRequest {
    let damageText: String?
    let isCrit: Bool
    let onImpact: () -> Void
}

final class BattleSceneView: NSView {
    /// Every CALayer effect is hosted here rather than on the scene's own layer.
    /// AppKit keeps subview backing layers at the end of the sublayer array, so
    /// anything added with `layer?.addSublayer` ends up *below* the opaque
    /// backdrop subview - which is why no slash, projectile or impact was ever
    /// visible. This overlay is the last subview, so effects land on top.
    private let effectsHost = EffectOverlayView()
    private var effectsLayer: CALayer? { effectsHost.layer }
    private let heroView = PixelActorView(kind: .hero)
    private let monsterView = PixelActorView(kind: .monster)
    private let backdropView = BackdropView()
    // Monster queue: multiple monsters waiting to fight, fought in order
    private var monsterQueue: [MonsterInstance] = []
    // Current monster index in the queue (-1 if none)
    private var currentMonsterIndex: Int = -1
    // Hero's position in world coordinates (advances as the world scrolls).
    private var heroWorldX: CGFloat = 0
    private let flashLayer = CALayer()
    private let monsterHitFlashLayer = CALayer()
    // The flash that lands on the hero is reused for every wolf-claw hit.
    private let heroImpactLayer = CAShapeLayer()
    private let floatingTextLabels = (0..<6).map { _ in NSTextField(labelWithString: "") }
    private let monsterOverheadHPBar = PixelBarView()
    private var floatingTextIndex = 0

    private var displayLink: CADisplayLink?
    private var backgroundSimulationTimer: Timer?
    private var lastUpdateTime: CFTimeInterval = 0

    var rendersCombatEffects = false {
        didSet {
            guard rendersCombatEffects != oldValue else {
                return
            }
            updateWorldMotion()
            if rendersCombatEffects {
                stopBackgroundSimulation()
                startGameLoop()
            } else {
                heroAttackQueue.removeAll()
                stopGameLoop()
                startBackgroundSimulation()
            }
        }
    }

    // When true the monster is within attack range: the world stops scrolling,
    // hero stands to fight, HP bar is visible, and attacks can be triggered.
    // When false the world scrolls and hero walks toward the monster.
    private(set) var monsterEngaged = false
    private(set) var worldIsMoving = false
    var onWorldMotionChanged: ((Bool) -> Void)?
    var onMonsterEngaged: (() -> Void)?
    private var isAttackInProgress = false
    private var currentMonsterDefeated = false
    private var heroAttackQueue: [HeroAttackRequest] = []
    private var approachWorkItem: DispatchWorkItem?

    private static let heroImpactDelay: TimeInterval = 0
    private static let heroAttackDuration: TimeInterval = 0.40
    private static let monsterImpactDelay: TimeInterval = 0

    // Attack range: monster must be within this distance from hero to engage
    // This is measured from hero's right edge to monster's left edge
    private let attackRange: CGFloat = 30

    private func updateWorldMotion() {
        let moving = currentMonster != nil && !monsterEngaged && !heroDefeated
        if moving != worldIsMoving {
            worldIsMoving = moving
            onWorldMotionChanged?(moving)
        }
        backdropView.scrollingEnabled = rendersCombatEffects && moving
        heroView.setWalking(rendersCombatEffects && moving)
    }

    // The current target monster
    private var currentMonster: MonsterInstance? {
        guard currentMonsterIndex >= 0, currentMonsterIndex < monsterQueue.count else { return nil }
        return monsterQueue[currentMonsterIndex]
    }

    // The monster's on-screen frame, honoring an in-flight approach animation.
    private var monsterVisualFrame: CGRect {
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
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            stopGameLoop()
            stopBackgroundSimulation()
            backdropView.scrollingEnabled = false
            heroView.setWalking(false)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        lastUpdateTime = CACurrentMediaTime()
        if rendersCombatEffects {
            startGameLoop()
        } else {
            startBackgroundSimulation()
        }
        updateWorldMotion()
    }

    private var actorSize: CGFloat {
        max(0, min(bounds.height - 14, 46))
    }

    // Fight position is derived from bounds, not from heroView.frame, so it is
    // valid even before the scene has been laid out (e.g. a monster respawns
    // while the HUD is collapsed).
    private var monsterFightX: CGFloat {
        max(16, bounds.width * 0.3) + actorSize + 22
    }

    override func layout() {
        super.layout()

        backdropView.frame = bounds
        // Same coordinate space as the scene, so effect paths built from actor
        // frames need no conversion.
        effectsHost.frame = bounds
        let actorSize = actorSize
        heroView.frame = NSRect(
            x: max(16, bounds.width * 0.3),
            y: bounds.height - actorSize - 5,
            width: actorSize,
            height: actorSize
        )

        // Only set initial monster position if not yet positioned
        // Position is managed by updateMonsterPosition() during world scrolling
        if monsterView.frame.isEmpty {
            monsterView.frame = NSRect(x: monsterFightX, y: bounds.height - actorSize - 5, width: actorSize, height: actorSize)
        }
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
    private func setupCurrentMonster() {
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
    private func updateMonsterPosition() {
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
        let screenX = monsterFightX + remainingDistance

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

        // Attack range check: calculate distance from hero's attack point to monster's edge
        // Use hero's attack point (slightly in front of hero) for more intuitive range
        let heroAttackPointX = heroView.frame.maxX
        let monsterEdgeX = monsterView.frame.minX
        let distanceToHero = abs(monsterEdgeX - heroAttackPointX)

        if !currentMonsterDefeated, distanceToHero <= attackRange {
            // Monster is within attack range - engage!
            if !monsterEngaged {
                monsterEngaged = true
                updateWorldMotion()
                onMonsterEngaged?()
                if rendersCombatEffects {
                    playMonsterArrivalEffects()
                }
            }
        } else {
            // Monster is out of attack range - only disengage if not currently attacking
            // This prevents disengaging mid-attack which causes "effect but no damage" issues
            if monsterEngaged && !isAttackInProgress {
                monsterEngaged = false
                updateWorldMotion()
            }
        }

        // Show HP bar only when engaged (within attack range)
        monsterOverheadHPBar.isHidden = !monsterEngaged || currentMonsterDefeated

        // Update HP bar position
        let barFrame = NSRect(
            x: monsterView.frame.minX,
            y: max(2, monsterView.frame.minY - 7),
            width: monsterView.frame.width,
            height: 3
        )
        monsterOverheadHPBar.frame = barFrame
        monsterOverheadHPBar.value = monster.healthFraction
    }

    // Play effects when monster arrives at fight position
    private func playMonsterArrivalEffects() {
        guard let monster = currentMonster else { return }

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

    private func startGameLoop() {
        guard displayLink == nil else { return }
        displayLink = displayLink(target: self, selector: #selector(gameLoopTick))
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }

    private func stopGameLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func startBackgroundSimulation() {
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

    private func stopBackgroundSimulation() {
        backgroundSimulationTimer?.invalidate()
        backgroundSimulationTimer = nil
    }

    @objc private func gameLoopTick() {
        advanceGameClock()
    }

    private func advanceGameClock() {
        let now = CACurrentMediaTime()
        let dt = min(max(0, now - lastUpdateTime), 0.25)
        lastUpdateTime = now
        updateWorld(dt: dt)
    }

    // Called each frame/tick to update world scrolling and monster positions
    func updateWorld(dt: TimeInterval) {
        // Rendering can be paused while the compact HUD is visible, but world
        // progress and engagement remain part of the game simulation.
        let moving = currentMonster != nil && !monsterEngaged && !heroDefeated
        if moving {
            let delta = BackdropView.groundScrollSpeed * CGFloat(dt)
            heroWorldX += delta
            updateMonsterPosition()
        }
    }

    func playLootDrop(_ drop: LootDrop) {
        guard rendersCombatEffects else {
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

        let label = floatingTextLabels[floatingTextIndex]
        floatingTextIndex = (floatingTextIndex + 1) % floatingTextLabels.count
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
        let rise: CGFloat = style == .crit ? 20 : style == .banner ? 12 : 15
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
        let jitter: CGFloat = style == .banner ? 0 : CGFloat.random(in: -3...3)
        let startFrame = NSRect(
            x: max(2, min(bounds.width - width - 2, originX)),
            // Keep the whole rise inside the scene, or it fades out clipped.
            y: max(1, min(bounds.height - height - rise - 1, originY + jitter)),
            width: width,
            height: height
        )
        label.frame = startFrame
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
        isCrit: Bool = false,
        onImpact: @escaping () -> Void
    ) -> Bool {
        guard !heroDefeated, rendersCombatEffects, monsterEngaged else {
            return false
        }

        enqueueHeroAttack(HeroAttackRequest(damageText: damageText, isCrit: isCrit, onImpact: onImpact))
        return true
    }

    private func enqueueHeroAttack(_ request: HeroAttackRequest) {
        heroAttackQueue.append(request)
        playNextHeroAttackIfNeeded()
    }

    private func playNextHeroAttackIfNeeded() {
        guard !isAttackInProgress else {
            return
        }
        guard !heroDefeated, rendersCombatEffects, monsterEngaged else {
            heroAttackQueue.removeAll()
            return
        }
        guard !heroAttackQueue.isEmpty else {
            return
        }

        let request = heroAttackQueue.removeFirst()
        isAttackInProgress = true
        playShockwave(isCrit: request.isCrit) { [weak self] in
            guard let self else {
                return
            }
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
            request.onImpact()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.heroAttackDuration) { [weak self] in
            guard let self else {
                return
            }
            self.isAttackInProgress = false
            self.playNextHeroAttackIfNeeded()
        }
    }
    
    // MARK: - Energy Laser Attack Effect
    
    private let laserCoreLayer = CAShapeLayer()
    private let laserGlowLayer = CAShapeLayer()
    private let laserFlickerLayers = (0..<4).map { _ in CAShapeLayer() }
    private let impactBurstLayer = CAShapeLayer()
    
    private func playShockwave(isCrit: Bool, onImpact: @escaping () -> Void) {
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
        laserGlowLayer.removeAllAnimations()
        laserGlowLayer.path = laserPath
        laserGlowLayer.strokeColor = NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.4).cgColor
        laserGlowLayer.lineWidth = isCrit ? 12 : 8
        laserGlowLayer.lineCap = .round
        laserGlowLayer.shadowColor = NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0).cgColor
        laserGlowLayer.shadowRadius = 10
        laserGlowLayer.shadowOpacity = 0.7
        laserGlowLayer.opacity = 0
        
        if laserGlowLayer.superlayer == nil {
            effectsLayer?.addSublayer(laserGlowLayer)
        }
        
        // 2. Core beam (bright white-blue)
        laserCoreLayer.removeAllAnimations()
        laserCoreLayer.path = laserPath
        laserCoreLayer.strokeColor = NSColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.95).cgColor
        laserCoreLayer.lineWidth = isCrit ? 4 : 3
        laserCoreLayer.lineCap = .round
        laserCoreLayer.shadowColor = NSColor.white.cgColor
        laserCoreLayer.shadowRadius = 4
        laserCoreLayer.shadowOpacity = 0.9
        laserCoreLayer.opacity = 0
        
        if laserCoreLayer.superlayer == nil {
            effectsLayer?.addSublayer(laserCoreLayer)
        }
        
        // Flash animation for main laser
        let laserFlash = CAKeyframeAnimation(keyPath: "opacity")
        laserFlash.values = [0, 1, 1, 0]
        laserFlash.keyTimes = [0, 0.1, 0.6, 1]
        laserFlash.duration = 0.2
        
        let glowFlash = CAKeyframeAnimation(keyPath: "opacity")
        glowFlash.values = [0, 0.8, 0.8, 0]
        glowFlash.keyTimes = [0, 0.1, 0.6, 1]
        glowFlash.duration = 0.22
        
        laserCoreLayer.add(laserFlash, forKey: "flash")
        laserGlowLayer.add(glowFlash, forKey: "flash")
        
        // 3. Energy flickers (short arcs along the beam)
        for (index, flicker) in laserFlickerLayers.enumerated() {
            let t = CGFloat(index + 1) / CGFloat(laserFlickerLayers.count + 1)
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
            
            if flicker.superlayer == nil {
                effectsLayer?.addSublayer(flicker)
            }
            
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
        
        impactBurstLayer.removeAllAnimations()
        impactBurstLayer.path = burstPath
        impactBurstLayer.position = monsterPos
        impactBurstLayer.strokeColor = NSColor(red: 0.8, green: 0.95, blue: 1.0, alpha: 0.9).cgColor
        impactBurstLayer.fillColor = nil
        impactBurstLayer.lineWidth = 2
        impactBurstLayer.lineCap = .round
        impactBurstLayer.shadowColor = NSColor(red: 0.5, green: 0.85, blue: 1.0, alpha: 1.0).cgColor
        impactBurstLayer.shadowRadius = 8
        impactBurstLayer.shadowOpacity = 0.9
        impactBurstLayer.opacity = 0
        
        if impactBurstLayer.superlayer == nil {
            effectsLayer?.addSublayer(impactBurstLayer)
        }
        
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
        
        impactBurstLayer.add(burstFlash, forKey: "flash")
        impactBurstLayer.add(burstScale, forKey: "scale")
        
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

        onImpact()
    }

    @discardableResult
    func playMonsterAttack(damage: CGFloat, onImpact: @escaping () -> Void) -> Bool {
        guard rendersCombatEffects, monsterEngaged else {
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
        onImpact()
        return true
    }

    // Wolf claw scratch layers
    private let clawGlowLayers = (0..<3).map { _ in CAShapeLayer() }
    private let clawCoreLayers = (0..<3).map { _ in CAShapeLayer() }
    private let clawSparkLayers = (0..<6).map { _ in CAShapeLayer() }
    
    private func playWolfClawAttack() {
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
            let glow = clawGlowLayers[index]
            glow.removeAllAnimations()
            glow.path = clawPath
            glow.strokeColor = clawColor.withAlphaComponent(0.5).cgColor
            glow.lineWidth = 8 - CGFloat(index)
            glow.lineCap = .round
            glow.shadowColor = clawColor.cgColor
            glow.shadowRadius = 8
            glow.shadowOpacity = 0.8
            glow.opacity = 0
            
            if glow.superlayer == nil {
                effectsLayer?.addSublayer(glow)
            }
            
            // Core layer (inner, bright)
            let core = clawCoreLayers[index]
            core.removeAllAnimations()
            core.path = clawPath
            core.strokeColor = NSColor.white.withAlphaComponent(0.9).cgColor
            core.lineWidth = 3 - CGFloat(index) * 0.5
            core.lineCap = .round
            core.shadowColor = clawColor.cgColor
            core.shadowRadius = 4
            core.shadowOpacity = 0.9
            core.opacity = 0
            
            if core.superlayer == nil {
                effectsLayer?.addSublayer(core)
            }
            
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
        for (index, spark) in clawSparkLayers.enumerated() {
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
            
            if spark.superlayer == nil {
                effectsLayer?.addSublayer(spark)
            }
            
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

    private func setup() {
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

    /// Put a reused effect layer exactly where the hit happened. A bare CALayer
    /// animates its own geometry implicitly, so without this the layer spends a
    /// quarter second gliding over from the last hit while the explicit
    /// animation it was moved for is already playing somewhere else.
    private func placeEffect(_ layer: CALayer, at point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position = point
        CATransaction.commit()
    }

    private func placeEffect(_ layer: CALayer, frame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = frame
        CATransaction.commit()
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

    private func lootPath(for drop: LootDrop, in rect: CGRect) -> CGPath {
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

    private func equipmentPath(for slot: EquipmentSlot, in rect: CGRect) -> CGPath {
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

}

private struct HeroPalette {
    let skin: NSColor
    let hair: NSColor
    let shirt: NSColor
    let sleeve: NSColor
    let pants: NSColor
}

private extension HeroRole {
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
