import AppKit
import XCTest
@testable import VibeHero

/// Progression math used to live as `private` types inside the 1,740-line
/// `NotchContentView.swift`, which made it unreachable from tests. These cover
/// the rules now that they are their own layer.
final class ProgressionTests: XCTestCase {

    // MARK: - Experience curve

    func testLevelZeroUntilTheFirstRequirementIsMet() {
        XCTAssertEqual(ExperienceCurve.state(for: 0).level, 0)
        XCTAssertEqual(ExperienceCurve.state(for: 119).level, 0)
        XCTAssertEqual(ExperienceCurve.state(for: 120).level, 1)
    }

    func testTotalXPRequiredRoundTripsThroughState() {
        for level in 0...20 {
            let totalXP = ExperienceCurve.totalXPRequired(toReach: level)
            let state = ExperienceCurve.state(for: totalXP)

            XCTAssertEqual(state.level, level, "level \(level) did not round-trip")
            XCTAssertEqual(state.currentXP, 0, "level \(level) should land exactly on the boundary")
            XCTAssertEqual(state.progress, 0, accuracy: 0.000_001)
        }
    }

    func testOneXPShortOfALevelStaysOnThePreviousLevel() {
        for level in 1...12 {
            let boundary = ExperienceCurve.totalXPRequired(toReach: level)
            XCTAssertEqual(ExperienceCurve.state(for: boundary - 1).level, level - 1)
        }
    }

    func testProgressIsTheFractionIntoTheCurrentLevel() {
        let boundary = ExperienceCurve.totalXPRequired(toReach: 1)
        let required = ExperienceCurve.state(for: boundary).requiredXP
        let state = ExperienceCurve.state(for: boundary + required / 2)

        XCTAssertEqual(state.level, 1)
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.01)
    }

    func testProgressStaysClampedAndNegativeXPIsTreatedAsZero() {
        XCTAssertEqual(ExperienceCurve.state(for: -500).level, 0)
        XCTAssertEqual(ExperienceCurve.state(for: -500).currentXP, 0)

        for totalXP in [0, 1, 500, 10_000, 500_000] {
            let progress = ExperienceCurve.state(for: totalXP).progress
            XCTAssertGreaterThanOrEqual(progress, 0)
            XCTAssertLessThanOrEqual(progress, 1)
        }
    }

    func testCurveKeepsGoingPastTheHandTunedLevels() {
        // Past the twelve tabulated requirements the curve ramps linearly, so it
        // must still be strictly increasing rather than flat or wrapping.
        var previous = 0
        for level in 1...40 {
            let total = ExperienceCurve.totalXPRequired(toReach: level)
            XCTAssertGreaterThan(total, previous, "level \(level) did not cost more than level \(level - 1)")
            previous = total
        }
    }

    // MARK: - Stage progress

    func testStageAdvancesEveryEightKills() {
        XCTAssertEqual(StageProgress.stage(for: 0), 1)
        XCTAssertEqual(StageProgress.stage(for: 7), 1)
        XCTAssertEqual(StageProgress.stage(for: 8), 2)
        XCTAssertEqual(StageProgress.stage(for: 40), 6)
    }

    func testBossArrivesOnceAtTheStartOfEveryFifthStage() {
        let bossKills = (0..<80).filter { StageProgress.isBossEncounter(totalKills: $0) }

        XCTAssertEqual(bossKills, [32, 72])
        for kills in bossKills {
            XCTAssertTrue(StageProgress.isBossStage(StageProgress.stage(for: kills)))
            XCTAssertEqual(StageProgress.killsIntoStage(for: kills), 0)
        }
    }

    func testStageZeroIsNotABossStage() {
        XCTAssertFalse(StageProgress.isBossStage(0))
    }

    func testMaxHPGrowsTenPercentPerStage() {
        let stageOne = StageProgress.maxHP(stage: 1, monster: .promptWraith, isBoss: false)
        let stageTwo = StageProgress.maxHP(stage: 2, monster: .promptWraith, isBoss: false)

        XCTAssertEqual(stageOne, 120 * 100)
        XCTAssertEqual(Double(stageTwo) / Double(stageOne), 1.10, accuracy: 0.001)
    }

    func testBossesGet2Point2TimesTheHPPool() {
        let regular = StageProgress.maxHP(stage: 5, monster: .cacheGolem, isBoss: false)
        let boss = StageProgress.maxHP(stage: 5, monster: .cacheGolem, isBoss: true)

        XCTAssertEqual(Double(boss) / Double(regular), 2.2, accuracy: 0.001)
    }

    func testXPMultiplierGrowsEightPercentPerStageAndDoublesForBosses() {
        XCTAssertEqual(StageProgress.xpMultiplier(stage: 1, isBoss: false), 1, accuracy: 0.000_001)
        XCTAssertEqual(StageProgress.xpMultiplier(stage: 2, isBoss: false), 1.08, accuracy: 0.000_001)
        XCTAssertEqual(StageProgress.xpMultiplier(stage: 2, isBoss: true), 2.16, accuracy: 0.000_001)
    }

    func testStageScalingTreatsStageZeroAsStageOne() {
        XCTAssertEqual(
            StageProgress.maxHP(stage: 0, monster: .tokenSlime, isBoss: false),
            StageProgress.maxHP(stage: 1, monster: .tokenSlime, isBoss: false)
        )
    }

    // MARK: - Combat tiers

    func testAttackTierBandBoundaries() {
        XCTAssertEqual(CombatTiming.attackTier(for: 0), 0)
        XCTAssertEqual(CombatTiming.attackTier(for: 59), 0)
        XCTAssertEqual(CombatTiming.attackTier(for: 60), 1)
        XCTAssertEqual(CombatTiming.attackTier(for: 249), 1)
        XCTAssertEqual(CombatTiming.attackTier(for: 250), 2)
        XCTAssertEqual(CombatTiming.attackTier(for: 899), 2)
        XCTAssertEqual(CombatTiming.attackTier(for: 900), 3)
        XCTAssertEqual(CombatTiming.attackTier(for: 1_000_000), 3)
    }

    func testEveryAttackTierHasAStrikeCount() {
        for tokenDelta in [0, 60, 250, 900, 50_000] {
            let tier = CombatTiming.attackTier(for: tokenDelta)
            XCTAssertLessThan(tier, CombatTiming.burstStrikeCounts.count)
        }
    }

    // MARK: - Skill loadout

    func testLoadoutRoundTripsEverySkillRank() {
        let ranks = Dictionary(
            uniqueKeysWithValues: HeroSkill.allCases.enumerated().map { ($0.element, $0.offset + 1) }
        )
        let loadout = SkillLoadout(ranks: ranks)

        for skill in HeroSkill.allCases {
            XCTAssertEqual(loadout.rank(for: skill), ranks[skill])
        }
        XCTAssertEqual(loadout.totalRanks, ranks.values.reduce(0, +))
    }

    func testEmptyLoadoutReportsZeroForEverySkill() {
        for skill in HeroSkill.allCases {
            XCTAssertEqual(SkillLoadout.empty.rank(for: skill), 0)
        }
        XCTAssertEqual(SkillLoadout.empty.totalRanks, 0)
    }
}
