import AppKit
import XCTest
@testable import VibeHero

final class NotchGeometryTests: XCTestCase {
    private func laptop() -> NotchScreenGeometry {
        NotchScreenGeometry(
            frame: NSRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 38,
            auxiliaryTopLeftArea: NSRect(x: 0, y: 944, width: 620, height: 38),
            auxiliaryTopRightArea: NSRect(x: 820, y: 944, width: 692, height: 38)
        )
    }

    func testActualCameraGapDeterminesWidthAndOffCenterAnchorBelowSafeArea() {
        let geometry = laptop()
        XCTAssertEqual(geometry.cutoutRect, NSRect(x: 620, y: 944, width: 200, height: 38))
        XCTAssertEqual(geometry.anchorX, 720, "The physical gap need not be centered in the display")
        let styles = NotchStyle.styles(geometry: geometry)
        XCTAssertEqual(styles.collapsed.notchSize, NSSize(width: 200, height: 34))
        XCTAssertGreaterThanOrEqual(styles.expanded.notchSize.width, 468)
        XCTAssertEqual(styles.expanded.notchSize.height, styles.collapsed.notchSize.height + 190)
        for style in [styles.collapsed, styles.expanded] {
            let frame = geometry.windowFrame(for: style.windowSize)
            XCTAssertEqual(frame.midX, 720)
            XCTAssertEqual(frame.maxY, 944)
            XCTAssertTrue(geometry.frame.contains(frame))
            XCTAssertEqual(style.topInset, 0, "Window anchoring already applies the safe top inset")
            XCTAssertFalse(frame.intersects(geometry.cutoutRect!))
        }
    }

    func testAuxiliaryRectanglesStayInGlobalCoordinatesOnNegativeOffsetDisplay() {
        let geometry = NotchScreenGeometry(
            frame: NSRect(x: -1920, y: -200, width: 1920, height: 1080), safeAreaTop: 32,
            auxiliaryTopLeftArea: NSRect(x: -1920, y: 848, width: 820, height: 32),
            auxiliaryTopRightArea: NSRect(x: -900, y: 848, width: 900, height: 32)
        )
        XCTAssertEqual(geometry.cutoutRect, NSRect(x: -1100, y: 848, width: 200, height: 32))
        let frame = geometry.windowFrame(for: NSSize(width: 502, height: 242))
        XCTAssertEqual(frame, NSRect(x: -1251, y: 606, width: 502, height: 242))
        XCTAssertTrue(geometry.frame.contains(frame))
    }

    func testMissingAuxiliaryAreasKeepSafeTopAndUseDisplayCenter() {
        let geometry = NotchScreenGeometry(frame: NSRect(x: 200, y: 100, width: 1200, height: 800), safeAreaTop: 42)
        XCTAssertNil(geometry.cutoutRect)
        XCTAssertEqual(geometry.anchorX, 800)
        XCTAssertEqual(geometry.contentTopY, 858)
        let style = NotchStyle.styles(geometry: geometry).collapsed
        XCTAssertEqual(style.notchSize, NSSize(width: 199, height: 34))
        XCTAssertEqual(geometry.windowFrame(for: style.windowSize).maxY, 858)
    }

    func testExternalDisplayWithoutCutoutUsesStablePillAtPhysicalTop() {
        let geometry = NotchScreenGeometry(frame: NSRect(x: 1920, y: 100, width: 2560, height: 1440), safeAreaTop: 0)
        let style = NotchStyle.styles(geometry: geometry).collapsed
        XCTAssertNil(geometry.cutoutRect)
        XCTAssertEqual(style.notchSize, NSSize(width: 199, height: 34))
        XCTAssertEqual(geometry.windowFrame(for: style.windowSize), NSRect(x: 3088.5, y: 1506, width: 223, height: 34))
    }

    func testInvalidAuxiliaryGapCannotMoveAnchorButStillRespectsSafeTop() {
        let frame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        for areas in [
            (NSRect(x: 0, y: 868, width: 800, height: 32), NSRect(x: 700, y: 868, width: 740, height: 32)),
            (NSRect(x: 0, y: 100, width: 600, height: 32), NSRect(x: 800, y: 100, width: 640, height: 32))
        ] {
            let geometry = NotchScreenGeometry(frame: frame, safeAreaTop: 32,
                auxiliaryTopLeftArea: areas.0, auxiliaryTopRightArea: areas.1)
            XCTAssertNil(geometry.cutoutRect)
            XCTAssertEqual(geometry.anchorX, 720)
            XCTAssertEqual(geometry.windowFrame(for: NSSize(width: 500, height: 250)).maxY, 868)
        }
    }

