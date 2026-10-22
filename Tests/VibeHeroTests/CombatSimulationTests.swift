import AppKit
import XCTest
@testable import VibeHero

final class CombatSimulationTests: XCTestCase {
    @MainActor
    private func withView(_ body: (NotchContentView) -> Void) {
        _ = NSApplication.shared
        let suiteName = "VibeHero.CombatTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suiteName)!
        defer { store.removePersistentDomain(forName: suiteName) }
        Defaults.withStore(store) {
            Defaults.set(AppLanguage.english.rawValue, forKey: DefaultsKey.language)
            var view: NotchContentView? = NotchContentView(
                frame: NSRect(origin: .zero, size: NotchStyle.fallbackCollapsed.windowSize),
                collapsedStyle: .fallbackCollapsed, expandedStyle: .fallbackExpanded,
                startMonitors: false, presentationVisible: true, reduceMotion: false
            )
            body(view!)
            view?.monsterRespawnWorkItem?.cancel()
            view?.tokenActivityExpirationWorkItem?.cancel()
            view?.battleScene.stopGameLoop()
            view?.battleScene.stopBackgroundSimulation()
            view = nil
        }
    }

    @MainActor
    private func install(_ encounters: [MonsterEncounter], in view: NotchContentView) {
        view.battleScene.spawnMonsterBatch(encounters)
        view.activateMonster(encounters[0], announce: false)
        view.battleScene.updateWorld(dt: 2)
    }

    @MainActor
    func testColdCollapsedViewEngagesAndSpendsBankedDamageWithoutLayout() {
        withView { view in
            XCTAssertEqual(view.battleScene.bounds.size, .zero)
            XCTAssertNil(view.usageTimer)
            XCTAssertTrue(view.fileMonitors.isEmpty)
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: 100, isCrit: false))
            XCTAssertEqual(view.damageBank.pendingPoints, 100)

