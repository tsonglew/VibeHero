import AppKit

enum HeroSkill: String, CaseIterable {
    case pulseBlade
    case tokenVolley
    case arcBurst
    case wraithMark
    case novaStorm
    case overclockCore

    var name: String {
        switch self {
        case .pulseBlade: L10n.text(.skillPulseBladeName)
        case .tokenVolley: L10n.text(.skillTokenVolleyName)
        case .arcBurst: L10n.text(.skillArcBurstName)
        case .wraithMark: L10n.text(.skillWraithMarkName)
        case .novaStorm: L10n.text(.skillNovaStormName)
        case .overclockCore: L10n.text(.skillOverclockCoreName)
        }
    }

    var unlockLevel: Int {
        switch self {
        case .pulseBlade: 1
        case .tokenVolley: 2
        case .arcBurst: 3
        case .wraithMark: 3
        case .novaStorm: 5
        case .overclockCore: 7
        }
    }

    var maxRank: Int {
        switch self {
        case .pulseBlade, .tokenVolley, .arcBurst, .wraithMark: 3
        case .novaStorm, .overclockCore: 2
        }
    }

    var treeTier: Int {
        switch self {
        case .pulseBlade: 1
        case .tokenVolley: 2
        case .arcBurst, .wraithMark: 3
        case .novaStorm: 4
        case .overclockCore: 5
        }
    }

    var castEnergyRequirement: Int {
        switch self {
        case .pulseBlade: 12_000
        case .tokenVolley: 16_000
        case .arcBurst: 20_000
        case .wraithMark: 24_000
        case .novaStorm: 32_000
        case .overclockCore: 40_000
        }
    }

    var castCooldown: TimeInterval {
        switch self {
        case .pulseBlade: 14
        case .tokenVolley: 16
        case .arcBurst: 18
        case .wraithMark: 20
        case .novaStorm: 24
        case .overclockCore: 28
        }
    }

    var prerequisites: [(skill: HeroSkill, rank: Int)] {
        switch self {
        case .pulseBlade:
            []
        case .tokenVolley:
            [(.pulseBlade, 1)]
        case .arcBurst:
            [(.tokenVolley, 1)]
        case .wraithMark:
            [(.pulseBlade, 2)]
        case .novaStorm:
            [(.arcBurst, 2), (.wraithMark, 1)]
        case .overclockCore:
            [(.novaStorm, 1), (.tokenVolley, 2)]
        }
    }

    var summary: String {
        switch self {
        case .pulseBlade: L10n.text(.skillPulseBladeSummary)
        case .tokenVolley: L10n.text(.skillTokenVolleySummary)
        case .arcBurst: L10n.text(.skillArcBurstSummary)
        case .wraithMark: L10n.text(.skillWraithMarkSummary)
        case .novaStorm: L10n.text(.skillNovaStormSummary)
        case .overclockCore: L10n.text(.skillOverclockCoreSummary)
        }
    }

    var effectText: String {
        switch self {
        case .pulseBlade: L10n.text(.skillPulseBladeEffect)
        case .tokenVolley: L10n.text(.skillTokenVolleyEffect)
        case .arcBurst: L10n.text(.skillArcBurstEffect)
        case .wraithMark: L10n.text(.skillWraithMarkEffect)
        case .novaStorm: L10n.text(.skillNovaStormEffect)
        case .overclockCore: L10n.text(.skillOverclockCoreEffect)
        }
    }

    var lockedText: String {
        L10n.string(.unlocksAtLevel, unlockLevel)
    }

