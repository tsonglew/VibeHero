import AppKit

enum LootKind: CaseIterable {
    case healthPotion
    case powerBoost
    case gold

    var name: String {
        switch self {
        case .healthPotion: L10n.text(.lootHealthPotion)
        case .powerBoost: L10n.text(.lootPowerBoost)
        case .gold: L10n.text(.lootGold)
        }
    }

    var color: NSColor {
        switch self {
        case .healthPotion: NSColor(red: 1.0, green: 0.25, blue: 0.34, alpha: 1)
        case .powerBoost: NSColor(red: 0.35, green: 0.92, blue: 1.0, alpha: 1)
        case .gold: NSColor(red: 1.0, green: 0.76, blue: 0.18, alpha: 1)
        }
    }
}

struct LootDrop {
    let kind: LootKind
    let amount: Int
}

enum ItemSystem {
    private static let goldKey = "NotchHero.inventory.gold"
    private static let powerBoostExpiryKey = "NotchHero.buff.powerBoostExpiry"

    static let powerBoostMultiplier: CGFloat = 1.25
    static let powerBoostDuration: TimeInterval = 60

    static func rollDrop() -> LootDrop? {
        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<28:
            return LootDrop(kind: .healthPotion, amount: Int.random(in: 18...32))
        case 28..<48:
            return LootDrop(kind: .powerBoost, amount: Int(powerBoostDuration))
        case 48..<82:
            return LootDrop(kind: .gold, amount: Int.random(in: 6...18))
        default:
            return nil
        }
    }

    static var gold: Int {
        max(0, UserDefaults.standard.integer(forKey: goldKey))
    }

    static func addGold(_ amount: Int) {
        UserDefaults.standard.set(gold + max(0, amount), forKey: goldKey)
    }

    static func activatePowerBoost(now: Date = Date()) {
        let currentExpiry = powerBoostExpiry
        let base = max(now, currentExpiry ?? now)
        UserDefaults.standard.set(base.addingTimeInterval(powerBoostDuration).timeIntervalSince1970, forKey: powerBoostExpiryKey)
    }

    static func powerBoostRemaining(now: Date = Date()) -> Int {
        guard let expiry = powerBoostExpiry else {
            return 0
        }
        return max(0, Int(ceil(expiry.timeIntervalSince(now))))
    }

    static func damageMultiplier(now: Date = Date()) -> CGFloat {
        powerBoostRemaining(now: now) > 0 ? powerBoostMultiplier : 1
    }

    private static var powerBoostExpiry: Date? {
        let timestamp = UserDefaults.standard.double(forKey: powerBoostExpiryKey)
        guard timestamp > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}
