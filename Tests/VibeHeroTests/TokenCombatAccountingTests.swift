import Foundation
import XCTest
@testable import VibeHero

final class TokenCombatAccountingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    private func result(for batches: [Int], drainBetweenBatches: Bool = true) -> (damage: CGFloat, criticalDamage: CGFloat, healing: CGFloat, energy: CGFloat, combo: Int) {
        var ledger = TokenCombatAccounting(seed: 42)
        var damage: CGFloat = 0
        var criticalDamage: CGFloat = 0
        var healing: CGFloat = 0
        var energy: CGFloat = 0
        func consume(_ strikes: [ResolvedHeroStrike]) {
            for strike in strikes {
                damage += strike.damagePoints
                if strike.isCrit { criticalDamage += strike.damagePoints }
            }
        }
        for batch in batches {
            let recovery = ledger.deposit(tokens: batch, at: now, modifiers: TokenCombatModifiers())
            healing += recovery.healingPoints
            energy += recovery.energy
            if drainBetweenBatches { consume(ledger.resolveNext()) }
        }
        while ledger.hasPendingTokens { consume(ledger.resolveNext()) }
        return (damage, criticalDamage, healing, energy, ledger.comboCount)
    }

    func testScanPartitionsHaveIdenticalDamageCritComboAndRecovery() {
        let batches = [1, 49, 250, 17, 983, 2_000, 12_345, 1, 77]
        let total = batches.reduce(0, +)
        let expected = result(for: [total])
        for partition in [batches, Array(repeating: 1, count: total), [250, total - 250]] {
            for drainBetween in [false, true] {
                let actual = result(for: partition, drainBetweenBatches: drainBetween)
                XCTAssertEqual(actual.damage, expected.damage, accuracy: 0.000_001)
                XCTAssertEqual(actual.criticalDamage, expected.criticalDamage, accuracy: 0.000_001)
                XCTAssertEqual(actual.healing, expected.healing, accuracy: 0.000_001)
                XCTAssertEqual(actual.energy, expected.energy, accuracy: 0.000_001)
                XCTAssertEqual(actual.combo, expected.combo)
            }
        }
    }

    func testPartialSegmentKeepsOriginalCritAndDamageContext() {
        var ledger = TokenCombatAccounting(seed: 42)
        ledger.deposit(tokens: 100, at: now, modifiers: TokenCombatModifiers(damagePerToken: 1, critChance: 1))
        ledger.deposit(tokens: 400, at: now, modifiers: TokenCombatModifiers(damagePerToken: 9, critChance: 0))
        let strikes = ledger.resolveNext()
        XCTAssertEqual(strikes.count, 2)
        XCTAssertTrue(strikes[0].isCrit)
        XCTAssertEqual(strikes[0].damagePoints, 250 * 1.05 * 2, accuracy: 0.000_001)
        XCTAssertFalse(strikes[1].isCrit)
        XCTAssertEqual(strikes[1].damagePoints, 250 * 9 * 1.10, accuracy: 0.000_001)
        XCTAssertEqual(ledger.comboCount, 2)
    }

    func testTinyInputHasNoMinimumDamageOrPerScanRecoveryBonus() {
        var ledger = TokenCombatAccounting(seed: 42)
        let recovery = ledger.deposit(tokens: 1, at: now, modifiers: TokenCombatModifiers(critChance: 0))
        XCTAssertEqual(ledger.resolveNext().first?.damagePoints ?? 0, 1.05, accuracy: 0.000_001)
        XCTAssertEqual(recovery.healingPoints, 0.001, accuracy: 0.000_001)
        XCTAssertEqual(recovery.energy, 1, accuracy: 0.000_001)
        XCTAssertEqual(ledger.comboCount, 1)
        XCTAssertEqual(ledger.deposit(tokens: 0, at: now, modifiers: TokenCombatModifiers()), TokenCombatRecovery())
        XCTAssertEqual(ledger.deposit(tokens: -100, at: now, modifiers: TokenCombatModifiers()), TokenCombatRecovery())
        XCTAssertFalse(ledger.hasPendingTokens)
    }

    func testIntMaxBudgetIsSavedSynchronouslyAndResolvedInBoundedSmallStrikes() {
        var ledger = TokenCombatAccounting(seed: 42)
        ledger.deposit(tokens: Int.max, at: now, modifiers: TokenCombatModifiers(critChance: 0))
        XCTAssertEqual(ledger.pendingTokenCount, Decimal(Int.max))
        XCTAssertEqual(ledger.pendingEntryCount, 1)
        let strikes = ledger.resolveNext(maximumSegments: Int.max)
        XCTAssertEqual(strikes.count, 512)
        XCTAssertTrue(strikes.allSatisfy { $0.damagePoints > 0 && $0.damagePoints <= 375 })
        XCTAssertEqual(ledger.pendingTokenCount, Decimal(Int.max) - 128_000)
        ledger.deposit(tokens: Int.max, at: now, modifiers: TokenCombatModifiers(critChance: 0))
        XCTAssertEqual(ledger.pendingTokenCount, Decimal(Int.max) * 2 - 128_000)
        XCTAssertLessThanOrEqual(ledger.pendingEntryCount, 3)
        XCTAssertEqual(ledger.resolveNext().count, 512)
        XCTAssertEqual(ledger.pendingTokenCount, Decimal(Int.max) * 2 - 256_000)

        var bank = CombatDamageBank()
        bank.deposit(strikes.last!)
        let before = bank.pendingPoints
        XCTAssertEqual(bank.consume(upTo: 1)?.damagePoints, 1)
        XCTAssertEqual(bank.pendingPoints, before - 1)
    }

    func testTimeoutAndHitResetFutureComboWithoutChangingEarnedSegments() {
        for explicitHit in [false, true] {
            var ledger = TokenCombatAccounting(seed: 42)
            let modifiers = TokenCombatModifiers(critChance: 0)
            ledger.deposit(tokens: 2_251, at: now, modifiers: modifiers)
            XCTAssertEqual(ledger.comboCount, 10)
            if explicitHit { ledger.breakCombo() }
            ledger.deposit(tokens: 499, at: now.addingTimeInterval(explicitHit ? 1 : 13), modifiers: modifiers)
            let strikes = ledger.resolveNext()
            XCTAssertEqual(strikes.count, 11)
            XCTAssertEqual(strikes[9].damagePoints, 375, accuracy: 0.000_001)
            XCTAssertEqual(strikes[10].damagePoints, 262.5, accuracy: 0.000_001)
            XCTAssertEqual(ledger.comboCount, 1)
        }
    }

    func testCorruptNonFiniteAndExcessiveModifiersFallBackWithoutLosingTokens() {
        for invalid: CGFloat in [.nan, .infinity, -.infinity, -1, .greatestFiniteMagnitude] {
            var ledger = TokenCombatAccounting(seed: 42)
            let recovery = ledger.deposit(tokens: Int.max, at: now, modifiers: TokenCombatModifiers(
                damagePerToken: invalid, critChance: .nan,
                healingPointsPerToken: invalid, energyPerToken: invalid
            ))
            XCTAssertTrue(recovery.healingPoints.isFinite)
            XCTAssertTrue(recovery.energy.isFinite)
            XCTAssertEqual(ledger.pendingTokenCount, Decimal(Int.max))
            let strikes = ledger.resolveNext()
            XCTAssertTrue(strikes.allSatisfy { $0.damagePoints.isFinite && $0.damagePoints > 0 && $0.damagePoints <= 750 })
        }
    }

    func testRepeatedDepositsRemainCompressedWhileWaitingForATarget() {
        var ledger = TokenCombatAccounting(seed: 42)
        for _ in 0..<20_000 {
            ledger.deposit(tokens: 1, at: now, modifiers: TokenCombatModifiers())
        }
        XCTAssertEqual(ledger.pendingTokenCount, 20_000)
        XCTAssertEqual(ledger.pendingEntryCount, 1)
        XCTAssertEqual(ledger.resolveNext().count, 80)
        XCTAssertFalse(ledger.hasPendingTokens)
    }
}
