import AppKit
import XCTest
@testable import VibeHero

final class CombatFeedbackTests: XCTestCase {
    func testMonsterDamageDisplayUsesTheAppliedDamageAmount() {
        let damageFraction = CombatTiming.monsterDamagePerHit * 0.82 * 0.9

        XCTAssertEqual(
            CombatTiming.monsterDamagePoints(for: damageFraction),
            damageFraction * 100,
            accuracy: 0.000_001
        )
    }

    func testBaseMonsterDamageStillTakesThirtyMinutesToDefeatHero() {
        let hitsToDefeat = ceil(1 / CombatTiming.monsterDamagePerHit)
        let secondsToDefeat = Double(hitsToDefeat) * CombatTiming.monsterAttackInterval

        XCTAssertEqual(secondsToDefeat, 30 * 60, accuracy: 0.001)
    }

    @MainActor
    func testSubpixelHealthLossGetsVisibleBarFeedback() {
        let width = PixelBarView.visibleDamageWidth(
            oldValue: 1,
            newValue: 1 - CombatTiming.monsterDamagePerHit,
            barWidth: 100
        )

        XCTAssertEqual(width, 3, accuracy: 0.001)
    }
}
