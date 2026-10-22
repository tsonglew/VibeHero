import Foundation
import XCTest
@testable import VibeHero

final class CombatDamageBankTests: XCTestCase {
    func testOverkillAndFollowingStrikesKeepTheirAbsoluteDamageAndCrit() {
        var bank = CombatDamageBank()
        bank.deposit(ResolvedHeroStrike(damagePoints: 500, isCrit: true))
        bank.deposit(ResolvedHeroStrike(damagePoints: 80, isCrit: false))

        XCTAssertEqual(bank.consume(upTo: 200), ResolvedHeroStrike(damagePoints: 200, isCrit: true))
        XCTAssertEqual(bank.pendingPoints, 380)
        XCTAssertEqual(bank.consume(upTo: 1_000), ResolvedHeroStrike(damagePoints: 300, isCrit: true))
        XCTAssertEqual(bank.consume(upTo: 700), ResolvedHeroStrike(damagePoints: 80, isCrit: false))
        XCTAssertTrue(bank.isEmpty)
    }

    func testNoTargetAndInvalidAmountsCannotConsumeOrCreateDamage() {
        var bank = CombatDamageBank()
        for value: CGFloat in [0, -1, .infinity, .nan] {
            bank.deposit(ResolvedHeroStrike(damagePoints: value, isCrit: false))
        }
        XCTAssertTrue(bank.isEmpty)
        bank.deposit(ResolvedHeroStrike(damagePoints: 500, isCrit: false))
        for value: CGFloat in [0, -1, .infinity, .nan] {
            XCTAssertNil(bank.consume(upTo: value))
        }
        XCTAssertEqual(bank.pendingPoints, 500)
    }

    func testConservationAcrossManyEnemiesAndQueueCompaction() {
        var bank = CombatDamageBank()
        for _ in 0..<200 {
            bank.deposit(ResolvedHeroStrike(damagePoints: 13.5, isCrit: false))
        }
        var applied: CGFloat = 0
        for capacity: CGFloat in [15, 120, 200, 700, 1_000] {
            var remaining = capacity
            while let strike = bank.consume(upTo: remaining) {
                applied += strike.damagePoints
                remaining -= strike.damagePoints
            }
            XCTAssertEqual(applied + bank.pendingPoints, 2_700, accuracy: 0.000_001)
        }
        while let strike = bank.consume(upTo: 1_000) {
            applied += strike.damagePoints
        }
        XCTAssertEqual(applied, 2_700, accuracy: 0.000_001)
        XCTAssertTrue(bank.isEmpty)
        bank.deposit(ResolvedHeroStrike(damagePoints: 10, isCrit: true))
        XCTAssertEqual(bank.consume(upTo: 10)?.damagePoints, 10)
    }
}
