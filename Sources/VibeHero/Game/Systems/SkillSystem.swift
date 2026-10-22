import AppKit

/// Everything that defines a hero skill.
///
/// This replaced nine parallel `switch` statements on `HeroSkill`. Adding a
/// skill is one `SkillSpec` here plus its `L10nKey`s; `SkillProgress`,
/// `SkillLoadout` and the settings UI all derive from `HeroSkill.allCases`.
struct SkillSpec {
    let nameKey: L10nKey
    let summaryKey: L10nKey
    let effectKey: L10nKey
    /// Hero level at which the skill becomes upgradable.
    let unlockLevel: Int
    let maxRank: Int
    /// Row in the skill tree UI; also the priority order for `bestCastSkill`.
    let treeTier: Int
    let castEnergyRequirement: Int
    let castCooldown: TimeInterval
    /// Ranks in other skills required before this one unlocks.
    let prerequisites: [(skill: HeroSkill, rank: Int)]
    /// Added to the outgoing damage multiplier per rank held.
    let damageBonusPerRank: CGFloat
}

enum HeroSkill: String, CaseIterable {
    case pulseBlade
    case tokenVolley
    case arcBurst
    case wraithMark
    case novaStorm
    case overclockCore

    var spec: SkillSpec { SkillCatalog.spec(for: self) }

    var name: String { L10n.text(spec.nameKey) }

    var summary: String { L10n.text(spec.summaryKey) }

    var effectText: String { L10n.text(spec.effectKey) }

    var unlockLevel: Int { spec.unlockLevel }

    var maxRank: Int { spec.maxRank }

    var treeTier: Int { spec.treeTier }

    var castEnergyRequirement: Int { spec.castEnergyRequirement }

    var castCooldown: TimeInterval { spec.castCooldown }

    var prerequisites: [(skill: HeroSkill, rank: Int)] { spec.prerequisites }

    var damageBonusPerRank: CGFloat { spec.damageBonusPerRank }

    var lockedText: String {
        L10n.string(.unlocksAtLevel, unlockLevel)
    }

    var requirementText: String {
        let levelText = L10n.string(.requiresHeroLevel, unlockLevel)
        guard !prerequisites.isEmpty else {
            return levelText
        }

        let prereqText = prerequisites
            .map { L10n.string(.requiresSkillRank, $0.skill.name, $0.rank) }
            .joined(separator: ", ")
        return "\(levelText) + \(prereqText)"
    }

    func rankText(_ rank: Int) -> String {
        if rank <= 0 {
            return L10n.text(.locked)
        }
        return L10n.string(.rank, rank, maxRank)
    }
}

enum SkillCatalog {
    static let all: [HeroSkill: SkillSpec] = [
        .pulseBlade: SkillSpec(
            nameKey: .skillPulseBladeName,
            summaryKey: .skillPulseBladeSummary,
            effectKey: .skillPulseBladeEffect,
            unlockLevel: 1,
            maxRank: 3,
            treeTier: 1,
            castEnergyRequirement: 12_000,
            castCooldown: 14,
            prerequisites: [],
            damageBonusPerRank: 0.05
        ),
        .tokenVolley: SkillSpec(
            nameKey: .skillTokenVolleyName,
            summaryKey: .skillTokenVolleySummary,
            effectKey: .skillTokenVolleyEffect,
            unlockLevel: 2,
            maxRank: 3,
            treeTier: 2,
            castEnergyRequirement: 16_000,
            castCooldown: 16,
            prerequisites: [(.pulseBlade, 1)],
            damageBonusPerRank: 0.04
        ),
        .arcBurst: SkillSpec(
            nameKey: .skillArcBurstName,
            summaryKey: .skillArcBurstSummary,
            effectKey: .skillArcBurstEffect,
            unlockLevel: 3,
            maxRank: 3,
            treeTier: 3,
            castEnergyRequirement: 20_000,
            castCooldown: 18,
            prerequisites: [(.tokenVolley, 1)],
            damageBonusPerRank: 0.03
        ),
        .wraithMark: SkillSpec(
            nameKey: .skillWraithMarkName,
            summaryKey: .skillWraithMarkSummary,
            effectKey: .skillWraithMarkEffect,
            unlockLevel: 3,
            maxRank: 3,
            treeTier: 3,
            castEnergyRequirement: 24_000,
            castCooldown: 20,
            prerequisites: [(.pulseBlade, 2)],
            damageBonusPerRank: 0.06
        ),
        .novaStorm: SkillSpec(
            nameKey: .skillNovaStormName,
            summaryKey: .skillNovaStormSummary,
            effectKey: .skillNovaStormEffect,
            unlockLevel: 5,
            maxRank: 2,
            treeTier: 4,
            castEnergyRequirement: 32_000,
            castCooldown: 24,
            prerequisites: [(.arcBurst, 2), (.wraithMark, 1)],
            damageBonusPerRank: 0.07
        ),
        .overclockCore: SkillSpec(
            nameKey: .skillOverclockCoreName,
            summaryKey: .skillOverclockCoreSummary,
            effectKey: .skillOverclockCoreEffect,
            unlockLevel: 7,
            maxRank: 2,
            treeTier: 5,
            castEnergyRequirement: 40_000,
            castCooldown: 28,
            prerequisites: [(.novaStorm, 1), (.tokenVolley, 2)],
            damageBonusPerRank: 0.04
        )
    ]

