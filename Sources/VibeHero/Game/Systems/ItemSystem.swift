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

enum ItemRarity: Int, CaseIterable, Comparable, Codable {
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

enum EquipmentSlot: String, CaseIterable, Codable {
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

struct EquipmentDrop: Equatable {
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

enum EquipmentOutcome: Equatable {
    case equipped(EquipmentDrop)
    case salvaged(EquipmentDrop, gold: Int)
}

struct LootDrop {
    let kind: LootKind
    let amount: Int
    var equipment: EquipmentDrop?
    var equipmentOutcome: EquipmentOutcome?
    var actualHealedHP: Double?
}

enum EquipmentUpgradeStatus: Equatable {
    case available, empty, maxed, insufficientGold
}

struct EquipmentUpgradeOffer {
    let slot: EquipmentSlot
    let currentRarity: ItemRarity?
    let nextRarity: ItemRarity?
    let cost: Int?
    let balance: Int
    let status: EquipmentUpgradeStatus
}

enum EquipmentUpgradeResult: Equatable {
    case upgraded(EquipmentDrop, cost: Int)
    case empty
    case maxed
    case insufficientGold(required: Int, available: Int)
}

enum RewardKind: String, Codable {
    case healthPotion, powerBoost, gold, bossGold
    case equipmentEquipped, equipmentSalvaged, equipmentUpgraded
}

/// Persist facts, never localized display strings. HP keeps its fractional
/// value separately from exact integer gold amounts and upgrade prices.
struct RewardRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let kind: RewardKind
    let amount: Int
    var slot: EquipmentSlot?
    var rarity: ItemRarity?
    var previousRarity: ItemRarity?
    var healedHP: Double?
}

extension Notification.Name {
    static let vibeHeroInventoryChanged = Notification.Name(DefaultsKey.prefix + "inventoryChanged")
}

private struct InventoryState: Codable, Equatable {
    var version = 1
    var gold = 0
    var equipment: [String: Int] = [:]
    var powerBoostExpiry: Double = 0
    var history: [RewardRecord] = []
}

enum ItemSystem {

    static let powerBoostMultiplier: CGFloat = 1.25
    static let powerBoostDuration: TimeInterval = 60

