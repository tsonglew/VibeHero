import Foundation

/// Rest is an explicit player preference, including after a relaunch.
enum CampProgress {
    static func load() -> Bool {
        Defaults.bool(forKey: DefaultsKey.isCamping)
    }

    static func save(_ isCamping: Bool) {
        Defaults.set(isCamping, forKey: DefaultsKey.isCamping)
    }
}
