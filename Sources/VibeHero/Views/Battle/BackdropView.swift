import AppKit

/// Renders the current `BattleBackdrop`: a static sky painted directly, plus
/// parallax layers rendered once into tiled images and slid by Core Animation.
///
/// All art lives in `BackdropCatalog`; this view only knows how to paint a
/// `BackdropSpec`, so a new backdrop needs no change here.
final class BackdropView: NSView {
    /// Kept for callers that pace world motion against the ground layer.
    static var groundScrollSpeed: CGFloat { BackdropCatalog.groundScrollSpeed }

    var animationsEnabled = true {
        didSet {
            guard animationsEnabled != oldValue else { return }
            applyScrollingState()
        }
    }

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
        backdrop.spec.sky(skyCanvas)
    }

    private var groundTop: CGFloat {
        max(bounds.height - 10, bounds.height * 0.72)
    }

    private var skyCanvas: BackdropCanvas {
        BackdropCanvas(width: bounds.width, height: bounds.height, groundY: groundTop)
    }

    // MARK: - Scrolling world layers

    private func rebuildScrollingLayers() {
        scrollLayers.forEach { $0.removeFromSuperlayer() }
        scrollLayers = []
        lastTileSize = bounds.size

        let width = bounds.width
        let height = bounds.height
        guard width > 40, height > 24, let rootLayer = layer else {
            return
        }

        for spec in backdrop.spec.parallax {
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
            if animationsEnabled && scrollingEnabled {
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

        spec.painter(
            BackdropCanvas(width: width, height: height, groundY: groundTop, period: spec.period)
        )

        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }
}