    var requirementText: String {
        let levelText = "LV \(unlockLevel)"
        guard !prerequisites.isEmpty else {
            return levelText
        }

        let prereqText = prerequisites
            .map { "\($0.skill.name) R\($0.rank)" }
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

enum SkillProgress {
    private static let heroLevelKey = "VibeHero.currentHeroLevel"
    private static let skillKeyPrefix = "VibeHero.skill."
    private static let autoCastKeyPrefix = "VibeHero.skillAutoCast."

    static func saveHeroLevel(_ level: Int) {
        UserDefaults.standard.set(max(0, level), forKey: heroLevelKey)
    }

    static func loadHeroLevel() -> Int {
        max(0, UserDefaults.standard.integer(forKey: heroLevelKey))
    }

    static func rank(for skill: HeroSkill) -> Int {
        min(max(0, UserDefaults.standard.integer(forKey: key(for: skill))), skill.maxRank)
    }

    static func setRank(_ rank: Int, for skill: HeroSkill) {
        let clampedRank = min(max(0, rank), skill.maxRank)
        UserDefaults.standard.set(clampedRank, forKey: key(for: skill))
    }

    static func availablePoints(heroLevel: Int = loadHeroLevel()) -> Int {
        max(0, heroLevel - spentPoints())
    }

    static func spentPoints() -> Int {
        HeroSkill.allCases.reduce(0) { $0 + rank(for: $1) }
    }

    static func canUpgrade(_ skill: HeroSkill, heroLevel: Int = loadHeroLevel()) -> Bool {
        heroLevel >= skill.unlockLevel &&
            prerequisitesMet(for: skill) &&
            rank(for: skill) < skill.maxRank &&
            availablePoints(heroLevel: heroLevel) > 0
    }

    @discardableResult
    static func upgrade(_ skill: HeroSkill, heroLevel: Int = loadHeroLevel()) -> Bool {
        guard canUpgrade(skill, heroLevel: heroLevel) else {
            return false
        }

        setRank(rank(for: skill) + 1, for: skill)
        return true
    }

    static func damageMultiplier() -> CGFloat {
        let pulseBonus = CGFloat(rank(for: .pulseBlade)) * 0.05
        let volleyBonus = CGFloat(rank(for: .tokenVolley)) * 0.04
        let markBonus = CGFloat(rank(for: .wraithMark)) * 0.06
        let arcBonus = CGFloat(rank(for: .arcBurst)) * 0.03
        let novaBonus = CGFloat(rank(for: .novaStorm)) * 0.07
        let coreBonus = CGFloat(rank(for: .overclockCore)) * 0.04
        return 1 + pulseBonus + volleyBonus + markBonus + arcBonus + novaBonus + coreBonus
    }

    static func loadout() -> SkillLoadout {
        SkillLoadout(
            pulseBlade: rank(for: .pulseBlade),
            tokenVolley: rank(for: .tokenVolley),
            arcBurst: rank(for: .arcBurst),
            wraithMark: rank(for: .wraithMark),
            novaStorm: rank(for: .novaStorm),
            overclockCore: rank(for: .overclockCore)
        )
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

        let defaults = UserDefaults.standard
        let key = autoCastKey(for: skill)
        guard defaults.object(forKey: key) != nil else {
            return true
        }

        return defaults.bool(forKey: key)
    }

    static func setAutoCastEnabled(_ enabled: Bool, for skill: HeroSkill) {
        UserDefaults.standard.set(enabled, forKey: autoCastKey(for: skill))
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

    private static func prerequisitesMet(for skill: HeroSkill) -> Bool {
        skill.prerequisites.allSatisfy { rank(for: $0.skill) >= $0.rank }
    }

    private static func key(for skill: HeroSkill) -> String {
        skillKeyPrefix + skill.rawValue
    }

    private static func autoCastKey(for skill: HeroSkill) -> String {
        autoCastKeyPrefix + skill.rawValue
    }
}

struct SkillLoadout: Equatable {
    let pulseBlade: Int
    let tokenVolley: Int
    let arcBurst: Int
    let wraithMark: Int
    let novaStorm: Int
    let overclockCore: Int

    var totalRanks: Int {
        pulseBlade + tokenVolley + arcBurst + wraithMark + novaStorm + overclockCore
    }

    func rank(for skill: HeroSkill) -> Int {
        switch skill {
        case .pulseBlade: pulseBlade
        case .tokenVolley: tokenVolley
        case .arcBurst: arcBurst
        case .wraithMark: wraithMark
        case .novaStorm: novaStorm
        case .overclockCore: overclockCore
        }
    }

    static let empty = SkillLoadout(
        pulseBlade: 0,
        tokenVolley: 0,
        arcBurst: 0,
        wraithMark: 0,
        novaStorm: 0,
        overclockCore: 0
    )
}