    func testWindowClampsOversizedDimensionsAndOffCenterAnchorToTheDisplay() {
        let small = NotchScreenGeometry(frame: NSRect(x: -500, y: 80, width: 300, height: 200), safeAreaTop: 30)
        XCTAssertEqual(small.windowFrame(for: NSSize(width: 1000, height: 1000)),
                       NSRect(x: -500, y: 80, width: 300, height: 170))
        let edge = NotchScreenGeometry(
            frame: NSRect(x: 0, y: 0, width: 1000, height: 700), safeAreaTop: 30,
            auxiliaryTopLeftArea: NSRect(x: 0, y: 670, width: 10, height: 30),
            auxiliaryTopRightArea: NSRect(x: 110, y: 670, width: 890, height: 30)
        )
        XCTAssertEqual(edge.anchorX, 60)
        XCTAssertEqual(edge.windowFrame(for: NSSize(width: 500, height: 242)).minX, 0)
        XCTAssertEqual(edge.windowFrame(for: NSSize(width: -1, height: -10)).size, .zero)
        XCTAssertEqual(NotchStyle.styles(geometry: edge).collapsed.notchSize.width, 199,
                       "A narrow physical gap must not squeeze the compact labels")
    }

    func testStyleViewportMatchesClampedWindowOnSmallScreensAndOversizedGaps() {
        let geometries = [
            NotchScreenGeometry(frame: NSRect(x: -500, y: 80, width: 300, height: 200), safeAreaTop: 30),
            NotchScreenGeometry(frame: NSRect(x: 50, y: -80, width: 10, height: 12), safeAreaTop: 4),
            NotchScreenGeometry(frame: NSRect(x: 0, y: 0, width: 800, height: 600), safeAreaTop: 30,
                auxiliaryTopLeftArea: NSRect(x: 0, y: 570, width: 5, height: 30),
                auxiliaryTopRightArea: NSRect(x: 795, y: 570, width: 5, height: 30))
        ]
        for geometry in geometries {
            let styles = NotchStyle.styles(geometry: geometry, expandedNotchHeight: 10_000)
            for style in [styles.collapsed, styles.expanded] {
                let frame = geometry.windowFrame(for: style.windowSize)
                XCTAssertEqual(style.windowSize, frame.size)
                XCTAssertGreaterThanOrEqual(style.notchSize.width, 0)
                XCTAssertGreaterThanOrEqual(style.notchSize.height, 0)
                XCTAssertLessThanOrEqual(style.notchSize.width, style.windowSize.width)
                XCTAssertLessThanOrEqual(style.notchSize.height, style.windowSize.height)
                XCTAssertTrue(geometry.frame.contains(frame))
                XCTAssertLessThanOrEqual(frame.maxY, geometry.contentTopY)
            }
        }
    }

    func testContentHeightDoesNotGuessHardwareFromMenuBarHeight() {
        // Auto-hiding a menu bar changes visibleFrame, which is intentionally
        // absent from the geometry inputs. Changing safe-inset heights also
        // must not shrink the readable compact HUD or the #9 expanded layout.
        for top in [CGFloat(0), 24, 32, 38, 44] {
            let geometry = NotchScreenGeometry(frame: NSRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: top)
            let styles = NotchStyle.styles(geometry: geometry)
            XCTAssertEqual(styles.collapsed.notchSize.height, 34)
            XCTAssertEqual(styles.expanded.notchSize.height, 224)
            XCTAssertEqual(geometry.windowFrame(for: styles.collapsed.windowSize).maxY, 982 - top)
        }
    }

    func testSwitchingScreensRecomputesStylesAndAnchorWithoutCachedDisplayGeometry() {
        let internalDisplay = laptop()
        let external = NotchScreenGeometry(frame: NSRect(x: -1920, y: 100, width: 1920, height: 1080), safeAreaTop: 0)
        let before = NotchStyle.styles(geometry: internalDisplay).collapsed
        let outside = NotchStyle.styles(geometry: external).collapsed
        let returned = NotchStyle.styles(geometry: internalDisplay).collapsed
        XCTAssertEqual(before.notchSize, returned.notchSize)
        XCTAssertEqual(internalDisplay.windowFrame(for: before.windowSize), internalDisplay.windowFrame(for: returned.windowSize))
        XCTAssertEqual(outside.notchSize.width, 199)
        XCTAssertEqual(external.windowFrame(for: outside.windowSize).midX, -960)
        XCTAssertEqual(external.windowFrame(for: outside.windowSize).maxY, 1180)
    }

    func testSessionHeightCapAndInvalidRequestsPreserveReadableBaseLayout() {
        let geometry = laptop()
        let tall = NotchStyle.styles(geometry: geometry, expandedNotchHeight: 2000).expanded
        XCTAssertEqual(tall.windowSize.height, round(geometry.frame.height * 0.45))
        XCTAssertTrue(geometry.frame.contains(geometry.windowFrame(for: tall.windowSize)))
        for requested in [CGFloat(-1), .nan, .infinity] {
            let styles = NotchStyle.styles(geometry: geometry, expandedNotchHeight: requested)
            XCTAssertEqual(styles.expanded.notchSize.height, 224)
        }
        let fallback = NotchStyle.styles(geometry: nil)
        XCTAssertEqual(fallback.collapsed.notchSize, NotchStyle.fallbackCollapsed.notchSize)
        XCTAssertEqual(fallback.expanded.notchSize, NotchStyle.fallbackExpanded.notchSize)
    }
}