    static func rollDrop(
        isBoss: Bool = false,
        emptyDropRescueChance: CGFloat = 0,
        roll: Int? = nil,
        rescueRoll: Double? = nil
    ) -> LootDrop? {
        if isBoss {
            let drop = EquipmentDrop(slot: rollSlot(), rarity: rollRarity(minimum: .rare))
            return LootDrop(kind: .equipment, amount: drop.bonusPercent, equipment: drop)
        }

        var selectedRoll = roll ?? Int.random(in: 0..<100)
        // Preserve the normal 84% loot table. The skill gets one chance to
        // replace only an empty result with a guaranteed real reward.
        if selectedRoll >= 84 {
            let chance = emptyDropRescueChance.isFinite ? min(1, max(0, emptyDropRescueChance)) : 0
            guard (rescueRoll ?? Double.random(in: 0..<1)) < Double(chance) else { return nil }
            selectedRoll = Int.random(in: 0..<84)
        }
        switch selectedRoll {
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
        read { rarity(for: slot, in: $0) }
    }

    static func equippedDrop(for slot: EquipmentSlot) -> EquipmentDrop? {
        equippedRarity(for: slot).map { EquipmentDrop(slot: slot, rarity: $0) }
    }

    static func awardEquipment(
        _ drop: EquipmentDrop, goldMultiplier: CGFloat = 1, now: Date = Date()
    ) -> EquipmentOutcome {
        mutate { state in
            let current = rarity(for: drop.slot, in: state)
            if let current, current >= drop.rarity {
                let awarded = creditGold(drop.rarity.salvageGold, multiplier: goldMultiplier, in: &state)
                appendReward(.equipmentSalvaged, amount: awarded, slot: drop.slot,
                             rarity: drop.rarity, previousRarity: current, now: now, to: &state)
                return .salvaged(drop, gold: awarded)
            }
            state.equipment[drop.slot.rawValue] = drop.rarity.rawValue
            appendReward(.equipmentEquipped, amount: 0, slot: drop.slot,
                         rarity: drop.rarity, previousRarity: current, now: now, to: &state)
            return .equipped(drop)
        }
    }

    static func upgradeOffer(for slot: EquipmentSlot) -> EquipmentUpgradeOffer {
        read { upgradeOffer(for: slot, in: $0) }
    }

    @discardableResult
    static func upgradeEquipment(in slot: EquipmentSlot, now: Date = Date()) -> EquipmentUpgradeResult {
        mutate { state in
            // Re-evaluate against the same locked snapshot that is debited;
            // an offer displayed by a settings panel is only a preview.
            let offer = upgradeOffer(for: slot, in: state)
            switch offer.status {
            case .empty: return .empty
            case .maxed: return .maxed
            case .insufficientGold:
                return .insufficientGold(required: offer.cost!, available: state.gold)
            case .available:
                let cost = offer.cost!
                let next = offer.nextRarity!
                state.gold -= cost
                state.equipment[slot.rawValue] = next.rawValue
                appendReward(.equipmentUpgraded, amount: cost, slot: slot, rarity: next,
                             previousRarity: offer.currentRarity, now: now, to: &state)
                return .upgraded(EquipmentDrop(slot: slot, rarity: next), cost: cost)
            }
        }
    }

    private static func upgradeOffer(for slot: EquipmentSlot, in state: InventoryState) -> EquipmentUpgradeOffer {
        let current = rarity(for: slot, in: state)
        let next = current.flatMap { ItemRarity(rawValue: $0.rawValue + 1) }
        let cost = next.map { _ in 30 << (current!.rawValue - 1) }
        let status: EquipmentUpgradeStatus
        if current == nil { status = .empty }
        else if next == nil { status = .maxed }
        else if state.gold < cost! { status = .insufficientGold }
        else { status = .available }
        return EquipmentUpgradeOffer(slot: slot, currentRarity: current, nextRarity: next,
                                     cost: cost, balance: state.gold, status: status)
    }

    private static func rarity(for slot: EquipmentSlot, in state: InventoryState) -> ItemRarity? {
        state.equipment[slot.rawValue].flatMap(ItemRarity.init(rawValue:))
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

    // MARK: - Gold and reward history

    static var gold: Int { read { $0.gold } }
    static var recentRewards: [RewardRecord] { read { $0.history } }

    @discardableResult
    static func addGold(
        _ amount: Int, multiplier: CGFloat = 1, kind: RewardKind = .gold, now: Date = Date()
    ) -> Int {
        guard amount > 0 else { return 0 }
        return mutate { state in
            let awarded = creditGold(amount, multiplier: multiplier, in: &state)
            appendReward(kind == .bossGold ? .bossGold : .gold, amount: awarded, now: now, to: &state)
            return awarded
        }
    }

    /// The caller applies healing to the hero, then supplies the actual HP
    /// difference. A potion at full HP is still a consumed reward worth 0 HP.
    static func recordHealing(_ amount: Double, now: Date = Date()) {
        guard amount.isFinite, amount >= 0 else { return }
        mutate { state in
            appendReward(.healthPotion, amount: amount >= Double(Int.max) ? Int.max : Int(amount),
                         healedHP: amount, now: now, to: &state)
        }
    }

    private static func creditGold(_ amount: Int, multiplier: CGFloat, in state: inout InventoryState) -> Int {
        let factor = multiplier.isFinite ? max(0, multiplier) : 1
        let scaled = (CGFloat(max(0, amount)) * factor).rounded()
        // Keep an unmodified integer award exact beyond Double's 53-bit range.
        let proposed = factor == 1 ? max(0, amount) : (scaled >= CGFloat(Int.max) ? Int.max : Int(scaled))
        let awarded = min(proposed, Int.max - state.gold)
        state.gold += awarded
        return awarded
    }

    // MARK: - Power Boost

    @discardableResult
    static func activatePowerBoost(now: Date = Date()) -> Int {
        mutate { state in
            let timestamp = validDate(now).timeIntervalSince1970
            let base = state.powerBoostExpiry > 0 ? max(timestamp, state.powerBoostExpiry) : timestamp
            let expiry = min(Date.distantFuture.timeIntervalSince1970, base + powerBoostDuration)
            let added = Int(max(0, expiry - base))
            state.powerBoostExpiry = max(base, expiry)
            appendReward(.powerBoost, amount: added, now: now, to: &state)
            return added
        }
    }

    static func powerBoostRemaining(now: Date = Date()) -> Int {
        read { state in
            guard state.powerBoostExpiry > 0 else { return 0 }
            let remaining = max(0, ceil(state.powerBoostExpiry - validDate(now).timeIntervalSince1970))
            return remaining >= Double(Int.max) ? Int.max : Int(remaining)
        }
    }

    static func damageMultiplier(now: Date = Date()) -> CGFloat {
        powerBoostRemaining(now: now) > 0 ? powerBoostMultiplier : 1
    }

    // MARK: - Atomic inventory persistence

    private static func read<T>(_ body: (InventoryState) -> T) -> T {
        Defaults.transaction { body(load(from: $0)) }
    }

    private static func mutate<T>(_ body: (inout InventoryState) -> T) -> T {
        let (result, changed) = Defaults.transaction { store in
            var state = load(from: store)
            let before = state
            let result = body(&state)
            let changed = state != before
            if changed { save(state, to: store) }
            return (result, changed)
        }
        if changed {
            NotificationCenter.default.post(name: .vibeHeroInventoryChanged, object: nil)
        }
        return result
    }

    private static func load(from store: UserDefaults) -> InventoryState {
        if store.object(forKey: DefaultsKey.inventoryState) != nil {
            // Presence is the migration boundary. A damaged new save must not
            // resurrect spent gold or replaced equipment from legacy backups.
            guard let encoded = store.string(forKey: DefaultsKey.inventoryState),
                  let data = encoded.data(using: .utf8),
                  var state = try? JSONDecoder().decode(InventoryState.self, from: data),
                  state.version == 1 else { return InventoryState() }
            state.gold = max(0, state.gold)
            state.equipment = state.equipment.filter {
                EquipmentSlot(rawValue: $0.key) != nil && ItemRarity(rawValue: $0.value) != nil
            }
            state.powerBoostExpiry = validExpiry(state.powerBoostExpiry)
            state.history = Array(state.history.filter {
                $0.amount >= 0 && $0.timestamp.timeIntervalSince1970.isFinite
                    && ($0.healedHP == nil || ($0.healedHP!.isFinite && $0.healedHP! >= 0))
            }.prefix(40))
            return state
        }

        var migrated = InventoryState()
        migrated.gold = max(0, store.integer(forKey: DefaultsKey.inventoryGold))
        for slot in EquipmentSlot.allCases {
            let raw = store.integer(forKey: DefaultsKey.equipment(slot: slot.rawValue))
            if ItemRarity(rawValue: raw) != nil { migrated.equipment[slot.rawValue] = raw }
        }
        let expiry = store.double(forKey: DefaultsKey.powerBoostExpiry)
        migrated.powerBoostExpiry = validExpiry(expiry)
        // The old keys remain backup data. Every later transaction uses this
        // one value, so gold, gear, buff expiry and history cannot be half-saved.
        save(migrated, to: store)
        return migrated
    }

    private static func save(_ state: InventoryState, to store: UserDefaults) {
        do {
            let data = try JSONEncoder().encode(state)
            store.set(String(decoding: data, as: UTF8.self), forKey: DefaultsKey.inventoryState)
        } catch {
            // All external numeric/date inputs are validated before mutation;
            // an encoder failure is a programming error, never a paid purchase.
            preconditionFailure("Cannot encode validated inventory: \(error)")
        }
    }

    private static func appendReward(
        _ kind: RewardKind, amount: Int, slot: EquipmentSlot? = nil,
        rarity: ItemRarity? = nil, previousRarity: ItemRarity? = nil,
        healedHP: Double? = nil, now: Date, to state: inout InventoryState
    ) {
        state.history.insert(RewardRecord(id: UUID(), timestamp: validDate(now), kind: kind,
            amount: amount, slot: slot, rarity: rarity, previousRarity: previousRarity,
            healedHP: healedHP), at: 0)
        if state.history.count > 40 { state.history.removeLast(state.history.count - 40) }
    }

    private static func validDate(_ date: Date) -> Date {
        guard date.timeIntervalSince1970.isFinite else { return Date() }
        return min(Date.distantFuture, max(Date.distantPast, date))
    }

    private static func validExpiry(_ timestamp: Double) -> Double {
        timestamp.isFinite ? min(Date.distantFuture.timeIntervalSince1970, max(0, timestamp)) : 0
    }
}
