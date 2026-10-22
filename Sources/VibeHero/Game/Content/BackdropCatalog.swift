import AppKit

/// Drawing surface handed to a backdrop's painters, so backdrop art is data in
/// `BackdropCatalog` rather than methods on the view.
///
/// Everything is drawn in y-down point coordinates, matching the flipped space
/// `BackdropView` and the offscreen tile contexts both use.
struct BackdropCanvas {
    /// Sky painters get the view width; tile painters get the strip width.
    let width: CGFloat
    let height: CGFloat
    /// Top edge of the ground band. Silhouettes stand on this line.
    let groundY: CGFloat
    /// Tile painters repeat their motif every `period` points. Unused (0) for sky.
    let period: CGFloat

    init(width: CGFloat, height: CGFloat, groundY: CGFloat, period: CGFloat = 0) {
        self.width = width
        self.height = height
        self.groundY = groundY
        self.period = period
    }

    /// Snapped fill, so pixel-art edges stay crisp at fractional coordinates.
    func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
        color.setFill()
        NSBezierPath(rect: NSRect(x: round(x), y: round(y), width: ceil(w), height: ceil(h))).fill()
    }

    /// Horizontal gradient approximation: equal-height bands from the top edge
    /// down to the ground.
    func skyBands(_ colors: [NSColor]) {
        let bandHeight = groundY / CGFloat(colors.count)
        for (index, color) in colors.enumerated() {
            px(0, CGFloat(index) * bandHeight, width, bandHeight + 1, color)
        }
    }

    func ground(base: NSColor, edge: NSColor) {
        px(0, groundY, width, height - groundY, base)
        px(0, groundY, width, 1.5, edge)
    }

    /// Walks one motif across the whole strip, one placement per period.
    func repeating(_ body: (CGFloat) -> Void) {
        var base: CGFloat = 0
        while base < width {
            body(base)
            base += period
        }
    }
}

/// One parallax layer: how wide its motif is, how fast it slides, and how to
/// paint one period of it.
struct ScrollSpec {
    let period: CGFloat
    let speed: CGFloat
    let painter: (BackdropCanvas) -> Void
}

/// Everything that defines a battle backdrop.
///
/// This replaced four parallel `switch` statements (`name`, `accentColor`,
/// `BackdropView.draw`, `scrollSpecs`). Adding a backdrop is one `BackdropSpec`
/// plus its painters, with no view code to touch.
struct BackdropSpec {
    let nameKey: L10nKey
    let accentColor: CGColor
    /// Painted directly into the view; never scrolls.
    let sky: (BackdropCanvas) -> Void
    /// Back-to-front parallax layers, each rendered once into a tiled image.
    let parallax: [ScrollSpec]
}

enum BattleBackdrop: String, CaseIterable {
    case midnightForest
    case crystalCave
    case sunsetDunes
    case neonCity

    var spec: BackdropSpec { BackdropCatalog.spec(for: self) }

    var name: String { L10n.text(spec.nameKey) }

    var accentColor: CGColor { spec.accentColor }

    static func load() -> BattleBackdrop {
        guard let rawValue = Defaults.string(forKey: DefaultsKey.backdrop),
              let backdrop = BattleBackdrop(rawValue: rawValue) else {
            return .midnightForest
        }
        return backdrop
    }

    func save() {
        Defaults.set(rawValue, forKey: DefaultsKey.backdrop)
    }
}

enum BackdropCatalog {
    /// Ground-layer scroll speed in points/second. `BattleSceneView` advances
    /// world-anchored monsters at the same rate so they slide with the ground
    /// under them instead of drifting.
    static let groundScrollSpeed: CGFloat = 54

