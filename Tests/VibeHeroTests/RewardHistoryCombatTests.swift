import AppKit
import XCTest
@testable import VibeHero

final class RewardHistoryCombatTests: XCTestCase {
    @MainActor
    private func withView(_ body: (NotchContentView) -> Void) {
        _ = NSApplication.shared
        let name = "VibeHero.RewardCombat.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        defer { store.removePersistentDomain(forName: name) }
        Defaults.withStore(store) {
            Defaults.set(AppLanguage.english.rawValue, forKey: DefaultsKey.language)
            let view = NotchContentView(
                frame: NSRect(origin: .zero, size: NotchStyle.fallbackCollapsed.windowSize),
                collapsedStyle: .fallbackCollapsed, expandedStyle: .fallbackExpanded,
                startMonitors: false, presentationVisible: true, reduceMotion: false
            )
            body(view)
            view.monsterRespawnWorkItem?.cancel()
            view.tokenActivityExpirationWorkItem?.cancel()
            view.battleScene.stopGameLoop()
            view.battleScene.stopBackgroundSimulation()
        }
    }

    @MainActor
    func testHiddenBattleRewardsAreRecordedExactlyOnceAndSurviveReopening() {
        for sessions in [false, true] {
            withView { view in
                if sessions { view.toggleView() }
                _ = view.applyLoot(LootDrop(kind: .gold, amount: 11))
                _ = view.applyLoot(LootDrop(kind: .powerBoost, amount: 60))
                let records = ItemSystem.recentRewards
                XCTAssertEqual(records.count, 2)
                XCTAssertEqual(records.filter { $0.kind == .gold }.count, 1)
                XCTAssertEqual(records.filter { $0.kind == .powerBoost }.count, 1)
                view.setExpanded(true, animated: false)
                view.setExpanded(false, animated: false)
                XCTAssertEqual(ItemSystem.recentRewards.map(\.id), records.map(\.id))
                XCTAssertEqual(ItemSystem.gold, 11)
            }
        }
    }

    @MainActor
    func testPotionHistoryStoresActualFractionalRecoveryIncludingFullHealth() {
        withView { view in
            view.heroHealth = 1 - 0.25 / CGFloat(view.heroMaxHP)
            _ = view.applyLoot(LootDrop(kind: .healthPotion, amount: 30))
            XCTAssertEqual(view.heroHealth, 1)
            XCTAssertEqual(ItemSystem.recentRewards.first?.healedHP ?? -1, 0.25, accuracy: 0.000_001)
            _ = view.applyLoot(LootDrop(kind: .healthPotion, amount: 30))
            XCTAssertEqual(ItemSystem.recentRewards.first?.healedHP, 0)
            XCTAssertEqual(ItemSystem.recentRewards.count, 2)
        }
    }

    @MainActor
    func testInferiorEquipmentSummaryAndHistoryDescribeSalvageInsteadOfEquipping() {
        withView { view in
            let legendary = EquipmentDrop(slot: .weapon, rarity: .legendary)
            let common = EquipmentDrop(slot: .weapon, rarity: .common)
            _ = view.applyLoot(LootDrop(kind: .equipment, amount: legendary.bonusPercent, equipment: legendary))
            let result = view.applyLoot(LootDrop(kind: .equipment, amount: common.bonusPercent, equipment: common))!
            XCTAssertEqual(ItemSystem.equippedRarity(for: .weapon), .legendary)
            XCTAssertEqual(ItemSystem.gold, 5)
            XCTAssertEqual(ItemSystem.recentRewards.count, 2, "Salvage must not also create an ordinary gold entry")
            XCTAssertEqual(ItemSystem.recentRewards.first?.kind, .equipmentSalvaged)
            XCTAssertEqual(ItemSystem.recentRewards.first?.amount, 5)
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                XCTAssertEqual(view.lootSummary(for: result), L10n.string(.equipmentSalvaged, common.displayName, 5))
            }
        }
    }

    @MainActor
    func testBossBonusAndGuaranteedEquipmentProduceTwoDistinctHistoryEntries() {
        withView { view in
            let boss = MonsterEncounter(kind: .promptWraith, stage: 5, isBoss: true)
            view.battleScene.spawnMonsterBatch([boss])
            view.activateMonster(boss, announce: false)
            let reward = view.damageMonster(by: CGFloat(boss.maxHP))
            XCTAssertNotNil(reward)
            XCTAssertEqual(ItemSystem.recentRewards.count, 2)
            XCTAssertEqual(ItemSystem.recentRewards.filter { $0.kind == .bossGold }.count, 1)
            XCTAssertEqual(ItemSystem.recentRewards.filter { $0.kind == .equipmentEquipped }.count, 1)
            XCTAssertEqual(ItemSystem.recentRewards.first(where: { $0.kind == .bossGold })?.amount, reward?.bossGold)
        }
    }
}
