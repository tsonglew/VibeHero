import AppKit

/// Which display the notch overlay lives on. `nil` means "follow the main
/// display" rather than a specific pinned one.
enum ScreenPinning {
    static func load() -> Int? {
        let value = Defaults.int(forKey: DefaultsKey.pinnedDisplayID)
        return value == 0 ? nil : value
    }

    static func save(_ displayID: Int?) {
        if let displayID {
            Defaults.set(displayID, forKey: DefaultsKey.pinnedDisplayID)
        } else {
            Defaults.remove(forKey: DefaultsKey.pinnedDisplayID)
        }
    }

    static func preferredScreen() -> NSScreen? {
        if let displayID = load(),
           let screen = NSScreen.screens.first(where: { $0.notchDisplayID == displayID }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

extension NSScreen {
    var notchDisplayID: Int? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue
    }

    var notchDisplayName: String {
        let size = frame.size
        return "\(localizedName) (\(Int(size.width)) x \(Int(size.height)))"
    }
}
