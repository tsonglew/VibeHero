import AppKit
import XCTest
@testable import VibeHero

final class MonsterMechanicsTests: XCTestCase {
    func testShieldConsumesBudgetBeforeHealthAndPreservesOverkill() {
        let encounter = MonsterEncounter(kind: .cacheGolem, stage: 1, isBoss: false)
        var state = MonsterMechanicsState(encounter: encounter)
        XCTAssertEqual(state.shieldPoints, 3_400)
        let first = state.applyDamage(1_000, remainingHP: 17_000, maximumHP: 17_000)
        XCTAssertEqual(first, MonsterDamageApplication(budgetSpent: 1_000, shieldLost: 1_000, hpLost: 0))
        XCTAssertEqual(state.damageCapacity(remainingHP: 17_000), 19_400)
        let second = state.applyDamage(20_000, remainingHP: 17_000, maximumHP: 17_000)
        XCTAssertEqual(second, MonsterDamageApplication(budgetSpent: 19_400, shieldLost: 2_400, hpLost: 17_000))
        XCTAssertEqual(state.shieldPoints, 0)
        XCTAssertEqual(20_000 - second.budgetSpent, 600)
    }

    func testShieldRejectsInvalidDamageAndDeadTargets() {
        var state = MonsterMechanicsState(encounter: MonsterEncounter(kind: .cacheGolem, stage: 1, isBoss: false))
        let initial = state
        for damage: CGFloat in [.nan, .infinity, -1, 0] {
            XCTAssertEqual(state.applyDamage(damage, remainingHP: 17_000, maximumHP: 17_000).budgetSpent, 0)
            XCTAssertEqual(state, initial)
        }
        XCTAssertEqual(state.applyDamage(1_000, remainingHP: 0, maximumHP: 17_000).budgetSpent, 0)
        XCTAssertEqual(state, initial)
    }

    func testBossPhaseStartsAtHalfHealthAndDoesNotRevertAfterHealing() {
        var state = MonsterMechanicsState(encounter: MonsterEncounter(kind: .tokenSlime, stage: 5, isBoss: true))
        _ = state.applyDamage(49, remainingHP: 100, maximumHP: 100)
        XCTAssertFalse(state.isEnraged)
        _ = state.applyDamage(1, remainingHP: 51, maximumHP: 100)
        XCTAssertTrue(state.isEnraged)
        XCTAssertEqual(state.attackMultiplier, 1.5)
        _ = state.applyDamage(1, remainingHP: 80, maximumHP: 100)
        XCTAssertTrue(state.isEnraged)
        var regular = MonsterMechanicsState(encounter: MonsterEncounter(kind: .promptWraith, stage: 1, isBoss: false))
        _ = regular.applyDamage(75, remainingHP: 100, maximumHP: 100)
        XCTAssertEqual(regular.attackMultiplier, 1)
    }

    func testSlimeRecoveryIsLinearCappedAndCannotReviveAnEnemy() {
        let state = MonsterMechanicsState(encounter: MonsterEncounter(kind: .tokenSlime, stage: 1, isBoss: false))
        XCTAssertEqual(state.recoveredHP(elapsed: 10, currentHP: 5_000, maximumHP: 10_000), 100)
        XCTAssertEqual(state.recoveredHP(elapsed: 10_000, currentHP: 5_000, maximumHP: 10_000), 5_000)
        XCTAssertEqual(state.recoveredHP(elapsed: 10, currentHP: 0, maximumHP: 10_000), 0)
        XCTAssertEqual(state.recoveredHP(elapsed: .infinity, currentHP: 5_000, maximumHP: 10_000), 0)
        XCTAssertEqual(MonsterMechanicsState().recoveredHP(elapsed: 10, currentHP: 5_000, maximumHP: 10_000), 0)
    }

    func testBossesRotateByOrdinalAndRelaunchProducesSameIdentity() {
        let kinds: [MonsterKind] = [.promptWraith, .cacheGolem, .tokenSlime, .nullSentinel, .promptWraith]
        for (index, kind) in kinds.enumerated() {
            let stage = (index + 1) * 5
            let kills = (stage - 1) * StageProgress.killsPerStage
            for startingKind in MonsterKind.allCases {
                let plan = MonsterEncounterPlanner.makeBatch(totalKills: kills, startingKind: startingKind, requestedCount: 8)
                XCTAssertEqual(plan.encounters, [MonsterEncounter(kind: kind, stage: stage, isBoss: true)])
                XCTAssertEqual(plan.nextKind, startingKind.next, "Boss identity must not perturb the ordinary rotation")
            }
        }
    }

