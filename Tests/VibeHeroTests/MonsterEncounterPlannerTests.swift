import AppKit
import XCTest
@testable import VibeHero

final class MonsterEncounterPlannerTests: XCTestCase {
    func testInitialBatchStartsWithPromptWraithAndRotatesEveryEncounter() {
        let plan = MonsterEncounterPlanner.makeBatch(
            totalKills: 0,
            startingKind: .promptWraith,
            requestedCount: 5
        )

        XCTAssertEqual(plan.encounters.map(\.kind), [
            .promptWraith,
            .cacheGolem,
            .tokenSlime,
            .nullSentinel,
            .promptWraith
        ])
        XCTAssertEqual(plan.nextKind, .cacheGolem)
        XCTAssertTrue(plan.encounters.allSatisfy { $0.stage == 1 && !$0.isBoss })
    }

    func testRegularBatchStopsAtStageBoundary() {
        let plan = MonsterEncounterPlanner.makeBatch(
            totalKills: 7,
            startingKind: .nullSentinel,
            requestedCount: 8
        )

        XCTAssertEqual(plan.encounters, [
            MonsterEncounter(kind: .nullSentinel, stage: 1, isBoss: false)
        ])
        XCTAssertEqual(plan.nextKind, .promptWraith)
    }

    func testBossStageCreatesExactlyOneBossEncounter() {
        let bossPlan = MonsterEncounterPlanner.makeBatch(
            totalKills: 32,
            startingKind: .promptWraith,
            requestedCount: 8
        )
        let postBossPlan = MonsterEncounterPlanner.makeBatch(
            totalKills: 33,
            startingKind: bossPlan.nextKind,
            requestedCount: 8
        )

        XCTAssertEqual(bossPlan.encounters, [
            MonsterEncounter(kind: .promptWraith, stage: 5, isBoss: true)
        ])
        XCTAssertEqual(postBossPlan.encounters.count, 7)
        XCTAssertTrue(postBossPlan.encounters.allSatisfy { $0.stage == 5 && !$0.isBoss })
    }

    func testBossEncounterCanBeDerivedAfterRelaunch() {
        XCTAssertTrue(StageProgress.isBossEncounter(totalKills: 32))
        XCTAssertFalse(StageProgress.isBossEncounter(totalKills: 33))
        XCTAssertEqual(StageProgress.stage(for: 40), 6)
    }

    @MainActor
    func testWorldAdvancesWithoutEffectsAndNewBatchStillApproaches() {
        let scene = BattleSceneView(frame: NSRect(x: 0, y: 0, width: 420, height: 80))
        let first = MonsterEncounter(kind: .promptWraith, stage: 1, isBoss: false)
        let second = MonsterEncounter(kind: .cacheGolem, stage: 1, isBoss: false)
        var engagementCount = 0
        scene.onMonsterEngaged = { engagementCount += 1 }
        scene.layout()

        XCTAssertFalse(scene.rendersCombatEffects)
        scene.spawnMonsterBatch([first])
        XCTAssertFalse(scene.monsterEngaged)

        scene.updateWorld(dt: 2)
        XCTAssertTrue(scene.monsterEngaged)
        XCTAssertEqual(engagementCount, 1)

        scene.playMonsterDeath()
        scene.updateWorld(dt: 0.85)
        scene.spawnMonsterBatch([second])
        XCTAssertFalse(scene.monsterEngaged)

        scene.updateWorld(dt: 2)
        XCTAssertTrue(scene.monsterEngaged)
        XCTAssertEqual(engagementCount, 2)
    }

    @MainActor
    func testHeroAttackTellAddsLungeAndRecoilAnimations() {
        let hero = PixelActorView(kind: .hero)

        hero.playAttackTell(direction: 1)

        XCTAssertNotNil(hero.layer?.animation(forKey: "attackLunge"))
        XCTAssertNotNil(hero.layer?.animation(forKey: "attackRecoil"))
    }
}
