import Foundation

/// Captured when tokens arrive. A partially filled segment keeps these values,
/// so polling boundaries cannot reroll its crit or change its damage multiplier.
struct TokenCombatModifiers: Equatable {
    // Far above every supported build. Reject corrupt values before they can
    // create a strike whose floating-point spacing exceeds an enemy's HP.
    static let maximumDamagePerToken: CGFloat = 1_000_000
    var damagePerToken: CGFloat = 1
    var critChance: Double = CombatTiming.critChance
    var healingPointsPerToken: CGFloat = CombatTiming.healingPointsPerToken
    var energyPerToken: CGFloat = SkillCharge.energyPerToken

    fileprivate var validated: Self {
        var result = self
        if !result.damagePerToken.isFinite || result.damagePerToken < 0
            || result.damagePerToken > Self.maximumDamagePerToken {
            result.damagePerToken = 1
        }
        result.critChance = result.critChance.isFinite ? min(1, max(0, result.critChance)) : CombatTiming.critChance
        if !result.healingPointsPerToken.isFinite || result.healingPointsPerToken < 0
            || result.healingPointsPerToken > CGFloat.greatestFiniteMagnitude / CGFloat(Int.max) {
            result.healingPointsPerToken = CombatTiming.healingPointsPerToken
        }
        if !result.energyPerToken.isFinite || result.energyPerToken < 0
            || result.energyPerToken > CGFloat.greatestFiniteMagnitude / CGFloat(Int.max) {
            result.energyPerToken = SkillCharge.energyPerToken
        }
        return result
    }
}

struct TokenCombatRecovery: Equatable {
    var healingPoints: CGFloat = 0
    var energy: CGFloat = 0
}

/// An exact integer token ledger, independent of scan size and presentation.
/// Large deposits occupy at most two entries; only a bounded number of fixed
/// 250-token segments become damage on each simulation tick. No Int total is
/// accumulated, and no huge floating-point strike needs to lose tiny enemy HP.
struct TokenCombatAccounting {
    static let tokensPerSegment = 250
    static let maximumSegmentsPerTick = 512

    private struct Entry {
        var segmentID: UInt64
        var segmentOffset: Int
        var combo: Int
        var tokens: Int
        let modifiers: TokenCombatModifiers
    }

    private struct PartialSegment {
        let id: UInt64
        var usedTokens: Int
        let combo: Int
        let modifiers: TokenCombatModifiers
    }

    private let seed: UInt64
    private var nextSegmentID: UInt64 = 0
    private var partial: PartialSegment?
    private var entries: [Entry] = []
    private var head = 0
    private var lastActivityAt: Date?
    private(set) var comboCount = 0

    init(seed: UInt64 = UInt64.random(in: .min ... .max)) {
        self.seed = seed
    }

    var hasPendingTokens: Bool { head < entries.count }
    var pendingEntryCount: Int { entries.count - head }

    /// Decimal is diagnostic only; each retained budget remains an exact Int.
    /// Summing several Int.max deposits must not overflow an Int counter.
    var pendingTokenCount: Decimal {
        entries.dropFirst(head).reduce(Decimal.zero) { $0 + Decimal($1.tokens) }
    }

