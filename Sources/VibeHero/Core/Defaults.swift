import Foundation

/// Every persisted key the app owns, in one place.
///
/// These strings are load-bearing: they are what already sits in the user's
/// `defaults` database, so the values here must never be "tidied up" without a
/// migration. `LegacyDefaultsMigration` rewrites the pre-rename `NotchHero.*`
/// keys to `prefix` on first launch, which only works while every key in the
/// app is built from `prefix`.
enum DefaultsKey {
    static let legacyPrefix = "NotchHero."
    static let prefix = "VibeHero."

    // Preferences
    static let language = prefix + "language"
    static let selectedRole = prefix + "selectedRole"
    static let backdrop = prefix + "backdrop"
    static let pinnedDisplayID = prefix + "pinnedDisplayID"
    static let hideInFullScreen = prefix + "hideInFullScreen"
    static let isCamping = prefix + "isCamping"

    // Progression
    static let totalKills = prefix + "totalKills"
    static let heroTotalXP = prefix + "heroTotalXP"
    static let heroXPInitializedFromLevel = prefix + "heroXPInitializedFromLevel"
    static let currentHeroLevel = prefix + "currentHeroLevel"

    // Inventory and buffs
    static let inventoryState = prefix + "inventory.state.v1"
    static let inventoryGold = prefix + "inventory.gold"
    static let powerBoostExpiry = prefix + "buff.powerBoostExpiry"

    static func equipment(slot: String) -> String {
        prefix + "equipment." + slot
    }

    // Skills
    static func skillRank(_ skillID: String) -> String {
        prefix + "skill." + skillID
    }

    static func skillAutoCast(_ skillID: String) -> String {
        prefix + "skillAutoCast." + skillID
    }

    // Skill tree
    static let skillTreeAvailablePoints = prefix + "skillTree.availablePoints"
    static let skillBuild = prefix + "skillTree.build.v1"

    static func skillTreeNode(_ nodeID: String) -> String {
        prefix + "skillTree.node." + nodeID
    }
}

/// Thin typed wrapper over `UserDefaults.standard`, so persistence reads the
/// same way everywhere instead of each system spelling out the store.
enum Defaults {
    private static let storeLock = NSRecursiveLock()
    nonisolated(unsafe) private static var scopedStore: UserDefaults?

    static var store: UserDefaults {
        storeLock.lock()
        defer { storeLock.unlock() }
        return scopedStore ?? .standard
    }

    /// A synchronous, serialized scope lets integration tests exercise real
    /// progression code against an isolated suite instead of the player's save.
    static func withStore<T>(_ store: UserDefaults, perform body: () throws -> T) rethrows -> T {
        storeLock.lock()
        let previous = scopedStore
        scopedStore = store
        defer {
            scopedStore = previous
            storeLock.unlock()
        }
        return try body()
    }

    /// Serialize the complete read/modify/write operation against the selected
    /// store. Callers publish change notifications after this scope returns.
    static func transaction<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
        storeLock.lock()
        defer { storeLock.unlock() }
        return try body(scopedStore ?? .standard)
    }

    static func hasValue(forKey key: String) -> Bool {
        store.object(forKey: key) != nil
    }

    static func int(forKey key: String) -> Int {
        store.integer(forKey: key)
    }

    static func double(forKey key: String) -> Double {
        store.double(forKey: key)
    }

    static func bool(forKey key: String) -> Bool {
        store.bool(forKey: key)
    }

    static func string(forKey key: String) -> String? {
        store.string(forKey: key)
    }

    static func set(_ value: Int, forKey key: String) {
        store.set(value, forKey: key)
    }

    static func set(_ value: Double, forKey key: String) {
        store.set(value, forKey: key)
    }

    static func set(_ value: Bool, forKey key: String) {
        store.set(value, forKey: key)
    }

    static func set(_ value: String, forKey key: String) {
        store.set(value, forKey: key)
    }

    static func remove(forKey key: String) {
        store.removeObject(forKey: key)
    }
}
