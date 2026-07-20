import AppKit

enum LootKind: CaseIterable {
    case healthPotion
    case powerBoost
    case gold
    case equipment

    var name: String {
        switch self {
        case .healthPotion: L10n.text(.lootHealthPotion)
        case .powerBoost: L10n.text(.lootPowerBoost)
        case .gold: L10n.text(.lootGold)
        case .equipment: L10n.text(.lootEquipment)
        }
    }

    var color: NSColor {
        switch self {
        case .healthPotion: NSColor(red: 1.0, green: 0.25, blue: 0.34, alpha: 1)
        case .powerBoost: NSColor(red: 0.35, green: 0.92, blue: 1.0, alpha: 1)
        case .gold: NSColor(red: 1.0, green: 0.76, blue: 0.18, alpha: 1)
        case .equipment: NSColor.white.withAlphaComponent(0.9)
        }
    }
}

enum ItemRarity: Int, CaseIterable, Comparable {
    case common = 1
    case uncommon
    case rare
    case epic
    case legendary

    var name: String {
        switch self {
        case .common: L10n.text(.rarityCommon)
        case .uncommon: L10n.text(.rarityUncommon)
        case .rare: L10n.text(.rarityRare)
        case .epic: L10n.text(.rarityEpic)
        case .legendary: L10n.text(.rarityLegendary)
        }
    }

    var color: NSColor {
        switch self {
        case .common: NSColor.white.withAlphaComponent(0.88)
        case .uncommon: NSColor(red: 0.45, green: 1.0, blue: 0.55, alpha: 1)
        case .rare: NSColor(red: 0.35, green: 0.68, blue: 1.0, alpha: 1)
        case .epic: NSColor(red: 0.72, green: 0.48, blue: 1.0, alpha: 1)
        case .legendary: NSColor(red: 1.0, green: 0.72, blue: 0.24, alpha: 1)
        }
    }

    var salvageGold: Int {
        rawValue * 5
    }

    static func < (lhs: ItemRarity, rhs: ItemRarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum EquipmentSlot: String, CaseIterable {
    case weapon
    case armor
    case charm

    var name: String {
        switch self {
        case .weapon: L10n.text(.slotWeapon)
        case .armor: L10n.text(.slotArmor)
        case .charm: L10n.text(.slotCharm)
        }
    }

    func bonusPercent(for rarity: ItemRarity) -> Int {
        switch self {
        case .weapon, .armor:
            switch rarity {
            case .common: 4
            case .uncommon: 7
            case .rare: 10
            case .epic: 14
            case .legendary: 20
            }
        case .charm:
            switch rarity {
            case .common: 6
            case .uncommon: 10
            case .rare: 15
            case .epic: 20
            case .legendary: 28
            }
        }
    }

    func bonusText(for rarity: ItemRarity) -> String {
        let percent = bonusPercent(for: rarity)
        switch self {
        case .weapon: return L10n.string(.equipmentBonusWeapon, percent)
        case .armor: return L10n.string(.equipmentBonusArmor, percent)
        case .charm: return L10n.string(.equipmentBonusCharm, percent)
        }
    }
}

struct EquipmentDrop {
    let slot: EquipmentSlot
    let rarity: ItemRarity

    var bonusPercent: Int {
        slot.bonusPercent(for: rarity)
    }

    var displayName: String {
        L10n.string(.equipmentName, rarity.name, slot.name)
    }

    var summary: String {
        L10n.string(.lootEquipmentSummary, displayName, slot.bonusText(for: rarity))
    }
}

enum EquipmentOutcome {
    case equipped(EquipmentDrop)
    case salvaged(EquipmentDrop, gold: Int)
}

struct LootDrop {
    let kind: LootKind
    let amount: Int
    var equipment: EquipmentDrop?
}

enum ItemSystem {
    private static let goldKey = "NotchHero.inventory.gold"
    private static let powerBoostExpiryKey = "NotchHero.buff.powerBoostExpiry"
    private static let equipmentKeyPrefix = "NotchHero.equipment."

    static let powerBoostMultiplier: CGFloat = 1.25
    static let powerBoostDuration: TimeInterval = 60

    static func rollDrop(isBoss: Bool = false) -> LootDrop? {
        if isBoss {
            let drop = EquipmentDrop(slot: rollSlot(), rarity: rollRarity(minimum: .rare))
            return LootDrop(kind: .equipment, amount: drop.bonusPercent, equipment: drop)
        }

        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<24:
            return LootDrop(kind: .healthPotion, amount: Int.random(in: 18...32))
        case 24..<40:
            return LootDrop(kind: .powerBoost, amount: Int(powerBoostDuration))
        case 40..<68:
            return LootDrop(kind: .gold, amount: Int.random(in: 6...18))
        case 68..<84:
            let drop = EquipmentDrop(slot: rollSlot(), rarity: rollRarity())
            return LootDrop(kind: .equipment, amount: drop.bonusPercent, equipment: drop)
        default:
            return nil
        }
    }

    private static func rollSlot() -> EquipmentSlot {
        EquipmentSlot.allCases.randomElement() ?? .weapon
    }

    private static func rollRarity(minimum: ItemRarity = .common) -> ItemRarity {
        let roll = Int.random(in: 0..<100)
        let rarity: ItemRarity
        switch roll {
        case 0..<52: rarity = .common
        case 52..<78: rarity = .uncommon
        case 78..<91: rarity = .rare
        case 91..<98: rarity = .epic
        default: rarity = .legendary
        }
        return max(rarity, minimum)
    }

    // MARK: - Equipment

    static func equippedRarity(for slot: EquipmentSlot) -> ItemRarity? {
        let raw = UserDefaults.standard.integer(forKey: equipmentKeyPrefix + slot.rawValue)
        return raw > 0 ? ItemRarity(rawValue: raw) : nil
    }

    static func equippedDrop(for slot: EquipmentSlot) -> EquipmentDrop? {
        equippedRarity(for: slot).map { EquipmentDrop(slot: slot, rarity: $0) }
    }

    static func awardEquipment(_ drop: EquipmentDrop) -> EquipmentOutcome {
        let current = equippedRarity(for: drop.slot)
        if let current, current >= drop.rarity {
            addGold(drop.rarity.salvageGold)
            return .salvaged(drop, gold: drop.rarity.salvageGold)
        }

        UserDefaults.standard.set(drop.rarity.rawValue, forKey: equipmentKeyPrefix + drop.slot.rawValue)
        return .equipped(drop)
    }

    static func attackDamageMultiplier() -> CGFloat {
        guard let rarity = equippedRarity(for: .weapon) else {
            return 1
        }
        return 1 + CGFloat(EquipmentSlot.weapon.bonusPercent(for: rarity)) / 100
    }

    static func idleDamageTakenMultiplier() -> CGFloat {
        guard let rarity = equippedRarity(for: .armor) else {
            return 1
        }
        return 1 - CGFloat(EquipmentSlot.armor.bonusPercent(for: rarity)) / 100
    }

    static func skillChargeMultiplier() -> CGFloat {
        guard let rarity = equippedRarity(for: .charm) else {
            return 1
        }
        return 1 + CGFloat(EquipmentSlot.charm.bonusPercent(for: rarity)) / 100
    }

    // MARK: - Gold

    static var gold: Int {
        max(0, UserDefaults.standard.integer(forKey: goldKey))
    }

    static func addGold(_ amount: Int) {
        UserDefaults.standard.set(gold + max(0, amount), forKey: goldKey)
    }

    // MARK: - Power Boost

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