    /// `nonisolated(unsafe)` because the table is immutable and the `NSColor`s
    /// and painter closures in it are only ever read.
    nonisolated(unsafe) static let all: [BattleBackdrop: BackdropSpec] = [
        .midnightForest: BackdropSpec(
            nameKey: .backdropMidnightForest,
            accentColor: NSColor(red: 0.16, green: 0.52, blue: 0.44, alpha: 0.5).cgColor,
            sky: BackdropPainters.midnightForestSky,
            parallax: [
                ScrollSpec(period: 170, speed: 14, painter: BackdropPainters.forestFar),
                ScrollSpec(period: 230, speed: 30, painter: BackdropPainters.forestNear),
                ScrollSpec(period: 26, speed: groundScrollSpeed, painter: BackdropPainters.groundMarks(
                    color: NSColor(red: 0.14, green: 0.38, blue: 0.28, alpha: 1), dashWidth: 7))
            ]
        ),
        .crystalCave: BackdropSpec(
            nameKey: .backdropCrystalCave,
            accentColor: NSColor(red: 0.48, green: 0.34, blue: 0.78, alpha: 0.5).cgColor,
            sky: BackdropPainters.crystalCaveSky,
            parallax: [
                ScrollSpec(period: 150, speed: 14, painter: BackdropPainters.caveFar),
                ScrollSpec(period: 190, speed: 30, painter: BackdropPainters.caveNear),
                ScrollSpec(period: 30, speed: groundScrollSpeed, painter: BackdropPainters.groundMarks(
                    color: NSColor(red: 0.26, green: 0.16, blue: 0.42, alpha: 1), dashWidth: 5))
            ]
        ),
        .sunsetDunes: BackdropSpec(
            nameKey: .backdropSunsetDunes,
            accentColor: NSColor(red: 0.85, green: 0.52, blue: 0.28, alpha: 0.5).cgColor,
            sky: BackdropPainters.sunsetDunesSky,
            parallax: [
                ScrollSpec(period: 240, speed: 14, painter: BackdropPainters.dunesFar),
                ScrollSpec(period: 200, speed: 30, painter: BackdropPainters.dunesNear),
                ScrollSpec(period: 34, speed: groundScrollSpeed, painter: BackdropPainters.groundMarks(
                    color: NSColor(red: 0.78, green: 0.52, blue: 0.28, alpha: 1), dashWidth: 8))
            ]
        ),
        .neonCity: BackdropSpec(
            nameKey: .backdropNeonCity,
            accentColor: NSColor(red: 0.20, green: 0.44, blue: 0.85, alpha: 0.5).cgColor,
            sky: BackdropPainters.neonCitySky,
            parallax: [
                ScrollSpec(period: 190, speed: 14, painter: BackdropPainters.cityFar),
                ScrollSpec(period: 230, speed: 30, painter: BackdropPainters.cityNear),
                ScrollSpec(period: 24, speed: groundScrollSpeed, painter: BackdropPainters.groundMarks(
                    color: NSColor(red: 0.14, green: 0.30, blue: 0.52, alpha: 1), dashWidth: 6))
            ]
        )
    ]

    /// The fallback only fires if `all` is missing a case, which
    /// `ContentCatalogTests` asserts cannot happen.
    static func spec(for backdrop: BattleBackdrop) -> BackdropSpec {
        all[backdrop] ?? all[.midnightForest] ?? BackdropSpec(
            nameKey: .backdropMidnightForest,
            accentColor: NSColor.darkGray.cgColor,
            sky: { $0.ground(base: .black, edge: .darkGray) },
            parallax: []
        )
    }
}

// MARK: - Painters

/// The actual backdrop art. Static functions rather than methods so the catalog
/// can reference them as data.
enum BackdropPainters {

    // MARK: Static sky (never scrolls)

    static func midnightForestSky(_ canvas: BackdropCanvas) {
        canvas.skyBands([
            NSColor(red: 0.024, green: 0.05, blue: 0.12, alpha: 1),
            NSColor(red: 0.03, green: 0.07, blue: 0.15, alpha: 1),
            NSColor(red: 0.04, green: 0.10, blue: 0.19, alpha: 1),
            NSColor(red: 0.05, green: 0.13, blue: 0.22, alpha: 1)
        ])

        // stars
        let starPositions: [(CGFloat, CGFloat)] = [
            (0.06, 0.10), (0.16, 0.28), (0.28, 0.08), (0.38, 0.22),
            (0.50, 0.12), (0.60, 0.30), (0.74, 0.26), (0.88, 0.10), (0.95, 0.30)
        ]
        for (index, position) in starPositions.enumerated() {
            let alpha: CGFloat = index % 3 == 0 ? 0.85 : 0.5
            canvas.px(
                position.0 * canvas.width,
                position.1 * canvas.groundY,
                1.5,
                1.5,
                NSColor.white.withAlphaComponent(alpha)
            )
        }

        // moon
        canvas.px(canvas.width * 0.66, 5, 7, 7, NSColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 0.9))
        canvas.px(canvas.width * 0.66 + 2, 7, 3, 2, NSColor(red: 0.70, green: 0.78, blue: 0.92, alpha: 0.9))

