import AppKit

/// Where the hero sits on the XP curve: absolute level plus progress toward the
/// next one.
struct LevelState {
    let level: Int
    let progress: CGFloat
    let currentXP: Int
    let requiredXP: Int
}

/// Persisted lifetime XP. Level is always derived from this via
/// `ExperienceCurve`, never stored, so the two cannot disagree.
enum HeroExperience {
    static func loadTotalXP() -> Int {
        if Defaults.hasValue(forKey: DefaultsKey.heroTotalXP) {
            return max(0, Defaults.int(forKey: DefaultsKey.heroTotalXP))
        }

        guard !Defaults.bool(forKey: DefaultsKey.heroXPInitializedFromLevel) else {
            return 0
        }

        let migratedXP = ExperienceCurve.totalXPRequired(toReach: SkillProgress.loadHeroLevel())
        saveTotalXP(migratedXP)
        Defaults.set(true, forKey: DefaultsKey.heroXPInitializedFromLevel)
        return migratedXP
    }

    static func saveTotalXP(_ totalXP: Int) {
        Defaults.set(max(0, totalXP), forKey: DefaultsKey.heroTotalXP)
    }
}

/// Hand-tuned XP requirements for the first dozen levels, then a linear ramp so
/// the curve never runs out of levels.
enum ExperienceCurve {
    private static let nextLevelRequirements = [
        120,
        260,
        450,
        700,
        1_000,
        1_360,
        1_780,
        2_260,
        2_800,
        3_400,
        4_060,
        4_780
    ]

    static func state(for totalXP: Int) -> LevelState {
        var remainingXP = max(0, totalXP)
        var level = 0
        var nextRequirement = requirementForNextLevel(from: level)

        while remainingXP >= nextRequirement {
            remainingXP -= nextRequirement
            level += 1
            nextRequirement = requirementForNextLevel(from: level)
        }

        let progress = CGFloat(remainingXP) / CGFloat(max(1, nextRequirement))
        return LevelState(
            level: level,
            progress: min(max(progress, 0), 1),
            currentXP: remainingXP,
            requiredXP: nextRequirement
        )
    }

    static func totalXPRequired(toReach level: Int) -> Int {
        guard level > 0 else {
            return 0
        }

        return (0..<level).reduce(0) { total, currentLevel in
            total + requirementForNextLevel(from: currentLevel)
        }
    }

    private static func requirementForNextLevel(from level: Int) -> Int {
        if level < nextLevelRequirements.count {
            return nextLevelRequirements[level]
        }

        let extraLevel = level - nextLevelRequirements.count + 1
        return (nextLevelRequirements.last ?? 4_780) + extraLevel * 820
    }
}
