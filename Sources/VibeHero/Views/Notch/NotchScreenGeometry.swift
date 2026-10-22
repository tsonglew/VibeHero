import AppKit

/// A snapshot in global AppKit screen coordinates. No menu-bar or Dock state
/// participates: `visibleFrame` changes when either auto-hides, while the
/// physical camera cutout and its safe area remain in the same place.
struct NotchScreenGeometry: Equatable {
    let frame: NSRect
    let safeAreaTop: CGFloat
    let auxiliaryTopLeftArea: NSRect?
    let auxiliaryTopRightArea: NSRect?

    init(
        frame: NSRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeftArea: NSRect? = nil,
        auxiliaryTopRightArea: NSRect? = nil
    ) {
        let validFrame = Self.validFrame(frame)
        self.frame = validFrame
        self.safeAreaTop = safeAreaTop.isFinite ? min(max(0, safeAreaTop), validFrame.height) : 0
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
    }

    init(screen: NSScreen) {
        self.init(frame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
                  auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
                  auxiliaryTopRightArea: screen.auxiliaryTopRightArea)
    }

    /// Apple supplies the auxiliary rectangles in global screen coordinates.
    /// Their gap describes the cutout; a missing/invalid pair cannot establish
    /// its width or horizontal position, but the safe top inset still applies.
    var cutoutRect: NSRect? {
        guard safeAreaTop > 0,
              let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea,
              Self.isFinite(left), Self.isFinite(right),
              left.width > 0, left.height > 0, right.width > 0, right.height > 0 else { return nil }
        let band = NSRect(x: frame.minX, y: contentTopY, width: frame.width, height: safeAreaTop)
        guard left.intersects(band), right.intersects(band) else { return nil }
        let leftEdge = max(frame.minX, left.maxX)
        let rightEdge = min(frame.maxX, right.minX)
        guard leftEdge < rightEdge else { return nil }
        return NSRect(x: leftEdge, y: contentTopY, width: rightEdge - leftEdge, height: safeAreaTop)
    }

    var anchorX: CGFloat { cutoutRect?.midX ?? frame.midX }

    /// The overlay's content belongs below the unsafe strip, including when
    /// macOS reports the safe inset without auxiliary rectangles.
    var contentTopY: CGFloat { frame.maxY - safeAreaTop }

    func windowFrame(for requestedSize: NSSize) -> NSRect {
        let availableHeight = max(0, frame.height - safeAreaTop)
        let width = min(frame.width, Self.validLength(requestedSize.width))
        let height = min(availableHeight, Self.validLength(requestedSize.height))
        let x = min(max(frame.minX, anchorX - width / 2), frame.maxX - width)
        return NSRect(x: x, y: contentTopY - height, width: width, height: height)
    }

    private static func validLength(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }

    private static func validFrame(_ rect: NSRect) -> NSRect {
        guard isFinite(rect) else { return .zero }
        return NSRect(x: rect.origin.x, y: rect.origin.y,
                      width: max(0, rect.width), height: max(0, rect.height))
    }

    private static func isFinite(_ rect: NSRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
            && rect.maxX.isFinite && rect.maxY.isFinite
    }
}
