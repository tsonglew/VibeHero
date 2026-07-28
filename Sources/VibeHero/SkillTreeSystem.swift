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
    let name: String
    let description: String
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
    case attackSpeed(base: CGFloat, perLevel: CGFloat)
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
        guard level > 0 else { return 0 }
        switch self {
        case .damageMultiplier(let base, let perLevel),
             .critChance(let base, let perLevel),
             .attackSpeed(let base, let perLevel),
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

    var description: String {
        switch self {
        case .damageMultiplier: return L10n.text(.effectDamageMultiplier)
        case .critChance: return L10n.text(.effectCritChance)
        case .attackSpeed: return L10n.text(.effectAttackSpeed)
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
            name: L10n.text(.nodeAttackPower1),
            description: L10n.text(.nodeAttackPower1Desc),
            category: .attack,
            maxLevel: 5,
            unlockHeroLevel: 1,
            parentIDs: [],
            position: CGPoint(x: 0.5, y: 0.9),
            effect: .damageMultiplier(base: 1.05, perLevel: 0.03)
        ),
        SkillTreeNode(
            id: "atk_power_2",
            name: L10n.text(.nodeAttackPower2),
            description: L10n.text(.nodeAttackPower2Desc),
            category: .attack,
            maxLevel: 5,
            unlockHeroLevel: 3,
            parentIDs: ["atk_power_1"],
            position: CGPoint(x: 0.5, y: 0.75),
            effect: .damageMultiplier(base: 1.08, perLevel: 0.04)
        ),
        SkillTreeNode(
            id: "atk_crit_1",
            name: L10n.text(.nodeCritChance1),
            description: L10n.text(.nodeCritChance1Desc),
            category: .attack,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["atk_power_1"],
            position: CGPoint(x: 0.3, y: 0.75),
            effect: .critChance(base: 0.02, perLevel: 0.02)
        ),
        SkillTreeNode(
            id: "atk_speed_1",
            name: L10n.text(.nodeAttackSpeed1),
            description: L10n.text(.nodeAttackSpeed1Desc),
            category: .attack,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["atk_power_1"],
            position: CGPoint(x: 0.7, y: 0.75),
            effect: .attackSpeed(base: 1.05, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "atk_mastery",
            name: L10n.text(.nodeAttackMastery),
            description: L10n.text(.nodeAttackMasteryDesc),
            category: .attack,
            maxLevel: 3,
            unlockHeroLevel: 5,
            parentIDs: ["atk_power_2", "atk_crit_1"],
            position: CGPoint(x: 0.4, y: 0.6),
            effect: .damageMultiplier(base: 1.15, perLevel: 0.08)
        ),
        SkillTreeNode(
            id: "atk_berserk",
            name: L10n.text(.nodeBerserk),
            description: L10n.text(.nodeBerserkDesc),
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
            name: L10n.text(.nodeHPBonus1),
            description: L10n.text(.nodeHPBonus1Desc),
            category: .defense,
            maxLevel: 5,
            unlockHeroLevel: 1,
            parentIDs: [],
            position: CGPoint(x: 0.5, y: 0.9),
            effect: .maxHPBonus(base: 1.1, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "def_armor_1",
            name: L10n.text(.nodeArmor1),
            description: L10n.text(.nodeArmor1Desc),
            category: .defense,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["def_hp_1"],
            position: CGPoint(x: 0.3, y: 0.75),
            effect: .damageReduction(base: 0.05, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "def_regen_1",
            name: L10n.text(.nodeHPRegen1),
            description: L10n.text(.nodeHPRegen1Desc),
            category: .defense,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["def_hp_1"],
            position: CGPoint(x: 0.7, y: 0.75),
            effect: .hpRegen(base: 0.001, perLevel: 0.001)
        ),
        SkillTreeNode(
            id: "def_hp_2",
            name: L10n.text(.nodeHPBonus2),
            description: L10n.text(.nodeHPBonus2Desc),
            category: .defense,
            maxLevel: 5,
            unlockHeroLevel: 4,
            parentIDs: ["def_hp_1"],
            position: CGPoint(x: 0.5, y: 0.75),
            effect: .maxHPBonus(base: 1.15, perLevel: 0.06)
        ),
        SkillTreeNode(
            id: "def_vitality",
            name: L10n.text(.nodeVitality),
            description: L10n.text(.nodeVitalityDesc),
            category: .defense,
            maxLevel: 3,
            unlockHeroLevel: 6,
            parentIDs: ["def_hp_2", "def_armor_1"],
            position: CGPoint(x: 0.4, y: 0.6),
            effect: .maxHPBonus(base: 1.25, perLevel: 0.1)
        ),
        SkillTreeNode(
            id: "def_immortal",
            name: L10n.text(.nodeImmortal),
            description: L10n.text(.nodeImmortalDesc),
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
            name: L10n.text(.nodeGoldBonus1),
            description: L10n.text(.nodeGoldBonus1Desc),
            category: .economy,
            maxLevel: 5,
            unlockHeroLevel: 1,
            parentIDs: [],
            position: CGPoint(x: 0.5, y: 0.9),
            effect: .goldMultiplier(base: 1.1, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "eco_loot_1",
            name: L10n.text(.nodeLootChance1),
            description: L10n.text(.nodeLootChance1Desc),
            category: .economy,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["eco_gold_1"],
            position: CGPoint(x: 0.3, y: 0.75),
            effect: .lootChance(base: 0.05, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "eco_xp_1",
            name: L10n.text(.nodeXPBonus1),
            description: L10n.text(.nodeXPBonus1Desc),
            category: .economy,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["eco_gold_1"],
            position: CGPoint(x: 0.7, y: 0.75),
            effect: .xpMultiplier(base: 1.1, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "eco_gold_2",
            name: L10n.text(.nodeGoldBonus2),
            description: L10n.text(.nodeGoldBonus2Desc),
            category: .economy,
            maxLevel: 5,
            unlockHeroLevel: 4,
            parentIDs: ["eco_gold_1"],
            position: CGPoint(x: 0.5, y: 0.75),
            effect: .goldMultiplier(base: 1.2, perLevel: 0.08)
        ),
        SkillTreeNode(
            id: "eco_midas",
            name: L10n.text(.nodeMidas),
            description: L10n.text(.nodeMidasDesc),
            category: .economy,
            maxLevel: 3,
            unlockHeroLevel: 6,
            parentIDs: ["eco_gold_2", "eco_loot_1"],
            position: CGPoint(x: 0.4, y: 0.6),
            effect: .goldMultiplier(base: 1.5, perLevel: 0.15)
        ),
        SkillTreeNode(
            id: "eco_jackpot",
            name: L10n.text(.nodeJackpot),
            description: L10n.text(.nodeJackpotDesc),
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
            name: L10n.text(.nodeCooldownReduction1),
            description: L10n.text(.nodeCooldownReduction1Desc),
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 1,
            parentIDs: [],
            position: CGPoint(x: 0.5, y: 0.9),
            effect: .skillCooldownReduction(base: 0.9, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "abi_power_1",
            name: L10n.text(.nodeSkillPower1),
            description: L10n.text(.nodeSkillPower1Desc),
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["abi_cd_1"],
            position: CGPoint(x: 0.3, y: 0.75),
            effect: .skillDamageBoost(base: 1.1, perLevel: 0.08)
        ),
        SkillTreeNode(
            id: "abi_energy_1",
            name: L10n.text(.nodeEnergyRegen1),
            description: L10n.text(.nodeEnergyRegen1Desc),
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 2,
            parentIDs: ["abi_cd_1"],
            position: CGPoint(x: 0.7, y: 0.75),
            effect: .energyRegen(base: 1.1, perLevel: 0.1)
        ),
        SkillTreeNode(
            id: "abi_cd_2",
            name: L10n.text(.nodeCooldownReduction2),
            description: L10n.text(.nodeCooldownReduction2Desc),
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 4,
            parentIDs: ["abi_cd_1"],
            position: CGPoint(x: 0.5, y: 0.75),
            effect: .skillCooldownReduction(base: 0.85, perLevel: 0.05)
        ),
        SkillTreeNode(
            id: "abi_mastery",
            name: L10n.text(.nodeAbilityMastery),
            description: L10n.text(.nodeAbilityMasteryDesc),
            category: .ability,
            maxLevel: 3,
            unlockHeroLevel: 7,
            parentIDs: ["abi_cd_2", "abi_power_1"],
            position: CGPoint(x: 0.4, y: 0.6),
            effect: .skillDamageBoost(base: 1.3, perLevel: 0.12)
        ),
        SkillTreeNode(
            id: "abi_arcane",
            name: L10n.text(.nodeArcanePower),
            description: L10n.text(.nodeArcanePowerDesc),
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

// MARK: - Skill Tree Progress

enum SkillTreeProgress {
    private static let nodeKeyPrefix = "VibeHero.skillTree.node."
    private static let skillPointsKey = "VibeHero.skillTree.availablePoints"

    static func level(for nodeID: String) -> Int {
        UserDefaults.standard.integer(forKey: nodeKeyPrefix + nodeID)
    }

    static func setLevel(_ level: Int, for nodeID: String) {
        UserDefaults.standard.set(max(0, level), forKey: nodeKeyPrefix + nodeID)
    }

    static func isNodeUnlocked(_ nodeID: String) -> Bool {
        guard let node = SkillTreeData.node(byID: nodeID) else { return false }

        // Check hero level requirement
        let heroLevel = SkillProgress.loadHeroLevel()
        guard heroLevel >= node.unlockHeroLevel else { return false }

        // Check parent nodes
        for parentID in node.parentIDs {
            if level(for: parentID) == 0 {
                return false
            }
        }

        return true
    }

    static func canUpgradeNode(_ nodeID: String) -> Bool {
        guard let node = SkillTreeData.node(byID: nodeID) else { return false }

        // Must be unlocked
        guard isNodeUnlocked(nodeID) else { return false }

        // Must not be maxed
        guard level(for: nodeID) < node.maxLevel else { return false }

        // Must have available points
        return availablePoints() > 0
    }

    @discardableResult
    static func upgradeNode(_ nodeID: String) -> Bool {
        guard canUpgradeNode(nodeID) else { return false }

        let current = level(for: nodeID)
        setLevel(current + 1, for: nodeID)
        return true
    }

    @discardableResult
    static func downgradeNode(_ nodeID: String) -> Bool {
        let current = level(for: nodeID)
        guard current > 0 else { return false }

        // Check if any child nodes would become invalid
        let children = SkillTreeData.allNodes.filter { $0.parentIDs.contains(nodeID) }
        for child in children {
            if level(for: child.id) > 0 {
                // Cannot downgrade if child has points
                return false
            }
        }

        setLevel(current - 1, for: nodeID)
        return true
    }

    static func availablePoints() -> Int {
        let heroLevel = SkillProgress.loadHeroLevel()
        let spent = SkillTreeData.allNodes.reduce(0) { $0 + level(for: $1.id) }
        return max(0, heroLevel - spent)
    }

    static func totalSpentPoints() -> Int {
        SkillTreeData.allNodes.reduce(0) { $0 + level(for: $1.id) }
    }

    // MARK: - Effect Calculations

    static func totalEffect(for category: SkillTreeCategory) -> [NodeEffect: CGFloat] {
        let nodes = SkillTreeData.nodes(for: category)
        var effects: [NodeEffect: CGFloat] = [:]

        for node in nodes {
            let level = level(for: node.id)
            guard level > 0 else { continue }

            let value = node.effect.value(at: level)
            effects[node.effect] = (effects[node.effect] ?? 0) + value
        }

        return effects
    }

    static func damageMultiplier() -> CGFloat {
        let attackNodes = SkillTreeData.nodes(for: .attack)
        var multiplier: CGFloat = 1.0

        for node in attackNodes {
            if case .damageMultiplier = node.effect {
                multiplier *= node.effect.value(at: level(for: node.id))
            }
        }

        return multiplier
    }

    static func critChanceBonus() -> CGFloat {
        let attackNodes = SkillTreeData.nodes(for: .attack)
        var bonus: CGFloat = 0

        for node in attackNodes {
            if case .critChance = node.effect {
                bonus += node.effect.value(at: level(for: node.id))
            }
        }

        return bonus
    }

    static func maxHPBonus() -> CGFloat {
        let defenseNodes = SkillTreeData.nodes(for: .defense)
        var bonus: CGFloat = 1.0

        for node in defenseNodes {
            if case .maxHPBonus = node.effect {
                bonus *= node.effect.value(at: level(for: node.id))
            }
        }

        return bonus
    }

    static func goldMultiplier() -> CGFloat {
        let ecoNodes = SkillTreeData.nodes(for: .economy)
        var multiplier: CGFloat = 1.0

        for node in ecoNodes {
            if case .goldMultiplier = node.effect {
                multiplier *= node.effect.value(at: level(for: node.id))
            }
        }

        return multiplier
    }

    static func xpMultiplier() -> CGFloat {
        let ecoNodes = SkillTreeData.nodes(for: .economy)
        var multiplier: CGFloat = 1.0

        for node in ecoNodes {
            if case .xpMultiplier = node.effect {
                multiplier *= node.effect.value(at: level(for: node.id))
            }
        }

        return multiplier
    }

    static func skillDamageMultiplier() -> CGFloat {
        let abilityNodes = SkillTreeData.nodes(for: .ability)
        var multiplier: CGFloat = 1.0

        for node in abilityNodes {
            if case .skillDamageBoost = node.effect {
                multiplier *= node.effect.value(at: level(for: node.id))
            }
        }

        return multiplier
    }

    static func cooldownMultiplier() -> CGFloat {
        let abilityNodes = SkillTreeData.nodes(for: .ability)
        var multiplier: CGFloat = 1.0

        for node in abilityNodes {
            if case .skillCooldownReduction = node.effect {
                multiplier *= node.effect.value(at: level(for: node.id))
            }
        }

        return multiplier
    }
}