            view.battleScene.updateWorld(dt: 2)
            XCTAssertTrue(view.battleScene.monsterEngaged)
            XCTAssertTrue(view.damageBank.isEmpty)
            XCTAssertEqual(view.monsterHealth, 1 - 100.0 / 12_000, accuracy: 0.000_001)
            let position = view.battleScene.heroWorldX
            view.setExpanded(true, animated: false)
            view.setExpanded(false, animated: false)
            view.battleScene.updateWorld(dt: 2)
            XCTAssertEqual(view.battleScene.heroWorldX, position)
        }
    }

    @MainActor
    func testQueuedVisualsCannotChangeDamageWhenCollapsedOrShowingSessions() {
        for switchToSessions in [false, true] {
            withView { view in
                view.setExpanded(true, animated: false)
                view.battleScene.updateWorld(dt: 2)
                for points: CGFloat in [100, 200, 300] {
                    view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: points, isCrit: false))
                }
                XCTAssertEqual(view.battleScene.heroAttackQueue.count, 2)
                let health = view.monsterHealth
                XCTAssertEqual(health, 0.95, accuracy: 0.000_001)
                if switchToSessions {
                    view.toggleView()
                } else {
                    view.setExpanded(false, animated: false)
                }
                XCTAssertTrue(view.battleScene.heroAttackQueue.isEmpty)
                XCTAssertEqual(view.monsterHealth, health)
                view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: 400, isCrit: false))
                XCTAssertEqual(view.monsterHealth, 1 - 1_000.0 / 12_000, accuracy: 0.000_001)
                XCTAssertTrue(view.damageBank.isEmpty)
            }
        }
    }

    @MainActor
    func testOverkillAndDamageReceivedDuringRespawnReachTheNextEnemyOnce() {
        withView { view in
            let first = MonsterEncounter(kind: .promptWraith, stage: 1, isBoss: false)
            let second = MonsterEncounter(kind: .cacheGolem, stage: 2, isBoss: false)
            install([first, second], in: view)
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: CGFloat(first.maxHP) + 100, isCrit: true))
            XCTAssertEqual(view.totalKills, 1)
            XCTAssertEqual(view.monsterHealth, 0)
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: 400, isCrit: false))
            XCTAssertEqual(view.damageBank.pendingPoints, 500)
            let earnedXP = view.heroExperience
            view.flushPendingHeroStrikes()
            view.advanceMonsterAfterDefeat()
            XCTAssertEqual(view.currentMonster, second.kind)
            XCTAssertEqual(view.currentStage, second.stage)
            view.battleScene.updateWorld(dt: 10)

            XCTAssertEqual(view.monsterHealth, 1, "The new Golem shield absorbs the carried budget first")
            XCTAssertEqual(view.monsterMechanics.shieldPoints, CGFloat(second.maxHP) * 0.2 - 500, accuracy: 0.000_001)
            XCTAssertTrue(view.damageBank.isEmpty)
            view.advanceMonsterAfterDefeat()
            view.flushPendingHeroStrikes()
            XCTAssertEqual(view.totalKills, 1)
            XCTAssertEqual(view.heroExperience, earnedXP)
        }
    }

    @MainActor
    func testLargeBudgetCrossesMultipleEnemiesWithoutRepeatingRewards() {
        withView { view in
            let encounter = MonsterEncounter(kind: .promptWraith, stage: 1, isBoss: false)
            install([encounter, encounter, encounter], in: view)
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: CGFloat(encounter.maxHP * 2) + 50, isCrit: false))
            XCTAssertEqual(view.totalKills, 1)
            view.advanceMonsterAfterDefeat()
            view.battleScene.updateWorld(dt: 10)
            XCTAssertEqual(view.totalKills, 2)
            XCTAssertEqual(view.damageBank.pendingPoints, 50, accuracy: 0.000_001)
            view.advanceMonsterAfterDefeat()
            view.battleScene.updateWorld(dt: 10)
            XCTAssertEqual(view.totalKills, 2)
            XCTAssertEqual(view.monsterHealth, 1 - 50.0 / CGFloat(encounter.maxHP), accuracy: 0.000_001)
            XCTAssertTrue(view.damageBank.isEmpty)
        }
    }

    @MainActor
    func testQueuedDamageDoesNotReapplyNewEquipmentOrBoostMultipliers() {
        withView { view in
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: 100, isCrit: false))
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .weapon, rarity: .legendary))
            ItemSystem.activatePowerBoost()
            view.battleScene.updateWorld(dt: 2)
            XCTAssertEqual(view.monsterHealth, 1 - 100.0 / 12_000, accuracy: 0.000_001)
        }
    }

    @MainActor
    func testVisualQueueIsBoundedAndRejectsPreviousMonsterEvents() {
        withView { view in
            view.setExpanded(true, animated: false)
            view.battleScene.updateWorld(dt: 2)
            for _ in 0..<100 {
                view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: 1, isCrit: false))
            }
            XCTAssertEqual(view.battleScene.heroAttackQueue.count, BattleSceneView.maximumPendingVisualAttacks)
            XCTAssertEqual(view.monsterHealth, 1 - 100.0 / 12_000, accuracy: 0.000_001)
            view.battleScene.heroAttackQueue.removeAll()
            view.battleScene.isAttackInProgress = false
            view.battleScene.enqueueHeroAttack(HeroAttackRequest(monsterID: UUID(), damageText: "999", isCrit: true))
            XCTAssertTrue(view.battleScene.heroAttackQueue.isEmpty)
            XCTAssertFalse(view.battleScene.isAttackInProgress)
        }
    }

    @MainActor
    func testRevivingSnapshotAlsoAttacksAndKeepsTokenActivity() {
        withView { view in
            view.battleScene.updateWorld(dt: 2)
            let now = Date()
            _ = view.usageCursor.consume(total: 100, at: now)
            view.enterDefeatedState()
            view.applyUsageSnapshot(TokenUsageSnapshot(
                totalTokens: 150, inputTokens: 150, outputTokens: 0, cacheTokens: 0,
                recentTokens: 50, sourceBreakdown: ["Codex": 150], eventCount: 2,
                latestEventAt: now, generatedAt: now
            ))
            XCTAssertFalse(view.isDefeated)
            XCTAssertEqual(view.heroHealth, CombatTiming.reviveHealth + 0.0005, accuracy: 0.000_001)
            XCTAssertLessThan(view.monsterHealth, 1)
            XCTAssertTrue(view.battleScene.tokenActivity)
            XCTAssertEqual(view.tokenActivityExpiresAt, now.addingTimeInterval(TokenActivity.activeDuration))
        }
    }

    @MainActor
    func testTokenDamageHealingAndEnergyAreIndependentOfScanPartitions() {
        var results: [(damage: CGFloat, health: CGFloat, energy: CGFloat, combo: Int)] = []
        for batches in [[10_000], Array(repeating: 100, count: 100)] {
            withView { view in
                SkillProgress.setRank(1, for: .pulseBlade)
                view.tokenAccounting = TokenCombatAccounting(seed: 42)
                view.heroHealth = 0.2
                let encounter = MonsterEncounter(kind: .promptWraith, stage: 100, isBoss: false)
                install([encounter], in: view)
                let now = Date()
                for batch in batches { view.tickBattle(tokenDelta: batch, now: now) }
                XCTAssertFalse(view.tokenAccounting.hasPendingTokens)
                XCTAssertTrue(view.damageBank.isEmpty)
                results.append(((1 - view.monsterHealth) * CGFloat(encounter.maxHP), view.heroHealth, view.skillEnergy, view.comboCount))
            }
        }
        XCTAssertEqual(results[0].damage, results[1].damage, accuracy: 0.000_001)
        XCTAssertEqual(results[0].health, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(results[0].health, results[1].health, accuracy: 0.000_001)
        XCTAssertEqual(results[0].energy, 10_000, accuracy: 0.000_001)
        XCTAssertEqual(results[0].energy, results[1].energy, accuracy: 0.000_001)
        XCTAssertEqual(results[0].combo, results[1].combo)
    }

    @MainActor
    func testActiveCollapsedLogicalTicksDrainBudgetWithoutNewScansOrAnimations() {
        withView { view in
            view.tokenAccounting = TokenCombatAccounting(seed: 42)
            let encounter = MonsterEncounter(kind: .promptWraith, stage: 10_000, isBoss: false)
            install([encounter], in: view)
            view.hasRealUsageData = true
            view.tokenActivityExpiresAt = Date().addingTimeInterval(100)
            view.heroHealth = 0.2
            view.tickBattle(tokenDelta: 300_000)
            XCTAssertEqual(view.tokenAccounting.pendingTokenCount, 172_000)
            let healthAfterFirstTick = view.monsterHealth
            view.tickMonsterAttack()
            XCTAssertEqual(view.tokenAccounting.pendingTokenCount, 44_000)
            XCTAssertLessThan(view.monsterHealth, healthAfterFirstTick)
            view.tickMonsterAttack()
            XCTAssertFalse(view.tokenAccounting.hasPendingTokens)
            XCTAssertTrue(view.damageBank.isEmpty)
            XCTAssertEqual(view.heroHealth, 1)
            XCTAssertTrue(view.battleScene.heroAttackQueue.isEmpty)
        }
    }

    @MainActor
    func testWaitingTokenBudgetRetainsInputModifiersAndHasNoStageDamageFloor() {
        withView { view in
            view.tokenAccounting = TokenCombatAccounting(seed: 42)
            view.tickBattle(tokenDelta: 1)
            XCTAssertEqual(view.tokenAccounting.pendingTokenCount, 1)
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .weapon, rarity: .legendary))
            ItemSystem.activatePowerBoost()
            let encounter = MonsterEncounter(kind: .promptWraith, stage: 100, isBoss: false)
            install([encounter], in: view)
            let lostHP = (1 - view.monsterHealth) * CGFloat(encounter.maxHP)
            XCTAssertGreaterThan(lostHP, 0)
            XCTAssertLessThan(lostHP, 3)
            XCTAssertFalse(view.tokenAccounting.hasPendingTokens)
        }
    }
}
