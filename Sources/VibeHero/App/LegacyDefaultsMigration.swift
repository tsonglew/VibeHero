import Foundation

/// One-time rename of the persisted `NotchHero.*` UserDefaults keys to
/// `VibeHero.*`, from before the app settled on the Vibe Hero name. Without
/// this, existing players would lose kills, XP, gold, equipment and settings
/// on the first launch of a renamed build. Safe to delete once installs from
/// that era no longer matter.
enum LegacyDefaultsMigration {
    static func run() {
        let defaults = UserDefaults.standard
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(DefaultsKey.legacyPrefix) {
            let newKey = DefaultsKey.prefix + key.dropFirst(DefaultsKey.legacyPrefix.count)
            if defaults.object(forKey: newKey) == nil {
                defaults.set(value, forKey: newKey)
            }
            defaults.removeObject(forKey: key)
        }
    }
}
