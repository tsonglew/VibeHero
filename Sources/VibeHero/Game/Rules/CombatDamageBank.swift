import Foundation

/// Damage is resolved once, before presentation, and remains in absolute HP
/// units while waiting for a target. A later buff or target change cannot
/// reinterpret an already earned strike.
struct ResolvedHeroStrike: Equatable {
    let damagePoints: CGFloat
    let isCrit: Bool
}

struct CombatDamageBank {
    private var strikes: [ResolvedHeroStrike] = []
    private var head = 0

    var pendingPoints: CGFloat {
        strikes.dropFirst(head).reduce(0) { $0 + $1.damagePoints }
    }

    var isEmpty: Bool { head == strikes.count }

    mutating func deposit(_ strike: ResolvedHeroStrike) {
        guard strike.damagePoints.isFinite, strike.damagePoints > 0 else { return }
        strikes.append(strike)
    }

    /// Consumes only the HP the current enemy can lose. Overkill and subsequent
    /// strikes stay available for the next encounter, with their original crit.
    mutating func consume(upTo remainingHP: CGFloat) -> ResolvedHeroStrike? {
        guard remainingHP.isFinite, remainingHP > 0, !isEmpty else { return nil }
        let strike = strikes[head]
        let applied = min(remainingHP, strike.damagePoints)
        let remainder = strike.damagePoints - applied
        if remainder > 0 {
            strikes[head] = ResolvedHeroStrike(damagePoints: remainder, isCrit: strike.isCrit)
        } else {
            head += 1
            if isEmpty {
                strikes.removeAll(keepingCapacity: true)
                head = 0
            } else if head >= 64 && head >= strikes.count / 2 {
                strikes.removeFirst(head)
                head = 0
            }
        }
        return ResolvedHeroStrike(damagePoints: applied, isCrit: strike.isCrit)
    }
}
