import AppKit
import XCTest
@testable import VibeHero

final class EquipmentPresentationTests: XCTestCase {
    @MainActor
    private func withStore(_ body: () -> Void) {
        _ = NSApplication.shared
        let name = "VibeHero.EquipmentPresentation.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        defer { store.removePersistentDomain(forName: name) }
        Defaults.withStore(store) {
            Defaults.set(AppLanguage.english.rawValue, forKey: DefaultsKey.language)
            body()
        }
    }

    @MainActor
    func testUpgradeButtonShowsQuoteAndPerformsOnePaidTierChange() {
        withStore {
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .weapon, rarity: .common))
            let cost = ItemSystem.upgradeOffer(for: .weapon).cost!
            _ = ItemSystem.addGold(cost)
            let tab = EquipmentSettingsTab()
            _ = tab.view
            let row = tab.equipmentRows.first { $0.slot == .weapon }!
            let strings = text(in: row)
            XCTAssertTrue(strings.contains(L10n.string(.equipmentCurrentState, ItemRarity.common.name, L10n.string(.equipmentDetailedWeapon, 4))))
            XCTAssertTrue(strings.contains(L10n.string(.equipmentNextState, ItemRarity.uncommon.name, L10n.string(.equipmentDetailedWeapon, 7))))
            XCTAssertEqual(row.upgradeButton.title, L10n.string(.equipmentUpgradePrice, cost.formatted()))
            XCTAssertTrue(row.upgradeButton.isEnabled)
            XCTAssertEqual(row.upgradeButton.accessibilityLabel(), L10n.string(.equipmentUpgradeAccessibility, EquipmentSlot.weapon.name, ItemRarity.uncommon.name, cost.formatted()))

            row.upgradeButton.performClick(nil)
            XCTAssertEqual(ItemSystem.equippedRarity(for: .weapon), .uncommon)
            XCTAssertEqual(ItemSystem.gold, 0)
            XCTAssertEqual(ItemSystem.recentRewards.first?.kind, .equipmentUpgraded)
            XCTAssertEqual(ItemSystem.recentRewards.first?.amount, cost)
            XCTAssertFalse(row.upgradeButton.isEnabled)
            row.upgradeButton.performClick(nil)
            XCTAssertEqual(ItemSystem.equippedRarity(for: .weapon), .uncommon)
            XCTAssertEqual(ItemSystem.gold, 0)
        }
    }

    @MainActor
    func testEveryLanguageExplainsEmptyMaxedAndInsufficientSlots() {
        withStore {
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .weapon, rarity: .common))
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .armor, rarity: .legendary))
            let tab = EquipmentSettingsTab()
            _ = tab.view
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                tab.refresh()
                let strings = text(in: tab.view)
                XCTAssertTrue(strings.contains(L10n.text(.equipmentSlotEmpty)))
                XCTAssertTrue(strings.contains(L10n.text(.equipmentEmptyReason)))
                XCTAssertTrue(strings.contains(L10n.text(.equipmentMaxedReason)))
                let cost = ItemSystem.upgradeOffer(for: .weapon).cost!
                XCTAssertTrue(strings.contains(L10n.string(.equipmentInsufficientGold, cost.formatted())))
                XCTAssertTrue(strings.contains(L10n.string(.equipmentCurrentState, ItemRarity.legendary.name, L10n.string(.equipmentDetailedArmor, 20))))
                XCTAssertTrue(tab.equipmentRows.allSatisfy { !$0.upgradeButton.isEnabled })
            }
        }
    }

    @MainActor
    func testVisibleTabObservesInventoryLanguageAndBoostTimeThenReleasesResources() {
        withStore {
            var clock = Date(timeIntervalSince1970: 1_700_000_000)
            let tab = EquipmentSettingsTab(now: { clock })
            _ = tab.view
            XCTAssertNil(tab.refreshTimer)
            tab.viewWillAppear()
            let firstTimer = tab.refreshTimer
            tab.viewWillAppear()
            XCTAssertTrue(tab.refreshTimer === firstTimer)
            _ = ItemSystem.addGold(17)
            XCTAssertTrue(text(in: tab.view).contains(L10n.string(.equipmentGoldBalance, 17.formatted())))
            ItemSystem.activatePowerBoost(now: clock)
            XCTAssertTrue(text(in: tab.view).contains(L10n.string(.equipmentBoostActive, 25, 60)))
            clock = clock.addingTimeInterval(61)
            firstTimer?.fire()
            XCTAssertTrue(text(in: tab.view).contains(L10n.text(.equipmentBoostInactive)))
            AppLanguage.save(.japanese)
            XCTAssertTrue(text(in: tab.view).contains(L10n.text(.equipmentRecentRewards)))

            tab.viewWillDisappear()
            XCTAssertNil(tab.refreshTimer)
            XCTAssertEqual(firstTimer?.isValid, false)
            _ = ItemSystem.addGold(3)
            XCTAssertFalse(text(in: tab.view).contains(L10n.string(.equipmentGoldBalance, 20.formatted())))
            tab.viewWillAppear()
            XCTAssertFalse(tab.refreshTimer === firstTimer)
            XCTAssertTrue(text(in: tab.view).contains(L10n.string(.equipmentGoldBalance, 20.formatted())))
            tab.viewWillDisappear()
        }
    }

    @MainActor
    func testHistoryUsesActualFractionalHealingSalvageAndUpgradeAmounts() {
        withStore {
            ItemSystem.recordHealing(0.5)
            let potion = ItemSystem.recentRewards.first!
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .charm, rarity: .common))
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .charm, rarity: .common), goldMultiplier: 1.3)
            let salvage = ItemSystem.recentRewards.first!
            XCTAssertEqual(salvage.amount, 7)
            let cost = ItemSystem.upgradeOffer(for: .charm).cost!
            _ = ItemSystem.addGold(cost)
            _ = ItemSystem.upgradeEquipment(in: .charm)
            let upgrade = ItemSystem.recentRewards.first!
            let tab = EquipmentSettingsTab()
            _ = tab.view
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                tab.refresh()
                let strings = text(in: tab.view)
                XCTAssertTrue(strings.contains(EquipmentSettingsTab.rewardText(potion)))
                XCTAssertTrue(strings.contains(EquipmentSettingsTab.rewardText(salvage)))
                XCTAssertTrue(strings.contains(EquipmentSettingsTab.rewardText(upgrade)))
                XCTAssertTrue(EquipmentSettingsTab.rewardText(potion).contains(0.5.formatted(.number.precision(.fractionLength(0...1)))))
                XCTAssertTrue(EquipmentSettingsTab.rewardText(salvage).contains("7"))
                XCTAssertTrue(EquipmentSettingsTab.rewardText(upgrade).contains(String(cost)))
            }
        }
    }

    @MainActor
    private func text(in view: NSView) -> [String] {
        (view as? NSTextField).map { [$0.stringValue] } ?? view.subviews.flatMap { text(in: $0) }
    }
}
