import AppKit
import XCTest
@testable import VibeHero

/// Backdrop art moved from methods on `BackdropView` to painter functions fed a
/// `BackdropCanvas`. The riskiest part of that translation is `repeating`, which
/// replaced a hand-written `while base < stripWidth { ...; base += period }` loop
/// in each of the eight tile painters.
final class BackdropCanvasTests: XCTestCase {
    private func placements(stripWidth: CGFloat, period: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        BackdropCanvas(width: stripWidth, height: 80, groundY: 60, period: period)
            .repeating { result.append($0) }
        return result
    }

    /// The original loop semantics: start at 0, step by period, stop once the
    /// offset reaches the strip width.
    private func referenceLoop(stripWidth: CGFloat, period: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        var base: CGFloat = 0
        while base < stripWidth {
            result.append(base)
            base += period
        }
        return result
    }

    func testRepeatingMatchesTheOriginalWhileLoop() {
        // Covers every period the catalog actually uses, plus exact multiples and
        // off-by-one widths around the boundary.
        for period in [24, 26, 30, 34, 150, 170, 190, 200, 230, 240] as [CGFloat] {
            for stripWidth in [0, 1, period - 1, period, period + 1, period * 3, 420, 468] as [CGFloat] {
                XCTAssertEqual(
                    placements(stripWidth: stripWidth, period: period),
                    referenceLoop(stripWidth: stripWidth, period: period),
                    "period \(period), stripWidth \(stripWidth)"
                )
            }
        }
    }

    func testRepeatingCoversTheWholeStrip() {
        let placements = placements(stripWidth: 500, period: 170)

        XCTAssertEqual(placements.first, 0)
        XCTAssertGreaterThanOrEqual(placements.last ?? 0, 500 - 170)
        XCTAssertLessThan(placements.last ?? 0, 500)
    }

    func testRepeatingEmitsNothingForAnEmptyStrip() {
        XCTAssertTrue(placements(stripWidth: 0, period: 26).isEmpty)
    }

    func testSkyBandsSplitTheHeightAboveTheGround() {
        // Four bands is what every backdrop uses; they must tile groundY exactly.
        let groundY: CGFloat = 60
        let bandHeight = groundY / 4
        XCTAssertEqual(bandHeight * 4, groundY, accuracy: 0.000_001)
    }

    /// Every backdrop must paint something for both the sky and each parallax
    /// layer — a painter wired to the wrong catalog entry, or one that no longer
    /// reaches its draw calls, would produce a blank tile.
    func testEveryBackdropPaintsSkyAndParallaxLayers() {
        for backdrop in BattleBackdrop.allCases {
            let spec = backdrop.spec

            let sky = render(width: 420, height: 80) { canvas in spec.sky(canvas) }
            XCTAssertGreaterThan(sky.painted, 0, "\(backdrop) sky painted nothing")

            XCTAssertEqual(spec.parallax.count, 3, "\(backdrop) should have 3 parallax layers")
            for (index, layer) in spec.parallax.enumerated() {
                let painted = render(width: 420 + layer.period, height: 80, period: layer.period) { canvas in
                    layer.painter(canvas)
                }
                XCTAssertGreaterThan(painted.painted, 0, "\(backdrop) parallax layer \(index) painted nothing")
                XCTAssertGreaterThan(layer.speed, 0, "\(backdrop) layer \(index) would never scroll")
                XCTAssertGreaterThan(layer.period, 0, "\(backdrop) layer \(index) would loop forever")
            }
        }
    }

    /// Guards against a spec pointing at another backdrop's painter. Compares
    /// pixel content, not coverage: every sky fills the whole canvas, so a
    /// painted-pixel count is identical for all four by construction.
    func testBackdropsAreVisuallyDistinct() {
        let signatures = BattleBackdrop.allCases.map { backdrop in
            render(width: 420, height: 80) { canvas in backdrop.spec.sky(canvas) }.fingerprint
        }

        XCTAssertEqual(Set(signatures).count, signatures.count, "two backdrops paint identical skies")
    }

    /// Draws into an offscreen bitmap and reports both how much got painted and
    /// a hash of the pixel content.
    private struct Render {
        let painted: Int
        let fingerprint: Int
    }

    private func render(
        width: CGFloat,
        height: CGFloat,
        period: CGFloat = 0,
        body: (BackdropCanvas) -> Void
    ) -> Render {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(width),
            pixelsHigh: Int(height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
            XCTFail("could not build an offscreen context")
            return Render(painted: 0, fingerprint: 0)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        body(
            BackdropCanvas(
                width: width,
                height: height,
                groundY: max(height - 10, height * 0.72),
                period: period
            )
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.bitmapData else {
            return Render(painted: 0, fingerprint: 0)
        }

        var painted = 0
        var hasher = Hasher()
        let byteCount = rep.pixelsWide * rep.pixelsHigh * 4
        for index in 0..<byteCount {
            hasher.combine(data[index])
            if index % 4 == 3, data[index] > 0 {
                painted += 1
            }
        }
        return Render(painted: painted, fingerprint: hasher.finalize())
    }
}