        canvas.ground(
            base: NSColor(red: 0.04, green: 0.10, blue: 0.08, alpha: 1),
            edge: NSColor(red: 0.10, green: 0.28, blue: 0.20, alpha: 1)
        )
    }

    static func crystalCaveSky(_ canvas: BackdropCanvas) {
        canvas.skyBands([
            NSColor(red: 0.07, green: 0.04, blue: 0.12, alpha: 1),
            NSColor(red: 0.09, green: 0.05, blue: 0.15, alpha: 1),
            NSColor(red: 0.11, green: 0.06, blue: 0.19, alpha: 1),
            NSColor(red: 0.14, green: 0.08, blue: 0.23, alpha: 1)
        ])

        canvas.ground(
            base: NSColor(red: 0.08, green: 0.05, blue: 0.13, alpha: 1),
            edge: NSColor(red: 0.20, green: 0.12, blue: 0.32, alpha: 1)
        )
    }

    static func sunsetDunesSky(_ canvas: BackdropCanvas) {
        canvas.skyBands([
            NSColor(red: 0.17, green: 0.06, blue: 0.19, alpha: 1),
            NSColor(red: 0.29, green: 0.10, blue: 0.24, alpha: 1),
            NSColor(red: 0.48, green: 0.18, blue: 0.24, alpha: 1),
            NSColor(red: 0.72, green: 0.33, blue: 0.20, alpha: 1)
        ])

        // low sun
        canvas.px(
            canvas.width * 0.48 - 5,
            canvas.groundY - 15,
            11,
            11,
            NSColor(red: 1.0, green: 0.72, blue: 0.30, alpha: 0.95)
        )
        canvas.px(
            canvas.width * 0.48 - 3,
            canvas.groundY - 13,
            3,
            3,
            NSColor(red: 1.0, green: 0.86, blue: 0.52, alpha: 0.95)
        )

        canvas.ground(
            base: NSColor(red: 0.30, green: 0.16, blue: 0.10, alpha: 1),
            edge: NSColor(red: 0.66, green: 0.42, blue: 0.22, alpha: 1)
        )
    }

    static func neonCitySky(_ canvas: BackdropCanvas) {
        canvas.skyBands([
            NSColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1),
            NSColor(red: 0.03, green: 0.04, blue: 0.09, alpha: 1),
            NSColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1),
            NSColor(red: 0.05, green: 0.08, blue: 0.19, alpha: 1)
        ])

        canvas.ground(
            base: NSColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1),
            edge: NSColor(red: 0.10, green: 0.20, blue: 0.36, alpha: 1)
        )
    }

    // MARK: Parallax tiles (periodic, y-down)

    /// Dashes on the ground line. Shared by every backdrop; only the color and
    /// dash length change.
    static func groundMarks(color: NSColor, dashWidth: CGFloat) -> (BackdropCanvas) -> Void {
        { canvas in
            canvas.repeating { x in
                canvas.px(x, canvas.groundY + 2, dashWidth, 1.5, color)
            }
        }
    }

    static func forestFar(_ canvas: BackdropCanvas) {
        let green = NSColor(red: 0.04, green: 0.11, blue: 0.10, alpha: 1)
        let trees: [(CGFloat, CGFloat)] = [(12, 12), (60, 9), (108, 14), (146, 10)]
        canvas.repeating { base in
            for (dx, height) in trees {
                let x = base + dx
                let top = canvas.groundY - height
                canvas.px(x - 0.75, top + 3, 1.5, height - 3, green)
                canvas.px(x - 2.5, top + 1, 5, 3.5, green)
                canvas.px(x - 4, top + 4, 8, height - 4, green)
            }
        }
    }

    static func forestNear(_ canvas: BackdropCanvas) {
        let trees: [(CGFloat, CGFloat, Bool)] = [(24, 22, true), (96, 16, false), (168, 24, true)]
        canvas.repeating { base in
            for (dx, height, back) in trees {
                let x = base + dx
                let green = back
                    ? NSColor(red: 0.05, green: 0.14, blue: 0.12, alpha: 1)
                    : NSColor(red: 0.07, green: 0.19, blue: 0.15, alpha: 1)
                let top = canvas.groundY - height
                canvas.px(x - 1, top + 4, 2, height - 4, green)
                canvas.px(x - 2.5, top + 2, 5, 4, green)
                canvas.px(x - 4, top + 5, 8, 5, green)
                canvas.px(x - 5.5, top + 9, 11, height - 9, green)
            }
        }
    }

    static func caveFar(_ canvas: BackdropCanvas) {
        let rock = NSColor(red: 0.05, green: 0.03, blue: 0.09, alpha: 1)
        let stalactites: [(CGFloat, CGFloat)] = [(10, 9), (58, 13), (102, 7), (138, 11)]
        canvas.repeating { base in
            for (dx, length) in stalactites {
                let x = base + dx
                canvas.px(x - 3, 0, 6, length - 4, rock)
                canvas.px(x - 2, length - 4, 4, 2.5, rock)
                canvas.px(x - 1, length - 1.5, 2, 1.5, rock)
            }
        }
    }

    static func caveNear(_ canvas: BackdropCanvas) {
        let teal = NSColor(red: 0.20, green: 0.88, blue: 0.82, alpha: 1)
        let violet = NSColor(red: 0.62, green: 0.36, blue: 1.0, alpha: 1)
        let rock = NSColor(red: 0.07, green: 0.05, blue: 0.12, alpha: 1)
        let crystals: [(CGFloat, NSColor)] = [(20, teal), (110, violet), (160, teal)]
        canvas.repeating { base in
            for (dx, color) in crystals {
                let x = base + dx
                canvas.px(x - 3, canvas.groundY - 7, 6, 7, color.withAlphaComponent(0.25))
                canvas.px(x - 1.5, canvas.groundY - 6, 3, 6, color)
                canvas.px(x - 3.5, canvas.groundY - 3, 2, 3, color.withAlphaComponent(0.75))
            }
            // small stalagmite
            let sx = base + 62
            canvas.px(sx - 2.5, canvas.groundY - 5, 5, 5, rock)
            canvas.px(sx - 1.5, canvas.groundY - 7, 3, 3, rock)
        }
    }

    static func dunesFar(_ canvas: BackdropCanvas) {
        let backDune = NSColor(red: 0.42, green: 0.22, blue: 0.14, alpha: 1)
        canvas.repeating { base in
            canvas.px(base, canvas.groundY - 7, 130, 7, backDune)
            canvas.px(base + 150, canvas.groundY - 5, 90, 5, backDune)
        }
    }

    static func dunesNear(_ canvas: BackdropCanvas) {
        let frontDune = NSColor(red: 0.55, green: 0.30, blue: 0.16, alpha: 1)
        canvas.repeating { base in
            canvas.px(base + 30, canvas.groundY - 4, 110, 4, frontDune)
            canvas.px(base + 150, canvas.groundY - 3, 60, 3, frontDune)
        }
    }

    static func cityFar(_ canvas: BackdropCanvas) {
        let buildings: [(CGFloat, CGFloat, CGFloat)] = [
            (4, 30, 18), (44, 24, 26), (78, 34, 14), (122, 28, 22), (158, 26, 16)
        ]
        canvas.repeating { base in
            for (index, building) in buildings.enumerated() {
                let dark = index % 2 == 0
                    ? NSColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1)
                    : NSColor(red: 0.05, green: 0.07, blue: 0.16, alpha: 1)
                canvas.px(base + building.0, canvas.groundY - building.2, building.1, building.2, dark)
            }
        }
    }

    static func cityNear(_ canvas: BackdropCanvas) {
        let buildings: [(CGFloat, CGFloat, CGFloat)] = [
            (10, 34, 12), (60, 28, 17), (104, 38, 10), (158, 30, 15), (200, 24, 12)
        ]
        canvas.repeating { base in
            for (index, building) in buildings.enumerated() {
                let x = base + building.0
                let width = building.1
                let height = building.2
                let dark = index % 2 == 0
                    ? NSColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1)
                    : NSColor(red: 0.06, green: 0.08, blue: 0.19, alpha: 1)
                canvas.px(x, canvas.groundY - height, width, height, dark)

                let windowColor = index % 2 == 0
                    ? NSColor(red: 1.0, green: 0.84, blue: 0.36, alpha: 0.9)
                    : NSColor(red: 0.24, green: 0.85, blue: 1.0, alpha: 0.85)
                var windowY = canvas.groundY - height + 3
                while windowY < canvas.groundY - 3 {
                    var windowX = x + 2
                    while windowX < x + width - 2 {
                        if Int(windowX + windowY) % 3 != 0 {
                            canvas.px(windowX, windowY, 1.5, 1.5, windowColor.withAlphaComponent(0.75))
                        }
                        windowX += 4
                    }
                    windowY += 4
                }
            }
        }
    }
}
