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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        trackLayer.backgroundColor = trackColor.cgColor
        ghostLayer.backgroundColor = ghostFillColor().cgColor
        fillLayer.backgroundColor = fillColor.cgColor

        for barLayer in [trackLayer, ghostLayer, fillLayer] {
            barLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
            layer?.addSublayer(barLayer)
        }
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
        fillLayer.transform = CATransform3DMakeScale(value, 1, 1)
        ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
        CATransaction.commit()
    }

    private func updateFillLayers(oldValue: CGFloat) {
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
        drain.fromValue = oldValue
        drain.toValue = value
        drain.beginTime = CACurrentMediaTime() + 0.25
        drain.duration = 0.4
        drain.timingFunction = CAMediaTimingFunction(name: .easeOut)
        drain.fillMode = .backwards
        drain.isRemovedOnCompletion = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
        CATransaction.commit()
        ghostLayer.add(drain, forKey: "ghostDrain")
        updateWarningPulse()
    }

    private func ghostFillColor() -> NSColor {
        guard let blended = fillColor.blended(withFraction: 0.5, of: .white) else {
            return fillColor.withAlphaComponent(0.55)
        }
        return blended.withAlphaComponent(0.55)
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

    private static let defaultsKey = "NotchHero.backdrop"

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
        let speed: Float = scrollingEnabled ? 1 : 0
        scrollLayers.forEach { $0.speed = speed }
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
        let bossScale: CGFloat = isBoss ? 1.22 : 1
        let unit = min(bounds.width, bounds.height) / 16 * bossScale
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

// Represents a single monster instance in the world queue
private struct MonsterInstance {
    let id = UUID()
    let kind: MonsterKind
    let isBoss: Bool
    let maxHP: CGFloat
    var currentHP: CGFloat
    var worldX: CGFloat  // Fixed position in the scrolling world
    
    init(kind: MonsterKind, isBoss: Bool, maxHP: Int, worldX: CGFloat) {
        self.kind = kind
        self.isBoss = isBoss
        self.maxHP = CGFloat(maxHP)
        self.currentHP = self.maxHP
        self.worldX = worldX
    }
    
    var healthFraction: CGFloat {
        currentHP / maxHP
    }
}

final class BattleSceneView: NSView {
    private let heroView = PixelActorView(kind: .hero)
    private let monsterView = PixelActorView(kind: .monster)
    private let backdropView = BackdropView()
    // Monster queue: multiple monsters waiting to fight, fought in order
    private var monsterQueue: [MonsterInstance] = []
    // Current monster index in the queue (-1 if none)
    private var currentMonsterIndex: Int = -1
    // World scroll offset (increases as we move right)
    private var worldOffset: CGFloat = 0
    // Hero's position in world coordinates (advances as we move right)
    private var heroWorldX: CGFloat = 0
    private let slashLayer = CAShapeLayer()
    private let projectileLayer = CAShapeLayer()
    private let impactLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()
    private let novaLayer = CAShapeLayer()
    private let flashLayer = CALayer()
    private let monsterHitFlashLayer = CALayer()
    private let pooledProjectileLayers = (0..<8).map { _ in CAShapeLayer() }
    private let pooledImpactLayers = (0..<4).map { _ in CAShapeLayer() }
    private let floatingTextLabels = (0..<6).map { _ in NSTextField(labelWithString: "") }
    private let monsterOverheadHPBar = PixelBarView()
    private let groundLayer = CALayer()
    private var tokenAttackTimer: Timer?
    private var lastRingEffectAt: CFTimeInterval = 0
    private var projectilePoolIndex = 0
    private var impactPoolIndex = 0
    private var floatingTextIndex = 0
    private var effectGeneration = 0
    private var layerGenerations: [ObjectIdentifier: Int] = [:]
    var onSustainedHit: ((CGFloat) -> Void)?

    var rendersCombatEffects = false {
        didSet {
            guard rendersCombatEffects != oldValue else {
                return
            }
            updateWorldMotion()
        }
    }

    // When true the monster is standing at its fight position: the world stops
    // scrolling and the hero stands to fight. When false the world scrolls and
    // the hero walks toward the next monster, which stands at a fixed spot in
    // the world and slides into view with the ground.
    private var monsterEngaged = true
    private var approachWorkItem: DispatchWorkItem?

    private func updateWorldMotion() {
        let moving = rendersCombatEffects && !monsterEngaged && !heroDefeated
        backdropView.scrollingEnabled = moving
        heroView.setWalking(moving)
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

    // 0...3, derived from the latest token burst size. Drives burst strike
    // counts, projectile sizes, and sustained-fire density.
    var attackIntensity: Int = 0 {
        didSet {
            let clamped = min(max(attackIntensity, 0), 3)
            if clamped != attackIntensity {
                attackIntensity = clamped
                return
            }
            if clamped != oldValue, tokenActivity {
                stopSustainedTokenAttack()
                startSustainedTokenAttack()
            }
        }
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
            groundLayer.backgroundColor = backdrop.accentColor
        }
    }

    // Monster health fraction (0...1) of the current target
    var monsterHealth: CGFloat {
        get { currentMonster?.healthFraction ?? 1 }
        set {
            guard currentMonsterIndex >= 0, currentMonsterIndex < monsterQueue.count else { return }
            let clampedHealth = min(max(newValue, 0), 1)
            monsterQueue[currentMonsterIndex].currentHP = clampedHealth * monsterQueue[currentMonsterIndex].maxHP
            monsterOverheadHPBar.value = clampedHealth
            if newValue < monsterHealth, rendersCombatEffects {
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
            updateWorldMotion()
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
            backdropView.scrollingEnabled = false
            heroView.setWalking(false)
        }
    }

    private var actorSize: CGFloat {
        min(bounds.height - 14, 46)
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
        groundLayer.frame = NSRect(x: 12, y: bounds.height - 8, width: bounds.width - 24, height: 2)
        
        // Update HP bar position based on current monster view position
        updateMonsterPosition()
    }

    func playMonsterDeath() {
        approachWorkItem?.cancel()
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

    // Generate a batch of monsters with fixed world positions
    func spawnMonsterBatch(kind: MonsterKind, isBoss: Bool, stage: Int) {
        approachWorkItem?.cancel()
        monsterQueue.removeAll()
        // Note: worldOffset and heroWorldX are NOT reset - they continue advancing
        // This ensures hero's world position is always increasing
        
        // Generate more monsters per batch for higher density
        let count = isBoss ? 1 : Int.random(in: 5...8)
        let baseMaxHP = StageProgress.maxHP(stage: stage, monster: kind, isBoss: isBoss)
        
        // Space monsters closer together: each monster is ~120-180 units apart
        // This means monsters appear frequently as the hero walks
        var lastX = monsterFightX - 80 // Start first monster closer to hero
        for i in 0..<count {
            let spacing = CGFloat.random(in: 120...180)
            lastX += spacing
            var monster = MonsterInstance(
                kind: kind,
                isBoss: isBoss && i == 0, // Only first monster is boss in boss stages
                maxHP: baseMaxHP,
                worldX: lastX
            )
            monsterQueue.append(monster)
        }
        
        // Start with first monster
        currentMonsterIndex = 0
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
        
        monsterView.layer?.removeAllAnimations()
        monsterView.alphaValue = 1
        monsterView.needsDisplay = true
        monsterView.monsterKind = monster.kind
        monsterView.isBoss = monster.isBoss
        monsterOverheadHPBar.fillColor = monster.kind.hpColor
        monsterEngaged = false
        
        // Position monster based on its worldX relative to current worldOffset
        updateMonsterPosition()
        updateWorldMotion()
    }
    
    // Update monster view position based on world scrolling
    private func updateMonsterPosition() {
        guard let monster = currentMonster else { return }
        
        let fightFrame = NSRect(
            x: monsterFightX,
            y: monsterView.frame.minY,
            width: monsterView.frame.width,
            height: monsterView.frame.height
        )
        
        // Monster's screen X = worldX - worldOffset
        let screenX = monster.worldX - worldOffset
        
        if screenX <= monsterFightX {
            // Monster has reached fight position
            monsterView.frame = fightFrame
            if !monsterEngaged {
                monsterEngaged = true
                updateWorldMotion()
                playMonsterArrivalEffects()
            }
        } else {
            // Monster is still approaching from the right
            monsterView.frame = NSRect(
                x: screenX,
                y: fightFrame.minY,
                width: fightFrame.width,
                height: fightFrame.height
            )
            monsterEngaged = false
            updateWorldMotion()
        }
        
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
    
    // Check if there are more monsters in the current batch
    func hasNextMonsterInBatch() -> Bool {
        return currentMonsterIndex + 1 < monsterQueue.count
    }
    
    // Move to next monster in queue after defeating current
    func advanceToNextMonster() {
        currentMonsterIndex += 1
        
        if currentMonsterIndex >= monsterQueue.count {
            // All monsters in batch defeated
            monsterView.alphaValue = 0
            monsterEngaged = false
            updateWorldMotion()
        } else {
            // Setup next monster
            setupCurrentMonster()
        }
    }
    
    // Called each frame/tick to update world scrolling and monster positions
    func updateWorld(dt: TimeInterval) {
        guard rendersCombatEffects else { return }
        
        // If not engaged and hero is walking, scroll the world
        let moving = rendersCombatEffects && !monsterEngaged && !heroDefeated
        if moving {
            let delta = BackdropView.groundScrollSpeed * CGFloat(dt)
            worldOffset += delta
            heroWorldX += delta  // Hero advances in world coordinates
            updateMonsterPosition()
        }
    }
    
    // Legacy method for compatibility - spawns a single monster batch
    func playMonsterRespawn() {
        // This is now handled by spawnMonsterBatch called from NotchContentView
        setupCurrentMonster()
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
        layer?.addSublayer(itemLayer)

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

        label.stringValue = text
        label.textColor = color
        label.font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)

        let width: CGFloat = style == .banner ? 220 : 130
        let height: CGFloat = fontSize + 6
        let centerX: CGFloat
        let baseY: CGFloat
        switch anchor {
        case .monster:
            centerX = monsterVisualFrame.midX
            baseY = monsterVisualFrame.midY - height / 2
        case .hero:
            centerX = heroView.frame.midX
            baseY = heroView.frame.midY - height / 2
        case .center:
            centerX = bounds.midX
            baseY = bounds.midY - height / 2
        }
        let jitter: CGFloat = style == .banner ? 0 : CGFloat.random(in: -8...8)
        let startFrame = NSRect(
            x: max(2, min(bounds.width - width - 2, centerX - width / 2 + jitter)),
            y: baseY,
            width: width,
            height: height
        )
        label.frame = startFrame
        label.alphaValue = 1

        // Pop in from an oversize scale so hits feel punchy.
        let popScale: CGFloat = style == .crit ? 1.7 : style == .banner ? 1.0 : 1.35
        if popScale > 1, let textLayer = label.layer {
            textLayer.transform = CATransform3DMakeScale(popScale, popScale, 1)
            let pop = CABasicAnimation(keyPath: "transform")
            pop.fromValue = CATransform3DMakeScale(popScale, popScale, 1)
            pop.toValue = CATransform3DIdentity
            pop.duration = 0.16
            pop.timingFunction = CAMediaTimingFunction(name: .easeOut)
            textLayer.transform = CATransform3DIdentity
            textLayer.add(pop, forKey: "floatingTextPop")
        }

        let rise: CGFloat = style == .crit ? 20 : style == .banner ? 12 : 15
        let duration: Double = style == .crit ? 0.95 : style == .banner ? 1.15 : 0.7
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            label.animator().alphaValue = 0
            label.animator().frame = startFrame.offsetBy(dx: 0, dy: rise)
        }
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
            layer?.addSublayer(shard)

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

    private func playHitSparks(color: NSColor, intense: Bool) {
        let center = CGPoint(x: monsterVisualFrame.midX - 4, y: monsterVisualFrame.midY - 3)
        let sparkCount = intense ? 5 : 3
        for index in 0..<sparkCount {
            let spark = CALayer()
            spark.backgroundColor = (index % 2 == 0 ? NSColor.white : color).cgColor
            spark.shadowColor = color.cgColor
            spark.shadowOpacity = 0.3
            spark.shadowRadius = 1.5
            spark.frame = NSRect(x: 0, y: 0, width: intense ? 6 : 4, height: 2)
            spark.position = center
            layer?.addSublayer(spark)

            let angle = (CGFloat(index) / CGFloat(sparkCount) + 0.12) * CGFloat.pi * 2
            let distance = intense ? CGFloat.random(in: 12...20) : CGFloat.random(in: 8...14)
            let end = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)

            let fly = CABasicAnimation(keyPath: "position")
            fly.fromValue = center
            fly.toValue = end
            fly.duration = 0.2
            fly.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
            rotate.fromValue = angle
            rotate.toValue = angle + 0.5
            rotate.duration = 0.2

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.22
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false

            spark.add(fly, forKey: "hitSparkFly")
            spark.add(rotate, forKey: "hitSparkRotate")
            spark.add(fade, forKey: "hitSparkFade")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                spark.removeFromSuperlayer()
            }
        }
    }

    func playAttack(damageText: String, isCrit: Bool = false, intensity: Int = 0) {
        guard !heroDefeated, rendersCombatEffects else {
            return
        }

        let attackColor = heroRole.attackColor
        let clampedIntensity = min(max(intensity, 0), 3)
        let effectTier = min(max(skillLoadout.effectTier + clampedIntensity * 2, 0), 14)
        heroView.poseOffset = 5
        monsterView.poseOffset = -3
        let heroFrame = heroView.frame
        var heroLungeFrame = heroFrame
        heroLungeFrame.origin.x += 5

        if isCrit {
            showFloatingText(
                "\(L10n.text(.critLabel)) -\(damageText)",
                color: NSColor(red: 1.0, green: 0.84, blue: 0.24, alpha: 1.0),
                fontSize: 14,
                anchor: .monster,
                style: .crit
            )
        } else {
            showFloatingText("-\(damageText)", color: attackColor, anchor: .monster)
        }

        playProjectile(color: attackColor, tier: effectTier)
        if clampedIntensity >= 1 {
            playVolley(color: attackColor, tier: effectTier, count: clampedIntensity + 2)
        }
        playImpact(color: attackColor, tier: effectTier)
        playBasicSlash(color: attackColor, tier: effectTier)
        playMonsterHitFlash()
        playHitSparks(color: attackColor, intense: isCrit || clampedIntensity >= 2)
        playFlash(color: attackColor.withAlphaComponent(
            min(0.5, (isCrit ? 0.30 : 0.14 + CGFloat(min(effectTier, 6)) * 0.015) + CGFloat(clampedIntensity) * 0.05)
        ))
        if isCrit {
            shake(layer: monsterView.layer, distance: 7 + CGFloat(clampedIntensity), duration: 0.3)
            shake(layer: layer, distance: 2.5, duration: 0.18)
        } else if clampedIntensity >= 2 {
            shake(layer: monsterView.layer, distance: 5.5, duration: 0.24)
        } else {
            shakeMonster()
        }

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
    }

    private func playBasicSlash(color: NSColor, tier: Int) {
        slashLayer.removeAllAnimations()
        slashLayer.path = basicSlashPath().cgPath
        slashLayer.strokeColor = color.withAlphaComponent(0.95).cgColor
        slashLayer.shadowColor = color.cgColor
        slashLayer.lineWidth = 3.5 + CGFloat(min(tier, 8)) * 0.4
        slashLayer.opacity = 1

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.14
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.2
        fade.beginTime = CACurrentMediaTime() + 0.1
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        slashLayer.add(stroke, forKey: "basicSlashStroke")
        slashLayer.add(fade, forKey: "basicSlashFade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            self.slashLayer.opacity = 0
            self.slashLayer.removeAllAnimations()
        }
    }

    private func playMonsterHitFlash() {
        monsterHitFlashLayer.frame = monsterVisualFrame.insetBy(dx: -2, dy: -2)
        monsterHitFlashLayer.removeAllAnimations()
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0.55, 0]
        flash.keyTimes = [0, 1]
        flash.duration = 0.14
        flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
        monsterHitFlashLayer.opacity = 0
        monsterHitFlashLayer.add(flash, forKey: "monsterHitWhiteFlash")
    }

    func playSkillCast(skill: HeroSkill, rank: Int, damage: Int, isCrit: Bool = false) {
        guard !heroDefeated, rendersCombatEffects else {
            return
        }

        let color = skillCastColor(for: skill)
        let tier = min(18, max(skillLoadout.effectTier + skill.treeTier + rank, skill.treeTier * 2))
        let projectileCount = min(6, max(3, skillLoadout.projectileCount + rank + skill.treeTier / 2))
        let arcCount = min(4, max(2, skillLoadout.arcCount + rank + skill.treeTier / 2))

        if isCrit {
            showFloatingText(
                "\(L10n.text(.critLabel)) -\(damage)",
                color: NSColor(red: 1.0, green: 0.84, blue: 0.24, alpha: 1.0),
                fontSize: 14,
                anchor: .monster,
                style: .crit
            )
        } else {
            showFloatingText("-\(damage)", color: color, anchor: .monster)
        }
        heroView.poseOffset = 7
        monsterView.poseOffset = -5
        playFlash(color: color.withAlphaComponent(0.26 + CGFloat(min(rank, 3)) * 0.04 + (isCrit ? 0.12 : 0)))
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
    }

    func playMonsterAttack(damage: Double) {
        guard rendersCombatEffects else {
            return
        }
        showFloatingText(
            L10n.string(.hpDamageDecimal, damage),
            color: NSColor(red: 1.0, green: 0.36, blue: 0.32, alpha: 1.0),
            anchor: .hero
        )
        heroView.poseOffset = -3
        monsterView.poseOffset = -5
        playFlash(color: NSColor(red: 1.0, green: 0.18, blue: 0.16, alpha: 0.20))
        playMonsterProjectile()
        shakeHero()

        // Skip the frame lunge while the monster is still sliding into view so
        // the approach animation is not stomped.
        guard monsterEngaged else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                self.heroView.poseOffset = 0
                self.monsterView.poseOffset = 0
            }
            return
        }

        let monsterFrame = monsterView.frame
        var monsterLungeFrame = monsterFrame
        monsterLungeFrame.origin.x -= 6

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

        let start = CGPoint(x: monsterVisualFrame.minX - 4, y: monsterVisualFrame.midY)
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

        addSubview(backdropView)

        groundLayer.backgroundColor = backdrop.accentColor
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

        monsterHitFlashLayer.backgroundColor = NSColor.white.cgColor
        monsterHitFlashLayer.cornerRadius = 6
        monsterHitFlashLayer.opacity = 0
        layer?.addSublayer(monsterHitFlashLayer)
    }

    private func basicSlashPath() -> NSBezierPath {
        let center = CGPoint(x: monsterVisualFrame.midX, y: monsterVisualFrame.midY)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - 16, y: center.y + 13))
        path.curve(
            to: NSPoint(x: center.x + 14, y: center.y - 11),
            controlPoint1: NSPoint(x: center.x - 5, y: center.y + 5),
            controlPoint2: NSPoint(x: center.x + 6, y: center.y - 6)
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
        let end = CGPoint(x: monsterVisualFrame.midX - 8, y: y)
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
            to: NSPoint(x: monsterVisualFrame.midX - 6, y: monsterVisualFrame.midY - 5),
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
        let center = CGPoint(x: monsterVisualFrame.midX - 5, y: monsterVisualFrame.midY - 5)
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
        let path = skillRiftPath(center: CGPoint(x: monsterVisualFrame.midX - 5, y: monsterVisualFrame.midY - 5), radius: 18 + CGFloat(min(tier, 8))).cgPath
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

        let interval = max(0.55, skillLoadout.sustainedInterval / (1 + 0.35 * Double(attackIntensity)))
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
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
        let tier = min(max(skillLoadout.effectTier + attackIntensity * 2, 0), 14)
        let count = min(4, skillLoadout.sustainedProjectileCount + attackIntensity)
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
        let end = CGPoint(x: monsterVisualFrame.midX - 9, y: y)
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
        impactLayer.path = impactPath(center: CGPoint(x: monsterVisualFrame.midX - 4, y: monsterVisualFrame.midY - 3)).cgPath

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
        arcLayer.path = arcBurstPath(center: CGPoint(x: monsterVisualFrame.midX - 6, y: monsterVisualFrame.midY - 4), count: count).cgPath

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
        let center = CGPoint(x: monsterVisualFrame.midX - 5, y: monsterVisualFrame.midY - 4)
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
        let center = CGPoint(x: monsterVisualFrame.midX - 5, y: monsterVisualFrame.midY - 5)
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
        let center = CGPoint(x: monsterVisualFrame.midX - 5, y: monsterVisualFrame.midY - 5)
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