    @discardableResult
    mutating func deposit(tokens: Int, at now: Date, modifiers: TokenCombatModifiers) -> TokenCombatRecovery {
        guard tokens > 0 else { return TokenCombatRecovery() }
        let modifiers = modifiers.validated
        if let lastActivityAt {
            let elapsed = now.timeIntervalSince(lastActivityAt)
            if !elapsed.isFinite || elapsed < 0 || elapsed > CombatTiming.comboWindow {
                comboCount = 0
            }
        }
        lastActivityAt = now
        var remaining = tokens

        // Finish an already started segment using its original context. A
        // timeout/hit resets the NEXT segment, never rerolls the partial one.
        if var partial {
            let count = min(remaining, Self.tokensPerSegment - partial.usedTokens)
            append(Entry(segmentID: partial.id, segmentOffset: partial.usedTokens,
                         combo: partial.combo, tokens: count, modifiers: partial.modifiers))
            partial.usedTokens += count
            remaining -= count
            self.partial = partial.usedTokens == Self.tokensPerSegment ? nil : partial
        }

        if remaining > 0 {
            let firstCombo = min(CombatTiming.maxCombo, comboCount + 1)
            append(Entry(segmentID: nextSegmentID, segmentOffset: 0,
                         combo: firstCombo, tokens: remaining, modifiers: modifiers))
            let fullSegments = remaining / Self.tokensPerSegment
            let tail = remaining % Self.tokensPerSegment
            let segmentCount = fullSegments + (tail > 0 ? 1 : 0)
            comboCount = min(CombatTiming.maxCombo, comboCount + min(segmentCount, CombatTiming.maxCombo))
            nextSegmentID &+= UInt64(segmentCount)
            if tail > 0 {
                partial = PartialSegment(id: nextSegmentID &- 1, usedTokens: tail,
                                         combo: comboCount, modifiers: modifiers)
            }
        }
        return TokenCombatRecovery(healingPoints: CGFloat(tokens) * modifiers.healingPointsPerToken,
                                   energy: CGFloat(tokens) * modifiers.energyPerToken)
    }

    /// Already earned entries keep their combo. Only future segments reset.
    mutating func breakCombo() {
        comboCount = 0
        lastActivityAt = nil
    }

    mutating func resolveNext(maximumSegments: Int = maximumSegmentsPerTick) -> [ResolvedHeroStrike] {
        let limit = max(0, min(maximumSegments, Self.maximumSegmentsPerTick))
        var resolved: [ResolvedHeroStrike] = []
        resolved.reserveCapacity(limit)
        for _ in 0..<limit {
            guard hasPendingTokens else { break }
            var entry = entries[head]
            let count = min(entry.tokens, Self.tokensPerSegment - entry.segmentOffset)
            let isCrit = criticalRoll(for: entry.segmentID) < entry.modifiers.critChance
            let multiplier = (1 + 0.05 * CGFloat(entry.combo)) * (isCrit ? 2 : 1)
            resolved.append(ResolvedHeroStrike(damagePoints: CGFloat(count) * entry.modifiers.damagePerToken * multiplier,
                                               isCrit: isCrit))
            entry.tokens -= count
            entry.segmentOffset += count
            if entry.segmentOffset == Self.tokensPerSegment {
                entry.segmentID &+= 1
                entry.segmentOffset = 0
                entry.combo = min(CombatTiming.maxCombo, entry.combo + 1)
            }
            if entry.tokens == 0 {
                head += 1
            } else {
                entries[head] = entry
            }
        }
        if !hasPendingTokens {
            entries.removeAll(keepingCapacity: true)
            head = 0
        } else if head >= 64 && head >= entries.count / 2 {
            entries.removeFirst(head)
            head = 0
        }
        return resolved
    }

    private mutating func append(_ entry: Entry) {
        if hasPendingTokens, let previous = entries.last, previous.modifiers == entry.modifiers {
            let offset = previous.segmentOffset + previous.tokens % Self.tokensPerSegment
            let advance = previous.tokens / Self.tokensPerSegment + offset / Self.tokensPerSegment
            let endCombo = min(CombatTiming.maxCombo, previous.combo + min(advance, CombatTiming.maxCombo))
            let sum = previous.tokens.addingReportingOverflow(entry.tokens)
            if !sum.overflow, previous.segmentID &+ UInt64(advance) == entry.segmentID,
               offset % Self.tokensPerSegment == entry.segmentOffset, endCombo == entry.combo {
                entries[entries.count - 1].tokens = sum.partialValue
                return
            }
        }
        entries.append(entry)
    }

    /// SplitMix64 gives each segment a stable pseudo-random roll for this run.
    /// Reading the same tokens in different batches uses exactly the same roll.
    private func criticalRoll(for segmentID: UInt64) -> Double {
        var value = seed &+ segmentID &* 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value >> 11) / 9_007_199_254_740_992
    }
}
