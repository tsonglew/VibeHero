import AppKit

// MARK: - Skill Tree Categories

enum SkillTreeCategory: String, CaseIterable {
    case attack = "attack"
    case defense = "defense"
    case economy = "economy"
    case ability = "ability"

    var displayName: String {
        switch self {
        case .attack: L10n.text(.skillTreeAttack)
        case .defense: L10n.text(.skillTreeDefense)
        case .economy: L10n.text(.skillTreeEconomy)
        case .ability: L10n.text(.skillTreeAbility)
        }
    }

    var icon: String {
        switch self {
        case .attack: "⚔️"
        case .defense: "🛡️"
        case .economy: "💰"
        case .ability: "✨"
        }
    }

    var color: NSColor {
        switch self {
        case .attack: NSColor(red: 0.95, green: 0.3, blue: 0.2, alpha: 1.0)
        case .defense: NSColor(red: 0.2, green: 0.5, blue: 0.95, alpha: 1.0)
        case .economy: NSColor(red: 1.0, green: 0.8, blue: 0.1, alpha: 1.0)
        case .ability: NSColor(red: 0.6, green: 0.2, blue: 0.95, alpha: 1.0)
        }
    }
}

// MARK: - Skill Tree Node

struct SkillTreeNode: Identifiable {
    let id: String
    let nameKey: L10nKey
    let descriptionKey: L10nKey

    var name: String { L10n.text(nameKey) }
    var description: String { L10n.text(descriptionKey) }
    let category: SkillTreeCategory
    let maxLevel: Int
    let unlockHeroLevel: Int
    let parentIDs: [String]
    let position: CGPoint
    let effect: NodeEffect

    var currentLevel: Int {
        SkillTreeProgress.level(for: id)
    }

    var isUnlocked: Bool {
        SkillTreeProgress.isNodeUnlocked(id)
    }

    var canUpgrade: Bool {
        SkillTreeProgress.canUpgradeNode(id)
    }

    var isMaxed: Bool {
        currentLevel >= maxLevel
    }
}

// MARK: - Node Effects

enum NodeEffect: Hashable {
    case damageMultiplier(base: CGFloat, perLevel: CGFloat)
    case critChance(base: CGFloat, perLevel: CGFloat)
    case attackChargeMultiplier(base: CGFloat, perLevel: CGFloat)
    case maxHPBonus(base: CGFloat, perLevel: CGFloat)
    case damageReduction(base: CGFloat, perLevel: CGFloat)
    case hpRegen(base: CGFloat, perLevel: CGFloat)
    case goldMultiplier(base: CGFloat, perLevel: CGFloat)
    case lootChance(base: CGFloat, perLevel: CGFloat)
    case xpMultiplier(base: CGFloat, perLevel: CGFloat)
    case skillCooldownReduction(base: CGFloat, perLevel: CGFloat)
    case skillDamageBoost(base: CGFloat, perLevel: CGFloat)
    case energyRegen(base: CGFloat, perLevel: CGFloat)

    func value(at level: Int) -> CGFloat {
        guard level > 0 else { return neutralValue }
        switch self {
        case .damageMultiplier(let base, let perLevel),
             .critChance(let base, let perLevel),
             .attackChargeMultiplier(let base, let perLevel),
             .maxHPBonus(let base, let perLevel),
             .damageReduction(let base, let perLevel),
             .hpRegen(let base, let perLevel),
             .goldMultiplier(let base, let perLevel),
             .lootChance(let base, let perLevel),
             .xpMultiplier(let base, let perLevel),
             .skillCooldownReduction(let base, let perLevel),
             .skillDamageBoost(let base, let perLevel),
             .energyRegen(let base, let perLevel):
            return base + perLevel * CGFloat(level - 1)
        }
    }

    var neutralValue: CGFloat {
        switch self {
        case .critChance, .damageReduction, .hpRegen, .lootChance: return 0
        default: return 1
        }
    }

    /// Show player-facing changes, not internal multiplier representations.
    func formattedValue(at level: Int) -> String {
        let value = value(at: level)
        switch self {
        case .hpRegen:
            return L10n.string(.skillHPPerSecond, Double(value))
        case .skillCooldownReduction:
            return L10n.string(.skillPercentReduction, Double((1 - value) * 100))
        case .damageReduction:
            return L10n.string(.skillPercentReduction, Double(value * 100))
        default:
            let bonus = neutralValue == 1 ? value - 1 : value
            return L10n.string(.skillPercentBonus, Double(bonus * 100))
        }
    }

