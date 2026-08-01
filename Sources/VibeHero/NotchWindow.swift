import AppKit

final class NotchWindow: NSPanel {
    private let notchView: NotchContentView
    private let fullScreenMonitor = FullScreenMonitor()
    private var settingsWindow: NotchSettingsWindow?
    private var collapseWorkItem: DispatchWorkItem?
    private var isExpanded = false
    private var hiddenForFullScreen = false
    private var fullScreenPeekMonitor: Any?
    private var isPeekingInFullScreen = false

    init() {
        let initialScreen = ScreenPinning.preferredScreen()
        let initialStyles = NotchStyle.styles(for: initialScreen)
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
        notchView.onSettingsRequested = { [weak self] in
            self?.showSettings()
        }
        notchView.onExpandedHeightChanged = { [weak self] in
            self?.refreshExpandedSize()
        }
        contentView = notchView

        fullScreenMonitor.onChange = { [weak self] _ in
            self?.applyFullScreenVisibility()
        }
        fullScreenMonitor.start()
    }

    // Single entry point for showing the window: re-anchors, then honors the
    // full-screen hide preference instead of always ordering front.
    func show() {
        anchorToPreferredScreen()
        refreshFullScreenVisibility()
        if !hiddenForFullScreen {
            orderFrontRegardless()
        }
    }

    func refreshFullScreenVisibility() {
        fullScreenMonitor.refresh()
        applyFullScreenVisibility()
    }

    private func applyFullScreenVisibility() {
        let shouldHide = FullScreenHidePreference.load() && fullScreenMonitor.isFullScreenActive
        guard shouldHide != hiddenForFullScreen else {
            return
        }

        hiddenForFullScreen = shouldHide
        if shouldHide {
            collapseWorkItem?.cancel()
            orderOut(nil)
            startFullScreenPeekMonitor()
        } else {
            stopFullScreenPeekMonitor()
            orderFrontRegardless()
        }
    }

    // While hidden in full screen, watch the pointer globally (mouse events
    // do not require accessibility permission) so a push against the top edge
    // of the pinned screen pops the notch back out, like the menu bar.
    private func startFullScreenPeekMonitor() {
        guard fullScreenPeekMonitor == nil else {
            return
        }

        fullScreenPeekMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleFullScreenPeekMouseMoved()
        }
    }

    private func stopFullScreenPeekMonitor() {
        if let fullScreenPeekMonitor {
            NSEvent.removeMonitor(fullScreenPeekMonitor)
        }
        fullScreenPeekMonitor = nil
        isPeekingInFullScreen = false
    }

    private func handleFullScreenPeekMouseMoved() {
        guard hiddenForFullScreen, FullScreenHidePreference.load(),
              let screen = ScreenPinning.preferredScreen() else {
            return
        }

        let location = NSEvent.mouseLocation
        if isPeekingInFullScreen {
            // Hide again once the pointer leaves the pinned screen or drops
            // below the window (the expanded window's bottom edge is lower,
            // so the threshold follows the current frame).
            if !screen.frame.contains(location) || location.y < frame.minY - 12 {
                isPeekingInFullScreen = false
                orderOut(nil)
            }
        } else if screen.frame.contains(location), location.y >= screen.frame.maxY - 4 {
            isPeekingInFullScreen = true
            orderFrontRegardless()
        }
    }

    func anchorToPreferredScreen() {
        let styles = currentStyles()
        notchView.updateStyles(collapsed: styles.collapsed, expanded: styles.expanded, animated: false)
        settingsWindow?.refresh()

        let targetSize = isExpanded ? styles.expanded.windowSize : styles.collapsed.windowSize
        setFrame(frameForPreferredScreen(size: targetSize), display: true)

        // Coverage depends on which screen we are pinned to.
        fullScreenMonitor.refresh()
        applyFullScreenVisibility()
    }

    func showSettings() {
        let window = settingsWindow ?? NotchSettingsWindow()
        settingsWindow = window
        window.onRoleChanged = { [weak self] in
            self?.notchView.reloadPreferences()
        }
        window.onDisplayChanged = { [weak self] in
            self?.anchorToPreferredScreen()
        }
        window.onSkillChanged = { [weak self] in
            self?.notchView.reloadPreferences()
        }
        window.onLanguageChanged = { [weak self] in
            self?.notchView.reloadPreferences()
            self?.settingsWindow?.refresh()
        }
        window.onBackdropChanged = { [weak self] in
            self?.notchView.reloadPreferences()
        }
        window.onFullScreenHideChanged = { [weak self] in
            self?.refreshFullScreenVisibility()
        }
        window.refresh()
        window.centerNear(rect: frame)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        let targetFrame = frameForPreferredScreen(size: targetSize)

        notchView.updateStyles(collapsed: styles.collapsed, expanded: styles.expanded, animated: false)
        notchView.setExpanded(expanded, animated: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = expanded ? 0.22 : 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(targetFrame, display: true)
        }
    }

    private func currentStyles() -> (collapsed: NotchStyle, expanded: NotchStyle) {
        NotchStyle.styles(
            for: ScreenPinning.preferredScreen(),
            expandedNotchHeight: notchView.preferredExpandedNotchHeight
        )
    }

    /// The expanded panel grows to fit the session list, so its size can change
    /// while it is already on screen - switching to the list, or a scan that
    /// found more sessions.
    private func refreshExpandedSize() {
        let styles = currentStyles()
        notchView.updateStyles(collapsed: styles.collapsed, expanded: styles.expanded, animated: false)

        guard isExpanded else { return }

        let targetFrame = frameForPreferredScreen(size: styles.expanded.windowSize)
        guard targetFrame != frame else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(targetFrame, display: true)
        }
    }

    private func frameForPreferredScreen(size: NSSize) -> NSRect {
        let screen = ScreenPinning.preferredScreen()
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
