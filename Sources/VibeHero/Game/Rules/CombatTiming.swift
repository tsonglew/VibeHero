import AppKit

enum GameStats {
    static let heroMaxHP = 100

    static func maximumHeroHP(multiplier: CGFloat) -> Int {
        guard multiplier.isFinite else { return heroMaxHP }
        return Int((CGFloat(heroMaxHP) * min(10_000, max(1, multiplier))).rounded())
    }
}

/// How long a token burst keeps the hero visibly "working" after the last
/// scanned event. Deliberately longer than one refresh interval (file-monitor
/// debounce + scan time) so the activity animation does not flicker.
enum TokenActivity {
    static let refreshInterval: TimeInterval = 2
    static let activeDuration: TimeInterval = 15

    static func expiration(now: Date, previous: Date?, didSpendTokens: Bool, latestEventAt: Date?) -> Date? {
        if didSpendTokens { return now.addingTimeInterval(activeDuration) }
        if let previous, previous > now { return previous }
        guard let latestEventAt, latestEventAt <= now else { return nil }
        let expiration = latestEventAt.addingTimeInterval(activeDuration)
        return expiration > now ? expiration : nil
    }
}

enum SkillCharge {
    static let energyPerToken: CGFloat = 1
    static let maximumEnergy: CGFloat = 40_000
}

enum SkillCombat {
    static func baseDamage(for skill: HeroSkill, rank: Int) -> CGFloat {
        guard rank > 0 else { return 0 }
        let rank = min(rank, skill.maxRank)
        return CGFloat(skill.castEnergyRequirement) * (0.5 + 0.25 * CGFloat(rank - 1))
    }

    static func damage(for skill: HeroSkill, rank: Int, modifiers: SkillModifiers, outgoingMultiplier: CGFloat) -> CGFloat {
        baseDamage(for: skill, rank: rank) * modifiers.damageMultiplier * modifiers.skillDamageMultiplier * outgoingMultiplier
    }
}

enum CombatTiming {
    static let monsterAttackInterval: TimeInterval = 2
    static let idleAttackCooldown: TimeInterval = 1.8
    static let monsterDamagePerHit: CGFloat = 1 / 900
    static let reviveHealth: CGFloat = 0.28
    static let comboWindow: TimeInterval = 12
    static let maxCombo = 10
    static let critChance = 0.12
    static let healingPointsPerToken: CGFloat = 1 / 1_000

    // Presentation tiers only. Damage, combo and recovery never depend on a
    // scan's size or on how many animations can be displayed.
    static let burstStrikeCounts = [1, 2, 3, 5]
    static let burstStrikeSpacing: TimeInterval = 0.32

    static func monsterDamagePoints(for damageFraction: CGFloat) -> CGFloat {
        max(0, damageFraction) * CGFloat(GameStats.heroMaxHP)
    }

    static func attackTier(for tokenDelta: Int) -> Int {
        switch tokenDelta {
        case ..<60:
            return 0
        case 60..<250:
            return 1
        case 250..<900:
            return 2
        default:
            return 3
        }
    }
}

/// What the hero landed on a monster, after every multiplier that applies to
/// outgoing damage. Both the token-burst path and the idle-attack path route
/// through here so the two can never drift apart.
enum HeroDamage {
    /// Multipliers that scale *all* hero damage regardless of how the attack was
    /// triggered: permanent equipment bonuses and the timed power-boost buff.
    static func outgoingMultiplier() -> CGFloat {
        ItemSystem.damageMultiplier() * ItemSystem.attackDamageMultiplier()
    }

    /// Damage points for one attack, given the pre-multiplier `basePoints` the
    /// caller computed from tokens/combo/role.
    static func points(base basePoints: CGFloat) -> CGFloat {
        basePoints * outgoingMultiplier()
    }
}

/// Result of a monster reaching zero HP: what to announce, what was earned.
struct DefeatReward {
    let monsterName: String
    let xpGained: Int
    let didLevelUp: Bool
    let level: Int
    var loot: LootDrop?
    var bossGold = 0
}