    var description: String {
        switch self {
        case .damageMultiplier: return L10n.text(.effectDamageMultiplier)
        case .critChance: return L10n.text(.effectCritChance)
        case .attackChargeMultiplier: return L10n.text(.effectAttackSpeed)
        case .maxHPBonus: return L10n.text(.effectMaxHP)
        case .damageReduction: return L10n.text(.effectDamageReduction)
        case .hpRegen: return L10n.text(.effectHPRegen)
        case .goldMultiplier: return L10n.text(.effectGoldMultiplier)
        case .lootChance: return L10n.text(.effectLootChance)
        case .xpMultiplier: return L10n.text(.effectXPMultiplier)
        case .skillCooldownReduction: return L10n.text(.effectCooldownReduction)
        case .skillDamageBoost: return L10n.text(.effectSkillDamage)
        case .energyRegen: return L10n.text(.effectEnergyRegen)
        }
    }
}

// MARK: - Skill Tree Data

enum SkillTreeData {
    static let allNodes: [SkillTreeNode] = [
        // MARK: Attack Branch
        SkillTreeNode(
            id: "atk_power_1",
            nameKey: .nodeAttackPower1,
            descriptionKey: .nodeAttackPower1Desc,
            category: .attack,
            maxLevel: 5,
            unlockHeroLevel: 1,
            parentIDs: [],
            position: CGPoint(x: 0.5, y: 0.9),
            effect: .damageMultiplier(base: 1.05, perLevel: 0.03)
        ),
        SkillTreeNode(
            id: "atk_power_2",
            nameKey: .nodeAttackPower2,
            descriptionKey: .nodeAttackPower2Desc,
            category: .attack,
            maxLevel: 5,
            unlockHeroLevel: 3,
            parentIDs: ["atk_power_1"],
            position: CGPoint(x: 0.5, y: 0.75),
            effect: .damageMultiplier(base: 1.08, perLevel: 0.04)
        ),
        SkillTreeNode(
            id: "atk_crit_1",
            nameKey: .nodeCritChance1,
            descriptionKey: .nodeCritChance1Desc,
            category: .attack,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["atk_power_1"],
            position: CGPoint(x: 0.3, y: 0.75),
            effect: .critChance(base: 0.02, perLevel: 0.02)
        ),
        SkillTreeNode(
            id: "atk_speed_1",
            nameKey: .nodeAttackSpeed1,
            descriptionKey: .nodeAttackSpeed1Desc,
            category: .attack,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["atk_power_1"],
            position: CGPoint(x: 0.7, y: 0.75),
            effect: .attackChargeMultiplier(base: 1.05, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "atk_mastery",
            nameKey: .nodeAttackMastery,
            descriptionKey: .nodeAttackMasteryDesc,
            category: .attack,
            maxLevel: 3,
            unlockHeroLevel: 5,
            parentIDs: ["atk_power_2", "atk_crit_1"],
            position: CGPoint(x: 0.4, y: 0.6),
            effect: .damageMultiplier(base: 1.15, perLevel: 0.08)
        ),
        SkillTreeNode(
            id: "atk_berserk",
            nameKey: .nodeBerserk,
            descriptionKey: .nodeBerserkDesc,
            category: .attack,
            maxLevel: 1,
            unlockHeroLevel: 8,
            parentIDs: ["atk_mastery", "atk_speed_1"],
            position: CGPoint(x: 0.5, y: 0.45),
            effect: .damageMultiplier(base: 1.5, perLevel: 0)
        ),

        // MARK: Defense Branch
        SkillTreeNode(
            id: "def_hp_1",
            nameKey: .nodeHPBonus1,
            descriptionKey: .nodeHPBonus1Desc,
            category: .defense,
            maxLevel: 5,
            unlockHeroLevel: 1,
            parentIDs: [],
            position: CGPoint(x: 0.5, y: 0.9),
            effect: .maxHPBonus(base: 1.1, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "def_armor_1",
            nameKey: .nodeArmor1,
            descriptionKey: .nodeArmor1Desc,
            category: .defense,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["def_hp_1"],
            position: CGPoint(x: 0.3, y: 0.75),
            effect: .damageReduction(base: 0.05, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "def_regen_1",
            nameKey: .nodeHPRegen1,
            descriptionKey: .nodeHPRegen1Desc,
            category: .defense,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["def_hp_1"],
            position: CGPoint(x: 0.7, y: 0.75),
            effect: .hpRegen(base: 0.01, perLevel: 0.01)
        ),
        SkillTreeNode(
            id: "def_hp_2",
            nameKey: .nodeHPBonus2,
            descriptionKey: .nodeHPBonus2Desc,
            category: .defense,
            maxLevel: 5,
            unlockHeroLevel: 4,
            parentIDs: ["def_hp_1"],
            position: CGPoint(x: 0.5, y: 0.75),
            effect: .maxHPBonus(base: 1.15, perLevel: 0.06)
        ),
        SkillTreeNode(
            id: "def_vitality",
            nameKey: .nodeVitality,
            descriptionKey: .nodeVitalityDesc,
            category: .defense,
            maxLevel: 3,
            unlockHeroLevel: 6,
            parentIDs: ["def_hp_2", "def_armor_1"],
            position: CGPoint(x: 0.4, y: 0.6),
            effect: .maxHPBonus(base: 1.25, perLevel: 0.1)
        ),
        SkillTreeNode(
            id: "def_immortal",
            nameKey: .nodeImmortal,
            descriptionKey: .nodeImmortalDesc,
            category: .defense,
            maxLevel: 1,
            unlockHeroLevel: 10,
            parentIDs: ["def_vitality", "def_regen_1"],
            position: CGPoint(x: 0.5, y: 0.45),
            effect: .damageReduction(base: 0.3, perLevel: 0)
        ),

        // MARK: Economy Branch
        SkillTreeNode(
            id: "eco_gold_1",
            nameKey: .nodeGoldBonus1,
            descriptionKey: .nodeGoldBonus1Desc,
            category: .economy,
            maxLevel: 5,
            unlockHeroLevel: 1,
            parentIDs: [],
            position: CGPoint(x: 0.5, y: 0.9),
            effect: .goldMultiplier(base: 1.1, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "eco_loot_1",
            nameKey: .nodeLootChance1,
            descriptionKey: .nodeLootChance1Desc,
            category: .economy,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["eco_gold_1"],
            position: CGPoint(x: 0.3, y: 0.75),
            effect: .lootChance(base: 0.05, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "eco_xp_1",
            nameKey: .nodeXPBonus1,
            descriptionKey: .nodeXPBonus1Desc,
            category: .economy,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["eco_gold_1"],
            position: CGPoint(x: 0.7, y: 0.75),
            effect: .xpMultiplier(base: 1.1, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "eco_gold_2",
            nameKey: .nodeGoldBonus2,
            descriptionKey: .nodeGoldBonus2Desc,
            category: .economy,
            maxLevel: 5,
            unlockHeroLevel: 4,
            parentIDs: ["eco_gold_1"],
            position: CGPoint(x: 0.5, y: 0.75),
            effect: .goldMultiplier(base: 1.2, perLevel: 0.08)
        ),
        SkillTreeNode(
            id: "eco_midas",
            nameKey: .nodeMidas,
            descriptionKey: .nodeMidasDesc,
            category: .economy,
            maxLevel: 3,
            unlockHeroLevel: 6,
            parentIDs: ["eco_gold_2", "eco_loot_1"],
            position: CGPoint(x: 0.4, y: 0.6),
            effect: .goldMultiplier(base: 1.5, perLevel: 0.15)
        ),
        SkillTreeNode(
            id: "eco_jackpot",
            nameKey: .nodeJackpot,
            descriptionKey: .nodeJackpotDesc,
            category: .economy,
            maxLevel: 1,
            unlockHeroLevel: 9,
            parentIDs: ["eco_midas", "eco_xp_1"],
            position: CGPoint(x: 0.5, y: 0.45),
            effect: .lootChance(base: 0.5, perLevel: 0)
        ),

        // MARK: Ability Branch
        SkillTreeNode(
            id: "abi_cd_1",
            nameKey: .nodeCooldownReduction1,
            descriptionKey: .nodeCooldownReduction1Desc,
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 1,
            parentIDs: [],
            position: CGPoint(x: 0.5, y: 0.9),
            effect: .skillCooldownReduction(base: 0.9, perLevel: -0.05)
        ),
        SkillTreeNode(
            id: "abi_power_1",
            nameKey: .nodeSkillPower1,
            descriptionKey: .nodeSkillPower1Desc,
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["abi_cd_1"],
            position: CGPoint(x: 0.3, y: 0.75),
            effect: .skillDamageBoost(base: 1.1, perLevel: 0.08)
        ),
        SkillTreeNode(
            id: "abi_energy_1",
            nameKey: .nodeEnergyRegen1,
            descriptionKey: .nodeEnergyRegen1Desc,
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["abi_cd_1"],
            position: CGPoint(x: 0.7, y: 0.75),
            effect: .energyRegen(base: 1.1, perLevel: 0.1)
        ),
        SkillTreeNode(
            id: "abi_cd_2",
            nameKey: .nodeCooldownReduction2,
            descriptionKey: .nodeCooldownReduction2Desc,
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 4,
            parentIDs: ["abi_cd_1"],
            position: CGPoint(x: 0.5, y: 0.75),
            effect: .skillCooldownReduction(base: 0.85, perLevel: -0.05)
        ),
        SkillTreeNode(
            id: "abi_mastery",
            nameKey: .nodeAbilityMastery,
            descriptionKey: .nodeAbilityMasteryDesc,
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 7,
            parentIDs: ["abi_cd_2", "abi_power_1"],
            position: CGPoint(x: 0.4, y: 0.6),
            effect: .skillDamageBoost(base: 1.3, perLevel: 0.12)
        ),
        SkillTreeNode(
            id: "abi_arcane",
            nameKey: .nodeArcanePower,
            descriptionKey: .nodeArcanePowerDesc,
            category: .ability,
            maxLevel: 1,
            unlockHeroLevel: 12,
            parentIDs: ["abi_mastery", "abi_energy_1"],
            position: CGPoint(x: 0.5, y: 0.45),
            effect: .skillCooldownReduction(base: 0.6, perLevel: 0)
        ),
    ]

    static func nodes(for category: SkillTreeCategory) -> [SkillTreeNode] {
        allNodes.filter { $0.category == category }
    }

    static func node(byID id: String) -> SkillTreeNode? {
        allNodes.first { $0.id == id }
    }
}

// MARK: - Unified Skill Progress

struct SkillModifiers: Equatable {
    var damageMultiplier: CGFloat = 1
    var critChanceBonus: CGFloat = 0
    var maxHPMultiplier: CGFloat = 1
    var damageReduction: CGFloat = 0
    var hpRegenPointsPerSecond: CGFloat = 0
    var goldMultiplier: CGFloat = 1
    var emptyDropRescueChance: CGFloat = 0
    var xpMultiplier: CGFloat = 1
    var cooldownMultiplier: CGFloat = 1
    var skillDamageMultiplier: CGFloat = 1
    var attackChargeMultiplier: CGFloat = 1
    var energyChargeMultiplier: CGFloat = 1
}

/// A single persisted document makes migration and refunds atomic. Legacy keys
/// remain untouched as a backup, but are never read after this document exists.
private struct SkillBuild: Codable {
    var nodeRanks: [String: Int] = [:]
    var activeRanks: [String: Int] = [:]
    var migrationCredit = 0
    var migrationNoticePending = false

    var spentPoints: Int {
        SkillTreeData.allNodes.reduce(0) { total, node in
            total + min(node.maxLevel, max(0, nodeRanks[node.id] ?? 0))
        } + HeroSkill.allCases.reduce(0) { total, skill in
            total + min(skill.maxRank, max(0, activeRanks[skill.rawValue] ?? 0))
        }
    }
}

enum SkillTreeProgress {
    private static var maximumMigrationCredit: Int {
        SkillTreeData.allNodes.reduce(0) { $0 + $1.maxLevel }
            + HeroSkill.allCases.reduce(0) { $0 + $1.maxRank }
    }

    private static func loadBuild() -> SkillBuild {
        if let saved = Defaults.string(forKey: DefaultsKey.skillBuild),
           let data = saved.data(using: .utf8),
           var build = try? JSONDecoder().decode(SkillBuild.self, from: data) {
            build.migrationCredit = min(maximumMigrationCredit, max(0, build.migrationCredit))
            return build
        }
        var build = SkillBuild()
        for node in SkillTreeData.allNodes {
            build.nodeRanks[node.id] = min(node.maxLevel, max(0, Defaults.int(forKey: DefaultsKey.skillTreeNode(node.id))))
        }
        for skill in HeroSkill.allCases {
            build.activeRanks[skill.rawValue] = min(skill.maxRank, max(0, Defaults.int(forKey: DefaultsKey.skillRank(skill.rawValue))))
        }
        // Older builds offered independent budgets. Preserve every valid spent
        // rank once, then use this fixed credit in the one shared budget forever.
        build.migrationCredit = max(0, build.spentPoints - SkillProgress.loadHeroLevel())
        build.migrationNoticePending = build.spentPoints > 0
        save(build)
        return build
    }

    private static func save(_ build: SkillBuild) {
        guard let data = try? JSONEncoder().encode(build), let text = String(data: data, encoding: .utf8) else { return }
        Defaults.set(text, forKey: DefaultsKey.skillBuild)
    }

    static var migrationCredit: Int { loadBuild().migrationCredit }
    static var migrationNoticePending: Bool { loadBuild().migrationNoticePending }

    static func dismissMigrationNotice() {
        var build = loadBuild()
        build.migrationNoticePending = false
        save(build)
    }

    static func level(for nodeID: String) -> Int {
        guard let node = SkillTreeData.node(byID: nodeID) else { return 0 }
        return min(node.maxLevel, max(0, loadBuild().nodeRanks[nodeID] ?? 0))
    }

    /// Low-level compatibility setter; player actions use upgrade/refund below.
    static func setLevel(_ level: Int, for nodeID: String) {
        guard let node = SkillTreeData.node(byID: nodeID) else { return }
        var build = loadBuild()
        build.nodeRanks[nodeID] = min(node.maxLevel, max(0, level))
        save(build)
    }

    static func activeRank(for skill: HeroSkill) -> Int {
        min(skill.maxRank, max(0, loadBuild().activeRanks[skill.rawValue] ?? 0))
    }

    static func setActiveRank(_ rank: Int, for skill: HeroSkill) {
        var build = loadBuild()
        build.activeRanks[skill.rawValue] = min(skill.maxRank, max(0, rank))
        save(build)
    }

    static func activeLoadout() -> SkillLoadout {
        let build = loadBuild()
        return SkillLoadout(ranks: Dictionary(uniqueKeysWithValues: HeroSkill.allCases.map {
            ($0, min($0.maxRank, max(0, build.activeRanks[$0.rawValue] ?? 0)))
        }))
    }

    static func availablePoints(heroLevel: Int = SkillProgress.loadHeroLevel()) -> Int {
        let build = loadBuild()
        let (budget, overflow) = max(0, heroLevel).addingReportingOverflow(build.migrationCredit)
        return max(0, (overflow ? Int.max : budget) - build.spentPoints)
    }

    static func totalSpentPoints() -> Int { loadBuild().spentPoints }

    static func isNodeUnlocked(_ nodeID: String) -> Bool {
        guard let node = SkillTreeData.node(byID: nodeID) else { return false }
        return SkillProgress.loadHeroLevel() >= node.unlockHeroLevel && node.parentIDs.allSatisfy { level(for: $0) > 0 }
    }

    static func canUpgradeNode(_ nodeID: String) -> Bool {
        guard let node = SkillTreeData.node(byID: nodeID) else { return false }
        return isNodeUnlocked(nodeID) && level(for: nodeID) < node.maxLevel && availablePoints() > 0
    }

    @discardableResult
    static func upgradeNode(_ nodeID: String) -> Bool {
        guard canUpgradeNode(nodeID) else { return false }
        setLevel(level(for: nodeID) + 1, for: nodeID)
        return true
    }

    static func nodeRefundBlockReason(_ nodeID: String) -> String? {
        guard level(for: nodeID) == 1 else { return nil }
        let children = SkillTreeData.allNodes.filter { $0.parentIDs.contains(nodeID) && level(for: $0.id) > 0 }
        guard !children.isEmpty else { return nil }
        return L10n.string(.skillRefundBlocked, children.map(\.name).joined(separator: ", "))
    }

    static func canDowngradeNode(_ nodeID: String) -> Bool {
        level(for: nodeID) > 0 && nodeRefundBlockReason(nodeID) == nil
    }

    @discardableResult
    static func downgradeNode(_ nodeID: String) -> Bool {
        guard canDowngradeNode(nodeID) else { return false }
        setLevel(level(for: nodeID) - 1, for: nodeID)
        return true
    }

    static func canUpgradeActive(_ skill: HeroSkill, heroLevel: Int = SkillProgress.loadHeroLevel()) -> Bool {
        heroLevel >= skill.unlockLevel && activeRank(for: skill) < skill.maxRank && availablePoints(heroLevel: heroLevel) > 0 &&
            skill.prerequisites.allSatisfy { activeRank(for: $0.skill) >= $0.rank }
    }

    @discardableResult
    static func upgradeActive(_ skill: HeroSkill, heroLevel: Int = SkillProgress.loadHeroLevel()) -> Bool {
        guard canUpgradeActive(skill, heroLevel: heroLevel) else { return false }
        setActiveRank(activeRank(for: skill) + 1, for: skill)
        return true
    }

    static func activeRefundBlockReason(_ skill: HeroSkill) -> String? {
        let next = activeRank(for: skill) - 1
        let children = HeroSkill.allCases.filter { candidate in
            activeRank(for: candidate) > 0 && candidate.prerequisites.contains { $0.skill == skill && $0.rank > next }
        }
        guard !children.isEmpty else { return nil }
        return L10n.string(.skillRefundBlocked, children.map(\.name).joined(separator: ", "))
    }

    static func canDowngradeActive(_ skill: HeroSkill) -> Bool {
        activeRank(for: skill) > 0 && activeRefundBlockReason(skill) == nil
    }

    @discardableResult
    static func downgradeActive(_ skill: HeroSkill) -> Bool {
        guard canDowngradeActive(skill) else { return false }
        setActiveRank(activeRank(for: skill) - 1, for: skill)
        return true
    }

    static func modifiers() -> SkillModifiers {
        let build = loadBuild()
        var result = SkillModifiers()
        // Legacy active ranks retain their passive damage contribution, counted
        // once here alongside the new passive tree.
        for skill in HeroSkill.allCases {
            result.damageMultiplier += CGFloat(min(skill.maxRank, max(0, build.activeRanks[skill.rawValue] ?? 0))) * skill.damageBonusPerRank
        }
        for node in SkillTreeData.allNodes {
            let rank = min(node.maxLevel, max(0, build.nodeRanks[node.id] ?? 0))
            let value = node.effect.value(at: rank)
            switch node.effect {
            case .damageMultiplier: result.damageMultiplier *= value
            case .critChance: result.critChanceBonus += value
            case .attackChargeMultiplier: result.attackChargeMultiplier *= value
            case .maxHPBonus: result.maxHPMultiplier *= value
            case .damageReduction: result.damageReduction += value
            case .hpRegen: result.hpRegenPointsPerSecond += value
            case .goldMultiplier: result.goldMultiplier *= value
            case .lootChance: result.emptyDropRescueChance += value
            case .xpMultiplier: result.xpMultiplier *= value
            case .skillCooldownReduction: result.cooldownMultiplier *= value
            case .skillDamageBoost: result.skillDamageMultiplier *= value
            case .energyRegen: result.energyChargeMultiplier *= value
            }
        }
        result.critChanceBonus = min(1, max(0, result.critChanceBonus))
        result.damageReduction = min(0.8, max(0, result.damageReduction))
        result.emptyDropRescueChance = min(1, max(0, result.emptyDropRescueChance))
        result.cooldownMultiplier = max(0.2, min(1, result.cooldownMultiplier))
        return result
    }

    // Compatibility wrappers share the same snapshot, never independent budgets.
    static func damageMultiplier() -> CGFloat { modifiers().damageMultiplier }
    static func critChanceBonus() -> CGFloat { modifiers().critChanceBonus }
    static func maxHPBonus() -> CGFloat { modifiers().maxHPMultiplier }
    static func goldMultiplier() -> CGFloat { modifiers().goldMultiplier }
    static func xpMultiplier() -> CGFloat { modifiers().xpMultiplier }
    static func skillDamageMultiplier() -> CGFloat { modifiers().skillDamageMultiplier }
    static func cooldownMultiplier() -> CGFloat { modifiers().cooldownMultiplier }
}
