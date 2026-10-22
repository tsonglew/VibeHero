import AppKit

/// Window and content geometry for one presentation state. The camera gap
/// controls compact width, while the HUD's readable height stays independent
/// of menu-bar visibility. NotchScreenGeometry positions it below the cutout.
struct NotchStyle {
    let windowSize: NSSize
    let notchSize: NSSize
    let topInset: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOpacity: Float

    static let fallbackCollapsed = makeCollapsed()

    static let fallbackExpanded = makeExpanded(collapsed: fallbackCollapsed)

    static func styles(for screen: NSScreen?, expandedNotchHeight: CGFloat? = nil) -> (collapsed: NotchStyle, expanded: NotchStyle) {
        styles(geometry: screen.map(NotchScreenGeometry.init(screen:)), expandedNotchHeight: expandedNotchHeight)
    }

    static func styles(
        geometry: NotchScreenGeometry?, expandedNotchHeight: CGFloat? = nil
    ) -> (collapsed: NotchStyle, expanded: NotchStyle) {
        let collapsed = makeCollapsed(cutoutWidth: geometry?.cutoutRect?.width, geometry: geometry)
        return (collapsed, makeExpanded(collapsed: collapsed, requestedHeight: expandedNotchHeight, geometry: geometry))
    }

    private static func makeCollapsed(cutoutWidth: CGFloat? = nil, geometry: NotchScreenGeometry? = nil) -> NotchStyle {
        // A narrow gap still needs enough room for the compact level/status.
        // Non-notched displays use a stable 199pt pill, regardless of Dock or
        // menu-bar settings, instead of treating menu-bar height as a notch.
        let desiredSize = NSSize(width: max(199, cutoutWidth ?? 199) + 24, height: 34)
        let windowSize = constrainedSize(desiredSize, geometry: geometry)
        let width = max(0, windowSize.width - 24)
        let height = windowSize.height

        return NotchStyle(
            windowSize: windowSize,
            notchSize: NSSize(width: width, height: height),
            topInset: 0,
            cornerRadius: round(height * 0.45),
            shadowRadius: 8,
            shadowOpacity: 0.26
        )
    }

    /// `requestedHeight` lets the session list ask for a taller panel than the
    /// game HUD needs, so a long list is readable instead of clipped to three
    /// rows. It only ever grows the panel, and never past `heightCap`.
    private static func makeExpanded(
        collapsed: NotchStyle,
        requestedHeight: CGFloat? = nil,
        geometry: NotchScreenGeometry? = nil
    ) -> NotchStyle {
        let base = round(collapsed.notchSize.height + 190)
        let requested = requestedHeight.flatMap { $0.isFinite ? round($0) : nil } ?? base
        let desiredHeight = min(max(base, requested), heightCap(for: geometry, base: base))
        let desiredWidth = round(max(468, collapsed.notchSize.width + 260))
        let windowSize = constrainedSize(NSSize(width: desiredWidth + 34, height: desiredHeight + 18), geometry: geometry)
        let width = max(0, windowSize.width - 34)
        let height = max(0, windowSize.height - 18)

        return NotchStyle(
            windowSize: windowSize,
            notchSize: NSSize(width: width, height: height),
            topInset: 0,
            cornerRadius: round(min(34, base * 0.28)),
            shadowRadius: 24,
            shadowOpacity: 0.52
        )
    }

    /// The style and the placed window must describe the same viewport. On
    /// displays smaller than the normal HUD, shrink the viewport and its
    /// shadow padding together; layout may clip, but never extends beyond a
    /// differently sized window or produces negative content dimensions.
    private static func constrainedSize(_ desiredSize: NSSize, geometry: NotchScreenGeometry?) -> NSSize {
        geometry?.windowFrame(for: desiredSize).size ?? desiredSize
    }

    /// However many sessions are open, the panel stops at 45% of the display so
    /// it stays an overlay rather than a window; past that the list scrolls.
    private static func heightCap(for geometry: NotchScreenGeometry?, base: CGFloat) -> CGFloat {
        guard let geometry else {
            return base
        }
        // The window adds 18pt of shadow padding below the notch shape.
        let availableHeight = max(0, geometry.frame.height - geometry.safeAreaTop)
        return max(base, min(round(geometry.frame.height * 0.45), availableHeight) - 18)
    }
}

/// The notch silhouette: square at the top edge where it meets the bezel,
/// rounded on the two bottom corners.
enum NotchShape {
    static func path(in rect: CGRect, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let r = min(radius, rect.width / 2, rect.height)
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        path.move(to: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        path.addLine(to: CGPoint(x: maxX, y: minY + r))
        path.addQuadCurve(to: CGPoint(x: maxX - r, y: minY), control: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: minX + r, y: minY))
        path.addQuadCurve(to: CGPoint(x: minX, y: minY + r), control: CGPoint(x: minX, y: minY))
        path.closeSubpath()

        return path
    }
}
