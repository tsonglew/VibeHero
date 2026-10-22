import XCTest
@testable import VibeHero

final class ItemSystemTests: XCTestCase {
    private func withInventory(_ body: (UserDefaults, String) throws -> Void) rethrows {
        let name = "VibeHero.ItemSystemTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        defer { store.removePersistentDomain(forName: name) }
        try Defaults.withStore(store) { try body(store, name) }
    }

    func testAllUpgradePricesDebitExactlyAndPersistOneCompleteState() {
        withInventory { store, name in
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .weapon, rarity: .common))
            ItemSystem.addGold(450)
            for (index, cost) in [30, 60, 120, 240].enumerated() {
                let oldBalance = ItemSystem.gold
                let target = ItemRarity(rawValue: index + 2)!
                let offer = ItemSystem.upgradeOffer(for: .weapon)
                XCTAssertEqual(offer.status, .available)
                XCTAssertEqual(offer.nextRarity, target)
                XCTAssertEqual(offer.cost, cost)
                XCTAssertEqual(ItemSystem.upgradeEquipment(in: .weapon),
                               .upgraded(EquipmentDrop(slot: .weapon, rarity: target), cost: cost))
                XCTAssertEqual(ItemSystem.gold, oldBalance - cost)
                XCTAssertEqual(ItemSystem.equippedRarity(for: .weapon), target)
                XCTAssertEqual(ItemSystem.recentRewards.first?.amount, cost)
                XCTAssertEqual(ItemSystem.recentRewards.first?.previousRarity?.rawValue, index + 1)
            }
            XCTAssertEqual(ItemSystem.gold, 0)
            XCTAssertEqual(ItemSystem.upgradeOffer(for: .weapon).status, .maxed)
            let persisted = store.string(forKey: DefaultsKey.inventoryState)
            XCTAssertNotNil(persisted)
            XCTAssertNil(store.object(forKey: DefaultsKey.inventoryGold), "New transactions must not split across legacy keys")
            XCTAssertNil(store.object(forKey: DefaultsKey.equipment(slot: "weapon")))
            let reopened = UserDefaults(suiteName: name)!
            Defaults.withStore(reopened) {
                XCTAssertEqual(ItemSystem.gold, 0)
                XCTAssertEqual(ItemSystem.equippedRarity(for: .weapon), .legendary)
                XCTAssertEqual(ItemSystem.recentRewards.filter { $0.kind == .equipmentUpgraded }.count, 4)
            }
        }
    }

    func testEmptyMaxedAndInsufficientUpgradesDoNotChargeOrAppendHistory() {
        withInventory { store, _ in
            ItemSystem.addGold(29)
            var before = store.string(forKey: DefaultsKey.inventoryState)
            XCTAssertEqual(ItemSystem.upgradeOffer(for: .armor).status, .empty)
            XCTAssertEqual(ItemSystem.upgradeEquipment(in: .armor), .empty)
            XCTAssertEqual(store.string(forKey: DefaultsKey.inventoryState), before)

            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .armor, rarity: .common))
            before = store.string(forKey: DefaultsKey.inventoryState)
            XCTAssertEqual(ItemSystem.upgradeOffer(for: .armor).status, .insufficientGold)
            XCTAssertEqual(ItemSystem.upgradeEquipment(in: .armor), .insufficientGold(required: 30, available: 29))
            XCTAssertEqual(store.string(forKey: DefaultsKey.inventoryState), before)

            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .charm, rarity: .legendary))
            before = store.string(forKey: DefaultsKey.inventoryState)
            XCTAssertEqual(ItemSystem.upgradeEquipment(in: .charm), .maxed)
            XCTAssertEqual(store.string(forKey: DefaultsKey.inventoryState), before)
            XCTAssertEqual(ItemSystem.gold, 29)
        }
    }

    func testConsecutivePurchasesRecheckTheCurrentRarityAndBalance() {
        withInventory { _, _ in
            _ = ItemSystem.awardEquipment(EquipmentDrop(slot: .weapon, rarity: .common))
            ItemSystem.addGold(90)
            let displayedOffer = ItemSystem.upgradeOffer(for: .weapon)
            XCTAssertEqual(displayedOffer.cost, 30)
            XCTAssertEqual(ItemSystem.upgradeEquipment(in: .weapon),
                           .upgraded(EquipmentDrop(slot: .weapon, rarity: .uncommon), cost: 30))
            XCTAssertEqual(ItemSystem.upgradeEquipment(in: .weapon),
                           .upgraded(EquipmentDrop(slot: .weapon, rarity: .rare), cost: 60))
            XCTAssertEqual(ItemSystem.upgradeEquipment(in: .weapon), .insufficientGold(required: 120, available: 0))
            XCTAssertEqual(ItemSystem.equippedRarity(for: .weapon), .rare)
            XCTAssertEqual(ItemSystem.recentRewards.filter { $0.kind == .equipmentUpgraded }.count, 2)
        }
    }

    func testAutomaticEquipmentOnlyReplacesWithBetterAndSalvageCreditsOnce() {
        withInventory { _, _ in
            let common = EquipmentDrop(slot: .armor, rarity: .common)
            let rare = EquipmentDrop(slot: .armor, rarity: .rare)
            XCTAssertEqual(ItemSystem.awardEquipment(common), .equipped(common))
            XCTAssertEqual(ItemSystem.awardEquipment(rare), .equipped(rare))
            XCTAssertEqual(ItemSystem.awardEquipment(rare, goldMultiplier: 1.3), .salvaged(rare, gold: 20))
            XCTAssertEqual(ItemSystem.awardEquipment(common, goldMultiplier: 1.3), .salvaged(common, gold: 7))
            XCTAssertEqual(ItemSystem.equippedRarity(for: .armor), .rare)
            XCTAssertEqual(ItemSystem.gold, 27)
            XCTAssertEqual(ItemSystem.recentRewards.count, 4)
            XCTAssertEqual(ItemSystem.recentRewards.filter { $0.kind == .gold }.count, 0)
            XCTAssertEqual(ItemSystem.recentRewards.first?.kind, .equipmentSalvaged)
            XCTAssertEqual(ItemSystem.recentRewards.first?.rarity, .common)
            XCTAssertEqual(ItemSystem.recentRewards.first?.previousRarity, .rare)
        }
    }

    func testLegacyMigrationIsOnceOnlyAndKeepsBackupsUntouched() {
        withInventory { store, name in
            store.set(91, forKey: DefaultsKey.inventoryGold)
            store.set(ItemRarity.uncommon.rawValue, forKey: DefaultsKey.equipment(slot: "weapon"))
            store.set(999, forKey: DefaultsKey.equipment(slot: "armor"))
            store.set(10_060.0, forKey: DefaultsKey.powerBoostExpiry)
            XCTAssertEqual(ItemSystem.gold, 91)
            XCTAssertEqual(ItemSystem.equippedRarity(for: .weapon), .uncommon)
            XCTAssertNil(ItemSystem.equippedRarity(for: .armor))
            XCTAssertEqual(ItemSystem.powerBoostRemaining(now: Date(timeIntervalSince1970: 10_000)), 60)
            XCTAssertTrue(ItemSystem.recentRewards.isEmpty, "Migration is not a newly earned reward")
            _ = ItemSystem.upgradeEquipment(in: .weapon)
            XCTAssertEqual(ItemSystem.gold, 31)
            XCTAssertEqual(store.integer(forKey: DefaultsKey.inventoryGold), 91)
            store.set(9_999, forKey: DefaultsKey.inventoryGold)
            store.set(ItemRarity.legendary.rawValue, forKey: DefaultsKey.equipment(slot: "weapon"))
            Defaults.withStore(UserDefaults(suiteName: name)!) {
                XCTAssertEqual(ItemSystem.gold, 31)
                XCTAssertEqual(ItemSystem.equippedRarity(for: .weapon), .rare)
                XCTAssertEqual(ItemSystem.recentRewards.count, 1)
            }
        }
    }

    func testDamagedCanonicalSaveNeverReimportsSpentLegacyGold() {
        withInventory { store, _ in
            store.set(1_000, forKey: DefaultsKey.inventoryGold)
            store.set("damaged JSON", forKey: DefaultsKey.inventoryState)
            XCTAssertEqual(ItemSystem.gold, 0)
            XCTAssertTrue(ItemSystem.recentRewards.isEmpty)
            ItemSystem.addGold(5)
            XCTAssertEqual(ItemSystem.gold, 5)
            XCTAssertEqual(ItemSystem.recentRewards.count, 1)
            XCTAssertEqual(store.integer(forKey: DefaultsKey.inventoryGold), 1_000)
        }
    }

    func testHistoryIsNewestFirstBoundedAndFailuresDoNotEvictRewards() {
        withInventory { store, _ in
            let start = Date(timeIntervalSince1970: 100_000)
            for amount in 1...45 { ItemSystem.addGold(amount, now: start.addingTimeInterval(Double(amount))) }
            let records = ItemSystem.recentRewards
            XCTAssertEqual(records.count, 40)
            XCTAssertEqual(records.first?.amount, 45)
            XCTAssertEqual(records.last?.amount, 6)
            XCTAssertEqual(records.first?.timestamp, start.addingTimeInterval(45))
            XCTAssertEqual(Set(records.map(\.id)).count, 40)
            let before = store.string(forKey: DefaultsKey.inventoryState)
            XCTAssertEqual(ItemSystem.upgradeEquipment(in: .charm), .empty)
            XCTAssertEqual(store.string(forKey: DefaultsKey.inventoryState), before)
        }
    }

    func testTypedRewardsKeepExactHealingAndAddedBuffSecondsWithoutLocalizedStrings() {
        withInventory { store, _ in
            let now = Date(timeIntervalSince1970: 20_000)
            ItemSystem.recordHealing(0.25, now: now)
            ItemSystem.recordHealing(0, now: now)
            XCTAssertEqual(ItemSystem.activatePowerBoost(now: now), 60)
            XCTAssertEqual(ItemSystem.activatePowerBoost(now: now.addingTimeInterval(10)), 60)
            XCTAssertEqual(ItemSystem.powerBoostRemaining(now: now.addingTimeInterval(10)), 110)
            XCTAssertEqual(ItemSystem.addGold(20, multiplier: 1.3, kind: .bossGold, now: now), 26)
            let records = ItemSystem.recentRewards
            XCTAssertEqual(records.map(\.kind), [.bossGold, .powerBoost, .powerBoost, .healthPotion, .healthPotion])
            XCTAssertEqual(records.last?.healedHP, 0.25)
            XCTAssertEqual(records[3].healedHP, 0)
            let encoded = store.string(forKey: DefaultsKey.inventoryState)!
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                XCTAssertEqual(ItemSystem.recentRewards, records)
                XCTAssertEqual(store.string(forKey: DefaultsKey.inventoryState), encoded)
                XCTAssertFalse(encoded.contains(LootKind.healthPotion.name))
            }
        }
    }

    func testGoldSaturatesAndHistoryStoresOnlyTheActuallyCreditedAmount() {
        withInventory { _, _ in
            XCTAssertEqual(ItemSystem.addGold(Int.max - 3), Int.max - 3)
            XCTAssertEqual(ItemSystem.addGold(10, multiplier: 1.5), 3)
            XCTAssertEqual(ItemSystem.gold, Int.max)
            XCTAssertEqual(ItemSystem.recentRewards.first?.amount, 3)
            XCTAssertEqual(ItemSystem.addGold(10), 0)
            XCTAssertEqual(ItemSystem.recentRewards.first?.amount, 0)
            XCTAssertEqual(ItemSystem.gold, Int.max)
        }
    }

    func testExtremeBuffDatesCannotOverflowDuringMigrationOrRenewal() {
        withInventory { store, _ in
            store.set(1e300, forKey: DefaultsKey.powerBoostExpiry)
            XCTAssertGreaterThan(ItemSystem.powerBoostRemaining(), 0)
            XCTAssertEqual(ItemSystem.activatePowerBoost(), 0)
            XCTAssertEqual(ItemSystem.recentRewards.first?.amount, 0)
            XCTAssertEqual(ItemSystem.activatePowerBoost(now: Date(timeIntervalSince1970: 1e300)), 0)
            XCTAssertEqual(ItemSystem.powerBoostRemaining(now: Date(timeIntervalSince1970: 1e300)), 0)
        }
    }
}