    /// The fallback only fires if `all` is missing a case, which
    /// `ContentCatalogTests` asserts cannot happen.
    static func spec(for skill: HeroSkill) -> SkillSpec {
        all[skill] ?? SkillSpec(
            nameKey: .skillPulseBladeName,
            summaryKey: .skillPulseBladeSummary,
            effectKey: .skillPulseBladeEffect,
            unlockLevel: 1,
            maxRank: 1,
            treeTier: 1,
            castEnergyRequirement: 12_000,
            castCooldown: 14,
            prerequisites: [],
            damageBonusPerRank: 0
        )
    }
}

enum SkillProgress {
    static func saveHeroLevel(_ level: Int) {
        Defaults.set(max(0, level), forKey: DefaultsKey.currentHeroLevel)
    }

    static func loadHeroLevel() -> Int {
        max(0, Defaults.int(forKey: DefaultsKey.currentHeroLevel))
    }

    static func rank(for skill: HeroSkill) -> Int {
        SkillTreeProgress.activeRank(for: skill)
    }

    static func setRank(_ rank: Int, for skill: HeroSkill) {
        SkillTreeProgress.setActiveRank(rank, for: skill)
    }

    static func availablePoints(heroLevel: Int = loadHeroLevel()) -> Int {
        SkillTreeProgress.availablePoints(heroLevel: heroLevel)
    }

    static func spentPoints() -> Int {
        SkillTreeProgress.totalSpentPoints()
    }

    static func canUpgrade(_ skill: HeroSkill, heroLevel: Int = loadHeroLevel()) -> Bool {
        SkillTreeProgress.canUpgradeActive(skill, heroLevel: heroLevel)
    }

    @discardableResult
    static func upgrade(_ skill: HeroSkill, heroLevel: Int = loadHeroLevel()) -> Bool {
        SkillTreeProgress.upgradeActive(skill, heroLevel: heroLevel)
    }

    static func canDowngrade(_ skill: HeroSkill) -> Bool {
        SkillTreeProgress.canDowngradeActive(skill)
    }

    @discardableResult
    static func downgrade(_ skill: HeroSkill) -> Bool {
        SkillTreeProgress.downgradeActive(skill)
    }

    static func damageMultiplier() -> CGFloat {
        SkillTreeProgress.modifiers().damageMultiplier
    }

    static func loadout() -> SkillLoadout {
        SkillTreeProgress.activeLoadout()
    }

    static func bestCastSkill(loadout: SkillLoadout = loadout()) -> HeroSkill? {
        HeroSkill.allCases
            .filter { loadout.rank(for: $0) > 0 }
            .sorted {
                if $0.treeTier == $1.treeTier {
                    return loadout.rank(for: $0) > loadout.rank(for: $1)
                }
                return $0.treeTier > $1.treeTier
            }
            .first
    }

    static func autoCastCandidates(loadout: SkillLoadout = loadout()) -> [HeroSkill] {
        HeroSkill.allCases.filter {
            loadout.rank(for: $0) > 0 && isAutoCastEnabled($0, loadout: loadout)
        }
    }

    static func randomCastSkill(loadout: SkillLoadout = loadout()) -> HeroSkill? {
        autoCastCandidates(loadout: loadout).randomElement()
    }

    static func isAutoCastEnabled(_ skill: HeroSkill, loadout: SkillLoadout = loadout()) -> Bool {
        guard loadout.rank(for: skill) > 0 else {
            return false
        }

        // Absent means "not yet configured", which defaults to on.
        let key = autoCastKey(for: skill)
        guard Defaults.hasValue(forKey: key) else {
            return true
        }

        return Defaults.bool(forKey: key)
    }

    static func setAutoCastEnabled(_ enabled: Bool, for skill: HeroSkill) {
        Defaults.set(enabled, forKey: autoCastKey(for: skill))
    }

    static func statusText(heroLevel: Int = loadHeroLevel()) -> String {
        let points = availablePoints(heroLevel: heroLevel)
        return points == 1 ? L10n.text(.oneSkillPointAvailable) : L10n.string(.skillPointsAvailable, points)
    }

    static func missingRequirementText(for skill: HeroSkill, heroLevel: Int = loadHeroLevel()) -> String? {
        if heroLevel < skill.unlockLevel {
            return skill.lockedText
        }

        let missing = skill.prerequisites.filter { rank(for: $0.skill) < $0.rank }
        guard !missing.isEmpty else {
            return nil
        }

        return missing
            .map { L10n.string(.requiresSkillRank, $0.skill.name, $0.rank) }
            .joined(separator: ", ")
    }

    private static func autoCastKey(for skill: HeroSkill) -> String {
        DefaultsKey.skillAutoCast(skill.rawValue)
    }
}

/// A snapshot of every skill's rank.
///
/// Dictionary-backed rather than one stored property per skill, so adding a
/// `HeroSkill` case needs no change here — it used to require edits to the
/// stored properties, the initializer, `totalRanks`, `rank(for:)` and `.empty`.
struct SkillLoadout: Equatable {
    private let ranks: [HeroSkill: Int]

    init(ranks: [HeroSkill: Int]) {
        self.ranks = ranks
    }

    var totalRanks: Int {
        ranks.values.reduce(0, +)
    }

    func rank(for skill: HeroSkill) -> Int {
        ranks[skill] ?? 0
    }

    static let empty = SkillLoadout(ranks: [:])
}
