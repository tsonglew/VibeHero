import AppKit

final class NotchWindow: NSPanel {
    private let notchView: NotchContentView
    private var collapseWorkItem: DispatchWorkItem?
    private var isExpanded = false

    init() {
        let initialStyles = NotchStyle.styles(for: NSScreen.main ?? NSScreen.screens.first)
        let contentRect = NSRect(origin: .zero, size: initialStyles.collapsed.windowSize)
        notchView = NotchContentView(
            frame: contentRect,
            collapsedStyle: initialStyles.collapsed,
            expandedStyle: initialStyles.expanded
        )

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true

        notchView.onHoverChanged = { [weak self] isHovering in
            if isHovering {
                self?.expand()
            } else {
                self?.scheduleCollapse()
            }
        }
        contentView = notchView
    }

    func anchorToActiveScreen() {
        let styles = currentStyles()
        notchView.updateStyles(collapsed: styles.collapsed, expanded: styles.expanded, animated: false)

        let targetSize = isExpanded ? styles.expanded.windowSize : styles.collapsed.windowSize
        setFrame(frameForCurrentScreen(size: targetSize), display: true)
    }

    private func expand() {
        collapseWorkItem?.cancel()
        setExpanded(true)
    }

    private func scheduleCollapse() {
        collapseWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.setExpanded(false)
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: item)
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }

        isExpanded = expanded
        let styles = currentStyles()
        let targetSize = expanded ? styles.expanded.windowSize : styles.collapsed.windowSize
        let targetFrame = frameForCurrentScreen(size: targetSize)

        notchView.updateStyles(collapsed: styles.collapsed, expanded: styles.expanded, animated: false)
        notchView.setExpanded(expanded, animated: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = expanded ? 0.22 : 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(targetFrame, display: true)
        }
    }

    private func currentStyles() -> (collapsed: NotchStyle, expanded: NotchStyle) {
        NotchStyle.styles(for: NSScreen.main ?? NSScreen.screens.first)
    }

    private func frameForCurrentScreen(size: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.frame else {
            return NSRect(origin: self.frame.origin, size: size)
        }

        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height
        )

        return NSRect(origin: origin, size: size)
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