    @MainActor
    private func withSlime(_ body: (NotchContentView, Date) -> Void) {
        _ = NSApplication.shared
        let suite = "VibeHero.MonsterMechanicsTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        Defaults.withStore(store) {
            let view = NotchContentView(
                frame: NSRect(origin: .zero, size: NotchStyle.fallbackExpanded.windowSize),
                collapsedStyle: .fallbackCollapsed, expandedStyle: .fallbackExpanded,
                startMonitors: false, presentationVisible: true, reduceMotion: false
            )
            defer {
                view.monsterRespawnWorkItem?.cancel()
                view.tokenActivityExpirationWorkItem?.cancel()
            }
            let encounter = MonsterEncounter(kind: .tokenSlime, stage: 1, isBoss: false)
            view.battleScene.spawnMonsterBatch([encounter])
            view.activateMonster(encounter, announce: false)
            view.battleScene.updateWorld(dt: 2)
            view.monsterHealth = 0.5
            let now = Date()
            view.lastMonsterRecoveryAt = now
            view.lastPassiveRecoveryAt = now
            body(view, now)
        }
    }

    @MainActor
    func testSlimeRecoversOnlyIdleIntervalsAndNeverBackfillsCampOrDeath() {
        withSlime { view, now in
            view.tokenActivityExpiresAt = now.addingTimeInterval(10)
            view.advanceMonsterRecovery(now: now.addingTimeInterval(5))
            XCTAssertEqual(view.monsterHealth, 0.5)
            view.advanceMonsterRecovery(now: now.addingTimeInterval(20))
            XCTAssertEqual(view.monsterHealth, 0.51, accuracy: 0.000_001)
            view.setCamping(true, now: now.addingTimeInterval(20))
            view.advanceMonsterRecovery(now: now.addingTimeInterval(100))
            XCTAssertEqual(view.monsterHealth, 0.51, accuracy: 0.000_001)
            view.setCamping(false, now: now.addingTimeInterval(120))
            view.advanceMonsterRecovery(now: now.addingTimeInterval(125))
            XCTAssertEqual(view.monsterHealth, 0.515, accuracy: 0.000_001)
            view.isDefeated = true
            view.advanceMonsterRecovery(now: now.addingTimeInterval(200))
            XCTAssertEqual(view.monsterHealth, 0.515, accuracy: 0.000_001)
            view.isDefeated = false
            view.advanceMonsterRecovery(now: now.addingTimeInterval(201))
            XCTAssertEqual(view.monsterHealth, 0.516, accuracy: 0.000_001)
        }
    }

    @MainActor
    func testSlimeRecoveryIsIndependentOfLogicalTickPartition() {
        var health: [CGFloat] = []
        for intervals in [[20.0], Array(1...20).map(Double.init)] {
            withSlime { view, now in
                view.tokenActivityExpiresAt = now.addingTimeInterval(7)
                for seconds in intervals { view.advanceMonsterRecovery(now: now.addingTimeInterval(seconds)) }
                health.append(view.monsterHealth)
            }
        }
        XCTAssertEqual(health[0], 0.513, accuracy: 0.000_001)
        XCTAssertEqual(health[0], health[1], accuracy: 0.000_001)
    }

    @MainActor
    func testSlimeExpiryCallbackSettlesOnlyTheIdlePartOfLastTick() {
        withSlime { view, now in
            view.tokenActivityExpiresAt = now.addingTimeInterval(15)
            view.lastMonsterRecoveryAt = now.addingTimeInterval(14)
            view.expireTokenActivity(now: now.addingTimeInterval(16))
            XCTAssertNil(view.tokenActivityExpiresAt)
            XCTAssertEqual(view.monsterHealth, 0.501, accuracy: 0.000_001)
            view.advanceMonsterRecovery(now: now.addingTimeInterval(17))
            XCTAssertEqual(view.monsterHealth, 0.502, accuracy: 0.000_001)
        }
    }

    @MainActor
    func testSlimeEngagementStartsANewRecoveryInterval() {
        withSlime { view, now in
            let encounter = MonsterEncounter(kind: .tokenSlime, stage: 1, isBoss: false)
            view.battleScene.spawnMonsterBatch([encounter])
            view.activateMonster(encounter, announce: false)
            view.monsterHealth = 0.5
            view.lastMonsterRecoveryAt = now.addingTimeInterval(-100)
            view.battleScene.updateWorld(dt: 2)
            XCTAssertTrue(view.battleScene.monsterEngaged)
            let engagedAt = view.lastMonsterRecoveryAt
            XCTAssertGreaterThanOrEqual(engagedAt, now)
            view.advanceMonsterRecovery(now: engagedAt.addingTimeInterval(1))
            XCTAssertEqual(view.monsterHealth, 0.501, accuracy: 0.000_001)
        }
    }

    @MainActor
    func testBossPhaseMultiplierReachesActualIncomingDamage() {
        withSlime { view, now in
            let boss = MonsterEncounter(kind: .promptWraith, stage: 5, isBoss: true)
            view.battleScene.spawnMonsterBatch([boss])
            view.activateMonster(boss, announce: false)
            view.battleScene.updateWorld(dt: 2)
            view.heroHealth = 1
            view.lastMonsterAttackAt = nil
            XCTAssertTrue(view.maybeMonsterAttack(now: now))
            let first = 1 - view.heroHealth
            _ = view.damageMonster(by: CGFloat(boss.maxHP) * 0.5)
            XCTAssertEqual(view.encounterPresentation(now: now).bossPhase, 2)
            let before = view.heroHealth
            XCTAssertTrue(view.maybeMonsterAttack(now: now.addingTimeInterval(2)))
            XCTAssertEqual(before - view.heroHealth, first * 1.5, accuracy: 0.000_001)
        }
    }
}
