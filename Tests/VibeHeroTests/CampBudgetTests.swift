import AppKit
import XCTest
@testable import VibeHero

/// Controller-level checks: camping changes when earned work is applied, never
/// the accounting behind that work. Rule-table details live in mechanics tests.
final class CampBudgetTests: XCTestCase {
    @MainActor
    private func withView(configure: () -> Void = {}, _ body: (NotchContentView) -> Void) {
        _ = NSApplication.shared
        let suite = "VibeHero.CampBudget.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        Defaults.withStore(store) {
            Defaults.set(AppLanguage.english.rawValue, forKey: DefaultsKey.language)
            configure()
            let view = NotchContentView(
                frame: NSRect(origin: .zero, size: NotchStyle.fallbackExpanded.windowSize),
                collapsedStyle: .fallbackCollapsed, expandedStyle: .fallbackExpanded,
                startMonitors: false, presentationVisible: true, reduceMotion: false
            )
            defer {
                view.monsterRespawnWorkItem?.cancel()
                view.tokenActivityExpirationWorkItem?.cancel()
                view.battleScene.stopGameLoop()
                view.battleScene.stopBackgroundSimulation()
            }
            body(view)
        }
    }

    @MainActor
    private func install(_ encounters: [MonsterEncounter], in view: NotchContentView) {
        view.battleScene.spawnMonsterBatch(encounters)
        view.activateMonster(encounters[0], announce: false)
        view.battleScene.updateWorld(dt: 2)
        XCTAssertTrue(view.battleScene.monsterEngaged)
    }

    private func snapshot(total: Int, at now: Date) -> TokenUsageSnapshot {
        TokenUsageSnapshot(totalTokens: total, inputTokens: total, outputTokens: 0, cacheTokens: 0,
            recentTokens: total, sourceBreakdown: ["Codex": total], eventCount: 1,
            latestEventAt: now, generatedAt: now)
    }

    @MainActor
    func testCampKeepsFreshUsageBudgetsAndSkillEnergyWithoutAttacking() {
        withView(configure: { SkillProgress.setRank(1, for: .pulseBlade) }) { view in
            let enemy = MonsterEncounter(kind: .promptWraith, stage: 100, isBoss: false)
            install([enemy], in: view)
            view.setExpanded(true, animated: false)
            let now = Date()
            view.tokenAccounting = TokenCombatAccounting(seed: 42)
            view.skillEnergy = 12_000
            view.setCamping(true, now: now)
            view.applyUsageSnapshot(snapshot(total: 100, at: now))
            view.applyUsageSnapshot(snapshot(total: 600, at: now.addingTimeInterval(1)))
            let latest = snapshot(total: 1_100, at: now.addingTimeInterval(2))
            view.applyUsageSnapshot(latest)
            view.applyUsageSnapshot(latest)
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: 77, isCrit: false))
            view.tickMonsterAttack(now: now.addingTimeInterval(20))
            XCTAssertEqual(view.todayTokens, 1_100)
            XCTAssertEqual(view.tokenAccounting.pendingTokenCount, 1_000)
            XCTAssertEqual(view.damageBank.pendingPoints, 77)
            XCTAssertEqual(view.skillEnergy, 13_000)
            XCTAssertNil(view.attemptAutoCast(now: now.addingTimeInterval(20)))
            XCTAssertTrue(view.skillCooldowns.isEmpty)
            XCTAssertEqual(view.monsterHealth, 1)
            XCTAssertEqual(view.totalKills, 0)
            XCTAssertEqual(view.heroHealth, 1, "Camp also prevents idle enemy damage")
            XCTAssertTrue(view.battleScene.heroAttackQueue.isEmpty)
            XCTAssertFalse(view.battleScene.animatesCombatEffects)
            XCTAssertFalse(view.compactHeroView.animationsEnabled)
            XCTAssertFalse(view.heroHPBar.animationsEnabled)
            view.setPresentation(visible: true, reduceMotion: false)
            XCTAssertFalse(view.battleScene.animatesCombatEffects)
            XCTAssertFalse(view.compactHeroView.animationsEnabled)
            XCTAssertFalse(view.heroHPBar.animationsEnabled)

            view.setCamping(false, now: now.addingTimeInterval(20))
            XCTAssertFalse(view.tokenAccounting.hasPendingTokens)
            XCTAssertTrue(view.damageBank.isEmpty)
            XCTAssertLessThan(view.monsterHealth, 1 - 77 / CGFloat(enemy.maxHP))
            let healthAfterSpending = view.monsterHealth
            view.setCamping(false, now: now.addingTimeInterval(20))
            view.advanceTokenCombat()
            XCTAssertEqual(view.monsterHealth, healthAfterSpending, "Already spent camp budgets cannot replay")
        }
    }

    @MainActor
    func testDefeatedCampRecoveryRevivesAtTwentyEightPercentWithoutTokens() {
        withView(configure: { SkillTreeProgress.setLevel(3, for: "def_regen_1") }) { view in
            let now = Date()
            view.setCamping(true, now: now)
            view.enterDefeatedState()
            XCTAssertEqual(view.heroMaxHP, 100)
            XCTAssertTrue(view.isDefeated)
            view.tickMonsterAttack(now: now.addingTimeInterval(55))
            XCTAssertEqual(view.heroHealth * 100, 27.5, accuracy: 0.000_001,
                           "Camp uses 0.5 HP/s, without adding the passive regeneration node")
            XCTAssertTrue(view.isDefeated)
            view.tickMonsterAttack(now: now.addingTimeInterval(56))
            XCTAssertEqual(view.heroHealth, 0.28, accuracy: 0.000_001)
            XCTAssertFalse(view.isDefeated)
            XCTAssertFalse(view.battleScene.heroDefeated)
            XCTAssertTrue(view.isCamping)
            view.tickMonsterAttack(now: now.addingTimeInterval(56))
            XCTAssertEqual(view.heroHealth, 0.28, accuracy: 0.000_001)
            view.tickMonsterAttack(now: now.addingTimeInterval(60))
            XCTAssertEqual(view.heroHealth, 0.3, accuracy: 0.000_001)
            XCTAssertFalse(view.hasRealUsageData)
            XCTAssertFalse(view.tokenAccounting.hasPendingTokens)
            XCTAssertEqual(view.totalKills, 0)
        }
    }

    @MainActor
    func testDefeatedCampingUsageCreditsWorkWithoutInstantTokenRevival() {
        withView(configure: { SkillProgress.setRank(1, for: .pulseBlade) }) { view in
            let now = Date()
            view.setCamping(true, now: now)
            view.enterDefeatedState()
            view.applyUsageSnapshot(snapshot(total: 100, at: now))
            view.applyUsageSnapshot(snapshot(total: 1_100, at: now))
            XCTAssertTrue(view.isDefeated, "Camp receives the earned 1 HP, not the normal token-triggered 28% revive")
            XCTAssertEqual(view.heroHealth * CGFloat(view.heroMaxHP), 1, accuracy: 0.000_001)
            XCTAssertEqual(view.tokenAccounting.pendingTokenCount, 1_000)
            XCTAssertEqual(view.skillEnergy, 1_000)
            XCTAssertEqual(view.monsterHealth, 1)
            XCTAssertNil(view.attemptAutoCast(now: now))
        }
    }

    @MainActor
    func testLeavingCampStartsEnemyCooldownWithoutCatchingUpMissedAttacks() {
        withView { view in
            install([MonsterEncounter(kind: .promptWraith, stage: 1, isBoss: false)], in: view)
            view.hasRealUsageData = true
            let now = Date()
            view.setCamping(true, now: now)
            let leaveAt = now.addingTimeInterval(3_600)
            view.tickMonsterAttack(now: leaveAt)
            view.setCamping(false, now: leaveAt)
            XCTAssertEqual(view.lastMonsterAttackAt, leaveAt)
            view.tickMonsterAttack(now: leaveAt)
            view.tickMonsterAttack(now: leaveAt.addingTimeInterval(1))
            XCTAssertEqual(view.heroHealth, 1)
            view.tickMonsterAttack(now: leaveAt.addingTimeInterval(2))
            let afterOneAttack = view.heroHealth
            XCTAssertEqual((1 - afterOneAttack) * CGFloat(view.heroMaxHP), 100 / 900.0, accuracy: 0.000_001)
            view.tickMonsterAttack(now: leaveAt.addingTimeInterval(2))
            XCTAssertEqual(view.heroHealth, afterOneAttack)
            view.tickMonsterAttack(now: leaveAt.addingTimeInterval(3_600))
            XCTAssertEqual((afterOneAttack - view.heroHealth) * CGFloat(view.heroMaxHP), 100 / 900.0,
                           accuracy: 0.000_001, "Even a delayed tick applies only one eligible attack")
        }
    }

    @MainActor
    func testCampCancelsRespawnAndLeavingResumesItExactlyOnce() {
        withView { view in
            let first = MonsterEncounter(kind: .promptWraith, stage: 1, isBoss: false)
            let second = MonsterEncounter(kind: .promptWraith, stage: 2, isBoss: false)
            install([first, second, second], in: view)
            _ = view.damageMonster(by: CGFloat(first.maxHP))
            let cancelled = view.monsterRespawnWorkItem
            XCTAssertNotNil(cancelled)
            let xpAfterKill = view.heroExperience
            let rewardIDs = ItemSystem.recentRewards.map(\.id)
            let now = Date()
            view.setCamping(true, now: now)
            XCTAssertTrue(cancelled?.isCancelled == true)
            XCTAssertNil(view.monsterRespawnWorkItem)
            view.advanceMonsterAfterDefeat()
            view.battleScene.updateWorld(dt: 100)
            XCTAssertEqual(view.battleScene.currentMonsterIndex, 0)
            XCTAssertEqual(view.monsterHealth, 0)
            view.setCamping(false, now: now.addingTimeInterval(60))
            let resumed = view.monsterRespawnWorkItem
            XCTAssertNotNil(resumed)
            view.setCamping(false, now: now.addingTimeInterval(60))
            XCTAssertTrue(view.monsterRespawnWorkItem === resumed)
            view.advanceMonsterAfterDefeat()
            view.advanceMonsterAfterDefeat()
            XCTAssertEqual(view.battleScene.currentMonsterIndex, 1)
            XCTAssertEqual(view.currentStage, second.stage)
            XCTAssertEqual(view.monsterHealth, 1)
            XCTAssertNil(view.monsterRespawnWorkItem)
            XCTAssertEqual(view.totalKills, 1)
            XCTAssertEqual(view.heroExperience, xpAfterKill)
            XCTAssertEqual(ItemSystem.recentRewards.map(\.id), rewardIDs)
        }
    }

    @MainActor
    func testControllerPaysGolemShieldAndPreservesOverkillForTheNextEnemy() {
        withView { view in
            let golem = MonsterEncounter(kind: .cacheGolem, stage: 1, isBoss: false)
            let next = MonsterEncounter(kind: .promptWraith, stage: 2, isBoss: false)
            install([golem, next], in: view)
            let originalShield = view.monsterMechanics.shieldPoints
            XCTAssertEqual(originalShield, CGFloat(golem.maxHP) * 0.2)
            let firstStrike = originalShield / 2
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: firstStrike, isCrit: false))
            XCTAssertEqual(view.monsterHealth, 1)
            XCTAssertEqual(view.monsterMechanics.shieldPoints, originalShield - firstStrike)
            XCTAssertTrue(view.damageBank.isEmpty)
            let secondStrike = originalShield - firstStrike + CGFloat(golem.maxHP) + 77
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: secondStrike, isCrit: true))
            XCTAssertEqual(view.totalKills, 1)
            XCTAssertEqual(view.monsterHealth, 0)
            XCTAssertEqual(view.monsterMechanics.shieldPoints, 0)
            XCTAssertEqual(view.damageBank.pendingPoints, 77, accuracy: 0.000_001)
            XCTAssertEqual(firstStrike + secondStrike,
                           originalShield + CGFloat(golem.maxHP) + view.damageBank.pendingPoints, accuracy: 0.000_001)
            view.advanceMonsterAfterDefeat()
            view.battleScene.updateWorld(dt: 10)
            XCTAssertEqual((1 - view.monsterHealth) * CGFloat(next.maxHP), 77, accuracy: 0.000_001)
            XCTAssertEqual(view.monsterMechanics.maxShieldPoints, 0)
            XCTAssertTrue(view.damageBank.isEmpty)
            view.flushPendingHeroStrikes()
            XCTAssertEqual(view.totalKills, 1)
        }
    }

    @MainActor
    func testActiveSkillShieldAndOverflowConsumeEnergyAndDamageOnlyOnce() {
        withView(configure: { SkillProgress.setRank(1, for: .pulseBlade) }) { view in
            let golem = MonsterEncounter(kind: .cacheGolem, stage: 1, isBoss: false)
            let next = MonsterEncounter(kind: .promptWraith, stage: 2, isBoss: false)
            install([golem, next], in: view)
            view.monsterHealth = 500 / CGFloat(golem.maxHP)
            let shield = view.monsterMechanics.shieldPoints
            view.skillEnergy = 12_000
            let now = Date()
            XCTAssertEqual(view.attemptAutoCast(now: now), .pulseBlade)
            let expectedOverflow: CGFloat = 6_300 - shield - 500
            XCTAssertGreaterThan(expectedOverflow, 0)
            XCTAssertEqual(view.skillEnergy, 0)
            XCTAssertEqual(view.totalKills, 1)
            XCTAssertEqual(view.damageBank.pendingPoints, expectedOverflow, accuracy: 0.000_001)
            let cooldown = view.skillCooldowns[.pulseBlade]
            XCTAssertNotNil(cooldown)
            view.advanceMonsterAfterDefeat()
            view.battleScene.updateWorld(dt: 10)
            XCTAssertEqual((1 - view.monsterHealth) * CGFloat(next.maxHP), expectedOverflow, accuracy: 0.000_001)
            XCTAssertTrue(view.damageBank.isEmpty)
            view.skillEnergy = 12_000
            XCTAssertNil(view.attemptAutoCast(now: now))
            XCTAssertEqual(view.skillEnergy, 12_000)
            XCTAssertEqual(view.skillCooldowns[.pulseBlade], cooldown)
            XCTAssertEqual(view.totalKills, 1)
        }
    }
}
