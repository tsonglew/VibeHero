import AppKit

enum FullScreenHidePreference {
    private static let defaultsKey = "NotchHero.hideInFullScreen"

    static func load() -> Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func save(_ hidden: Bool) {
        UserDefaults.standard.set(hidden, forKey: defaultsKey)
    }
}

// Watches space, app, and display changes and reports whether an on-screen
// window covers the whole pinned screen — that is how macOS lays out
// full-screen apps. Window bounds are readable without screen-recording
// permission; only titles are gated.
final class FullScreenMonitor {
    var onChange: ((Bool) -> Void)?

    private(set) var isFullScreenActive = false {
        didSet {
            if isFullScreenActive != oldValue {
                onChange?(isFullScreenActive)
            }
        }
    }

    private var observers: [NSObjectProtocol] = []
    private var recheckWorkItem: DispatchWorkItem?

    func start() {
        guard observers.isEmpty else {
            return
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleEvaluate()
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleEvaluate()
        })

        evaluate()
    }

    func refresh() {
        evaluate()
    }

    private func scheduleEvaluate() {
        evaluate()

        // Space switches animate; the window list can still show the old
        // layout mid-transition, so re-check once the animation settles.
        recheckWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.evaluate()
        }
        recheckWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
    }

    private func evaluate() {
        isFullScreenActive = Self.screenIsCoveredByFullScreenWindow(ScreenPinning.preferredScreen())
    }

    static func screenIsCoveredByFullScreenWindow(_ screen: NSScreen?) -> Bool {
        guard let screen else {
            return false
        }

        let target = screen.frame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? target.height
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for info in list {
            // Only normal-level app windows count. Status-level overlays
            // (layer 20+, e.g. vendor desktop agents or the Dock) can also
            // be screen-sized but do not represent a full-screen app.
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let quartzRect = CGRect(dictionaryRepresentation: boundsDict) else {
                continue
            }

            // Quartz window bounds are measured from the primary display's
            // top-left corner; NSScreen frames from its bottom-left corner.
            let rect = CGRect(
                x: quartzRect.minX,
                y: primaryHeight - quartzRect.minY - quartzRect.height,
                width: quartzRect.width,
                height: quartzRect.height
            )

            if rect.width >= target.width, rect.height >= target.height, rect.intersects(target) {
                return true
            }
        }
        return false
    }
}
