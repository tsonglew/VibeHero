import Foundation

struct MonsterDamageApplication: Equatable {
    let budgetSpent: CGFloat
    let shieldLost: CGFloat
    let hpLost: CGFloat
}

/// Encounter-local defenses and phase transitions. HP remains owned by the
/// combat controller; absorbed damage still consumes earned attack budget.
struct MonsterMechanicsState: Equatable {
    static let golemShieldFraction: CGFloat = 0.2
    static let slimeRecoveryFractionPerSecond: CGFloat = 0.001
    static let enragedAttackMultiplier: CGFloat = 1.5

    private(set) var shieldPoints: CGFloat = 0
    private(set) var maxShieldPoints: CGFloat = 0
    private(set) var isEnraged = false
    private(set) var kind: MonsterKind?
    private(set) var isBoss = false

    init() {}

    init(encounter: MonsterEncounter) {
        kind = encounter.kind
        isBoss = encounter.isBoss
        maxShieldPoints = encounter.kind == .cacheGolem
            ? CGFloat(encounter.maxHP) * Self.golemShieldFraction : 0
        shieldPoints = maxShieldPoints
    }

    var attackMultiplier: CGFloat { isEnraged ? Self.enragedAttackMultiplier : 1 }
    var idleRecoveryFractionPerSecond: CGFloat {
        kind == .tokenSlime ? Self.slimeRecoveryFractionPerSecond : 0
    }

    func damageCapacity(remainingHP: CGFloat) -> CGFloat {
        guard remainingHP.isFinite, remainingHP > 0 else { return 0 }
        return remainingHP + shieldPoints
    }

    mutating func applyDamage(_ points: CGFloat, remainingHP: CGFloat, maximumHP: CGFloat) -> MonsterDamageApplication {
        guard points.isFinite, points > 0, remainingHP.isFinite, remainingHP > 0 else {
            return MonsterDamageApplication(budgetSpent: 0, shieldLost: 0, hpLost: 0)
        }
        let shieldLost = min(shieldPoints, points)
        let hpLost = min(remainingHP, max(0, points - shieldLost))
        shieldPoints -= shieldLost
        let resultingHP = remainingHP - hpLost
        if isBoss, maximumHP.isFinite, maximumHP > 0, resultingHP > 0, resultingHP <= maximumHP * 0.5 {
            isEnraged = true
        }
        return MonsterDamageApplication(budgetSpent: shieldLost + hpLost, shieldLost: shieldLost, hpLost: hpLost)
    }

    func recoveredHP(elapsed: TimeInterval, currentHP: CGFloat, maximumHP: CGFloat) -> CGFloat {
        guard elapsed.isFinite, elapsed > 0, currentHP.isFinite, currentHP > 0,
              maximumHP.isFinite, maximumHP > currentHP else { return 0 }
        return min(maximumHP - currentHP, CGFloat(elapsed) * maximumHP * idleRecoveryFractionPerSecond)
    }
}

struct MonsterEncounterPresentation: Equatable {
    let shieldRemaining: CGFloat
    let shieldMaximum: CGFloat
    let idleRegenerationActive: Bool
    let idleRegenerationFractionPerSecond: CGFloat
    let bossPhase: Int?
}

enum CampRecovery {
    static let pointsPerSecond: CGFloat = 0.5
}
