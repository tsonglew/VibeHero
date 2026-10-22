import AppKit
import XCTest
@testable import VibeHero

final class SkillCombatTests: XCTestCase {
    @MainActor
    private func withView(configure: () -> Void = {}, _ body: (NotchContentView) -> Void) {
        _ = NSApplication.shared
        let suiteName = "VibeHero.SkillCombatTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suiteName)!
        defer { store.removePersistentDomain(forName: suiteName) }
        Defaults.withStore(store) {
            Defaults.set(AppLanguage.english.rawValue, forKey: DefaultsKey.language)
            configure()
            var view: NotchContentView? = NotchContentView(
                frame: NSRect(origin: .zero, size: NotchStyle.fallbackCollapsed.windowSize),
                collapsedStyle: .fallbackCollapsed, expandedStyle: .fallbackExpanded, startMonitors: false, presentationVisible: true, reduceMotion: false
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
    private func engage(_ view: NotchContentView, stage: Int = 10_000) -> CGFloat {
        let encounter = MonsterEncounter(kind: .promptWraith, stage: stage, isBoss: false)
        view.battleScene.spawnMonsterBatch([encounter])
        view.activateMonster(encounter, announce: false)
        view.battleScene.updateWorld(dt: 2)
        return CGFloat(encounter.maxHP)
    }

    @MainActor
    func testAttackAndCritNodesAffectTokenDamageThroughTheUnifiedSnapshot() {
        withView(configure: {
            SkillTreeProgress.setLevel(5, for: "atk_power_1")
            SkillTreeProgress.setLevel(3, for: "atk_crit_1")
            SkillProgress.setRank(1, for: .pulseBlade)
        }) { view in
            let maxHP = engage(view)
            view.tokenAccounting = TokenCombatAccounting(seed: 42)
            let modifiers = SkillTreeProgress.modifiers()
            var expected = TokenCombatAccounting(seed: 42)
            expected.deposit(tokens: 25_000, at: Date(), modifiers: TokenCombatModifiers(
                damagePerToken: modifiers.damageMultiplier,
                critChance: CombatTiming.critChance + Double(modifiers.critChanceBonus)
            ))
            let damage = expected.resolveNext().reduce(CGFloat.zero) { $0 + $1.damagePoints }
            view.tickBattle(tokenDelta: 25_000)
            XCTAssertEqual((1 - view.monsterHealth) * maxHP, damage, accuracy: 0.000_001)
            XCTAssertGreaterThan(modifiers.damageMultiplier, 1.2)
            XCTAssertEqual(modifiers.critChanceBonus, 0.06, accuracy: 0.000_001)
        }
    }

    @MainActor
    func testChargeNodesAndCharmScaleOnlyEnergyAndKeepScanPartitionsEquivalent() {
        var damages: [CGFloat] = []
        for enhanced in [false, true] {
            for batches in [[2_000], Array(repeating: 100, count: 20)] {
                withView(configure: {
                    SkillProgress.setRank(1, for: .pulseBlade)
                    if enhanced {
                        SkillTreeProgress.setLevel(3, for: "atk_speed_1")
                        SkillTreeProgress.setLevel(3, for: "abi_energy_1")
                        _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .charm, rarity: .legendary))
                    }
                }) { view in
                    let maxHP = engage(view)
                    view.tokenAccounting = TokenCombatAccounting(seed: 42)
                    let now = Date()
                    for batch in batches { view.tickBattle(tokenDelta: batch, now: now) }
                    damages.append((1 - view.monsterHealth) * maxHP)
                    let expected: CGFloat = enhanced ? 2_000 * 1.15 * 1.3 * 1.28 : 2_000
                    XCTAssertEqual(view.skillEnergy, expected, accuracy: 0.000_001)
                    XCTAssertTrue(view.skillCooldowns.isEmpty, "Scans must not trigger casts")
                }
            }
        }
        for damage in damages { XCTAssertEqual(damage, damages[0], accuracy: 0.000_001) }
    }

    @MainActor
    func testMaximumHPAndArmorAffectRealDamagePotionHealingAndTokenHealing() {
        withView(configure: {
            SkillTreeProgress.setLevel(5, for: "def_hp_1")
            SkillTreeProgress.setLevel(3, for: "def_armor_1")
        }) { view in
            _ = engage(view)
            XCTAssertEqual(view.heroMaxHP, 130)
            view.heroHealth = 0.5
            let before = view.heroHealth * CGFloat(view.heroMaxHP)
            _ = view.maybeMonsterAttack(now: Date())
            let damage = before - view.heroHealth * CGFloat(view.heroMaxHP)
            XCTAssertEqual(damage, 100 / 900.0 * 0.85, accuracy: 0.000_001)
            let potion = view.applyLoot(LootDrop(kind: .healthPotion, amount: 20))
            XCTAssertEqual(potion?.amount, 20)
            let afterPotion = view.heroHealth * CGFloat(view.heroMaxHP)
            XCTAssertEqual(afterPotion, before - damage + 20, accuracy: 0.000_001)
            view.tickBattle(tokenDelta: 1_000)
            XCTAssertEqual(view.heroHealth * CGFloat(view.heroMaxHP), afterPotion + 1, accuracy: 0.000_001)
            XCTAssertTrue(view.heroHPLabel.stringValue.contains("/130"))
        }
    }

    @MainActor
    func testPreferenceReloadUpdatesMaximumHPImmediatelyAndPreservesHealthFraction() {
        withView { view in
            view.heroHealth = 0.4
            XCTAssertEqual(view.heroMaxHP, 100)
            SkillTreeProgress.setLevel(5, for: "def_hp_1")
            view.reloadPreferences()
            XCTAssertEqual(view.heroMaxHP, 130)
            XCTAssertEqual(view.heroHealth, 0.4)
            XCTAssertTrue(view.heroHPLabel.stringValue.contains("/130"))
            SkillTreeProgress.setLevel(0, for: "def_hp_1")
            view.reloadPreferences()
            XCTAssertEqual(view.heroMaxHP, 100)
            XCTAssertEqual(view.heroHealth, 0.4)
        }
    }

    @MainActor
    func testRegenerationUsesElapsedSecondsAndFixedHPWithoutReviving() {
        for intervals in [[10.0], Array(repeating: 1.0, count: 10)] {
            withView(configure: {
                SkillTreeProgress.setLevel(3, for: "def_regen_1")
                SkillTreeProgress.setLevel(5, for: "def_hp_1")
            }) { view in
                var now = Date()
                view.lastPassiveRecoveryAt = now
                view.heroHealth = 0.2
                for elapsed in intervals {
                    now = now.addingTimeInterval(elapsed)
                    view.tickMonsterAttack(now: now)
                }
                XCTAssertEqual(view.heroHealth * CGFloat(view.heroMaxHP), 26.3, accuracy: 0.000_001)
                XCTAssertLessThan(view.skillModifiers.hpRegenPointsPerSecond, 100 / 900.0 / CombatTiming.monsterAttackInterval)
                view.enterDefeatedState()
                view.tickMonsterAttack(now: now.addingTimeInterval(100))
                XCTAssertEqual(view.heroHealth, 0)
                XCTAssertTrue(view.isDefeated)
            }
        }
    }

    @MainActor
    func testHighestReadySkillReservesEnergyAndCooldownAllowsLowerSkill() {
        withView(configure: {
            SkillProgress.setRank(1, for: .pulseBlade)
            SkillProgress.setRank(1, for: .overclockCore)
        }) { view in
            _ = engage(view)
            let now = Date()
            view.skillEnergy = 12_000
            XCTAssertNil(view.attemptAutoCast(now: now))
            XCTAssertEqual(view.skillEnergy, 12_000)
            XCTAssertTrue(view.skillCooldowns.isEmpty)
            view.skillEnergy = 40_000
            XCTAssertEqual(view.attemptAutoCast(now: now), .overclockCore)
            XCTAssertEqual(view.skillEnergy, 0)
            XCTAssertEqual(view.skillCooldowns[.overclockCore], now.addingTimeInterval(28))
            view.skillEnergy = 12_000
            XCTAssertEqual(view.attemptAutoCast(now: now.addingTimeInterval(1)), .pulseBlade)
            XCTAssertEqual(view.skillCooldowns[.overclockCore], now.addingTimeInterval(28))
        }
    }

    @MainActor
    func testLogicalTickCastsAtMostOnceAndEnergyCannotExceedFortyThousand() {
        withView(configure: {
            SkillProgress.setRank(1, for: .pulseBlade)
            SkillProgress.setRank(1, for: .tokenVolley)
        }) { view in
            _ = engage(view)
            let now = Date()
            view.hasRealUsageData = true
            view.tokenActivityExpiresAt = now.addingTimeInterval(100)
            view.gainSkillEnergy(by: CGFloat(Int.max))
            XCTAssertEqual(view.skillEnergy, 40_000)
            view.tickMonsterAttack(now: now)
            XCTAssertEqual(view.skillCooldowns.count, 1)
            XCTAssertNotNil(view.skillCooldowns[.tokenVolley])
            XCTAssertEqual(view.skillEnergy, 24_000)
            view.tickMonsterAttack(now: now.addingTimeInterval(2))
            XCTAssertEqual(view.skillCooldowns.count, 2)
            XCTAssertEqual(view.skillEnergy, 12_000)
        }
    }

    @MainActor
    func testDisabledWalkingAndDefeatedSkillsSpendNothing() {
        withView(configure: { SkillProgress.setRank(1, for: .pulseBlade) }) { view in
            let now = Date()
            view.skillEnergy = 40_000
            XCTAssertNil(view.attemptAutoCast(now: now), "Walking has no target")
            _ = engage(view)
            SkillProgress.setAutoCastEnabled(false, for: .pulseBlade)
            XCTAssertNil(view.attemptAutoCast(now: now))
            SkillProgress.setAutoCastEnabled(true, for: .pulseBlade)
            view.enterDefeatedState()
            XCTAssertNil(view.attemptAutoCast(now: now))
            XCTAssertEqual(view.skillEnergy, 40_000)
            XCTAssertTrue(view.skillCooldowns.isEmpty)
        }
    }

    @MainActor
    func testSkillDamageAndCooldownUseBuildAndDoNotWaitForAnimations() {
        withView(configure: {
            SkillProgress.setRank(1, for: .pulseBlade)
            SkillTreeProgress.setLevel(3, for: "abi_power_1")
            SkillTreeProgress.setLevel(3, for: "abi_cd_1")
        }) { view in
            view.setExpanded(true, animated: false)
            let maxHP = engage(view)
            let now = Date()
            view.skillEnergy = 12_000
            XCTAssertEqual(view.attemptAutoCast(now: now), .pulseBlade)
            XCTAssertEqual((1 - view.monsterHealth) * maxHP, 6_000 * 1.05 * 1.26, accuracy: 0.000_001)
            XCTAssertEqual(view.skillCooldowns[.pulseBlade]!.timeIntervalSince(now), 14 * 0.8, accuracy: 0.000_001)
            let health = view.monsterHealth
            view.setExpanded(false, animated: false)
            XCTAssertEqual(view.monsterHealth, health)
            XCTAssertEqual(view.skillEnergy, 0)
            XCTAssertTrue(view.damageBank.isEmpty)
            view.skillEnergy = 12_000
            XCTAssertNil(view.attemptAutoCast(now: now.addingTimeInterval(11)))
            XCTAssertEqual(view.skillEnergy, 12_000)
            XCTAssertEqual(view.attemptAutoCast(now: now.addingTimeInterval(11.2)), .pulseBlade)
        }
    }

    @MainActor
    func testSkillOverkillCarriesAcrossEnemiesExactlyOnce() {
        withView(configure: { SkillProgress.setRank(1, for: .pulseBlade) }) { view in
            let first = MonsterEncounter(kind: .promptWraith, stage: 1, isBoss: false)
            let second = MonsterEncounter(kind: .cacheGolem, stage: 2, isBoss: false)
            view.battleScene.spawnMonsterBatch([first, second])
            view.activateMonster(first, announce: false)
            view.battleScene.updateWorld(dt: 2)
            view.monsterHealth = 500 / CGFloat(first.maxHP)
            view.skillEnergy = 12_000
            XCTAssertEqual(view.attemptAutoCast(now: Date()), .pulseBlade)
            XCTAssertEqual(view.totalKills, 1)
            XCTAssertEqual(view.damageBank.pendingPoints, 5_800, accuracy: 0.000_001)
            view.advanceMonsterAfterDefeat()
            view.battleScene.updateWorld(dt: 10)
            XCTAssertEqual(view.monsterMechanics.shieldPoints, 0)
            XCTAssertEqual((1 - view.monsterHealth) * CGFloat(second.maxHP), 5_800 - CGFloat(second.maxHP) * 0.2, accuracy: 0.000_001)
            XCTAssertTrue(view.damageBank.isEmpty)
            XCTAssertEqual(view.totalKills, 1)
        }
    }

    @MainActor
    func testGoldAndExperienceUseUnifiedModifiersAndReportAwardedAmounts() {
        withView(configure: {
            SkillTreeProgress.setLevel(5, for: "eco_gold_1")
            SkillTreeProgress.setLevel(3, for: "eco_xp_1")
        }) { view in
            let gold = view.applyLoot(LootDrop(kind: .gold, amount: 10))
            XCTAssertEqual(gold?.amount, 13)
            XCTAssertEqual(ItemSystem.gold, 13)
            let weapon = EquipmentDrop(slot: .weapon, rarity: .common)
            _ = view.applyLoot(LootDrop(kind: .equipment, amount: 4, equipment: weapon))
            _ = view.applyLoot(LootDrop(kind: .equipment, amount: 4, equipment: weapon))
            XCTAssertEqual(ItemSystem.gold, 20, "5 salvage gold × 1.3 rounds to 7")
            let beforeXP = view.heroExperience
            let reward = view.grantExperience(for: .promptWraith, isBoss: false, stage: 1)
            let expectedXP = Int((CGFloat(MonsterKind.promptWraith.xpReward) * 1.2).rounded())
            XCTAssertEqual(reward.xpGained, expectedXP)
            XCTAssertEqual(view.heroExperience - beforeXP, expectedXP)
        }
    }

    @MainActor
    func testBossGoldUsesTheSameBonusAndReportsItsActualDeposit() {
        withView(configure: { SkillTreeProgress.setLevel(5, for: "eco_gold_1") }) { view in
            let boss = MonsterEncounter(kind: .promptWraith, stage: 5, isBoss: true)
            view.battleScene.spawnMonsterBatch([boss])
            view.activateMonster(boss, announce: false)
            view.battleScene.updateWorld(dt: 2)
            let reward = view.damageMonster(by: CGFloat(boss.maxHP))
            XCTAssertNotNil(reward)
            XCTAssertGreaterThanOrEqual(reward?.bossGold ?? 0, 26)
            XCTAssertLessThanOrEqual(reward?.bossGold ?? 0, 52)
            XCTAssertEqual(ItemSystem.gold, reward?.bossGold)
            XCTAssertEqual(reward?.loot?.kind, .equipment)
        }
    }

    func testEmptyDropRescueNeverChangesExistingRewardsOrAddsAnotherEmptyRoll() {
        XCTAssertNil(ItemSystem.rollDrop(emptyDropRescueChance: 0, roll: 99, rescueRoll: 0))
        XCTAssertNil(ItemSystem.rollDrop(emptyDropRescueChance: 0.2, roll: 99, rescueRoll: 0.3))
        for _ in 0..<100 {
            XCTAssertNotNil(ItemSystem.rollDrop(emptyDropRescueChance: 1, roll: 99, rescueRoll: 0.999))
        }
        for roll in 0..<84 {
            XCTAssertEqual(ItemSystem.rollDrop(roll: roll)?.kind,
                           ItemSystem.rollDrop(emptyDropRescueChance: 1, roll: roll, rescueRoll: 0)?.kind)
        }
        XCTAssertEqual(ItemSystem.rollDrop(isBoss: true, roll: 99)?.kind, .equipment)
    }
}
