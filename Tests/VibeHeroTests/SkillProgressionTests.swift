import AppKit
import XCTest
@testable import VibeHero

final class SkillProgressionTests: XCTestCase {
    @MainActor
    private func withStore(level: Int = 20, _ body: () -> Void) {
        _ = NSApplication.shared
        let name = "VibeHero.SkillProgression.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        defer { store.removePersistentDomain(forName: name) }
        Defaults.withStore(store) {
            Defaults.set(AppLanguage.english.rawValue, forKey: DefaultsKey.language)
            SkillProgress.saveHeroLevel(level)
            body()
        }
    }

    @MainActor
    func testUnlearnedBuildHasNeutralEffectsAndSingleNodeDoesNotZeroOthers() {
        withStore {
            XCTAssertEqual(SkillTreeProgress.modifiers(), SkillModifiers())
            XCTAssertTrue(SkillTreeProgress.upgradeNode("atk_power_1"))
            let value = SkillTreeProgress.modifiers()
            XCTAssertEqual(value.damageMultiplier, 1.05, accuracy: 0.000_001)
            XCTAssertEqual(value.maxHPMultiplier, 1)
            XCTAssertEqual(value.goldMultiplier, 1)
            XCTAssertEqual(value.cooldownMultiplier, 1)
            XCTAssertEqual(value.hpRegenPointsPerSecond, 0)
        }
    }

    @MainActor
    func testEveryEffectKindFeedsItsNamedModifierWithCorrectUnits() {
        withStore {
            let allocations = ["atk_power_1": 2, "atk_crit_1": 2, "atk_speed_1": 3,
                               "def_hp_1": 2, "def_armor_1": 2, "def_regen_1": 1,
                               "eco_gold_1": 2, "eco_loot_1": 2, "eco_xp_1": 2,
                               "abi_cd_1": 2, "abi_power_1": 2, "abi_energy_1": 2]
            for (id, rank) in allocations { SkillTreeProgress.setLevel(rank, for: id) }
            SkillProgress.setRank(1, for: .pulseBlade)
            let value = SkillTreeProgress.modifiers()
            XCTAssertEqual(value.damageMultiplier, 1.08 * 1.05, accuracy: 0.000_001)
            XCTAssertEqual(value.critChanceBonus, 0.04, accuracy: 0.000_001)
            XCTAssertEqual(value.attackChargeMultiplier, 1.15, accuracy: 0.000_001)
            XCTAssertEqual(value.maxHPMultiplier, 1.15, accuracy: 0.000_001)
            XCTAssertEqual(value.damageReduction, 0.10, accuracy: 0.000_001)
            XCTAssertEqual(value.hpRegenPointsPerSecond, 0.01, accuracy: 0.000_001)
            XCTAssertEqual(value.goldMultiplier, 1.15, accuracy: 0.000_001)
            XCTAssertEqual(value.emptyDropRescueChance, 0.10, accuracy: 0.000_001)
            XCTAssertEqual(value.xpMultiplier, 1.15, accuracy: 0.000_001)
            XCTAssertEqual(value.cooldownMultiplier, 0.85, accuracy: 0.000_001)
            XCTAssertEqual(value.skillDamageMultiplier, 1.18, accuracy: 0.000_001)
            XCTAssertEqual(value.energyChargeMultiplier, 1.20, accuracy: 0.000_001)
            XCTAssertEqual(SkillProgress.damageMultiplier(), value.damageMultiplier)
        }
    }

    @MainActor
    func testCooldownRanksAlwaysReduceTimeAndRegenRemainsBelowBaseIdleDamage() {
        withStore {
            for id in ["abi_cd_1", "abi_cd_2", "abi_arcane"] {
                let node = SkillTreeData.node(byID: id)!
                var previous: CGFloat = 1
                for rank in 1...node.maxLevel {
                    let next = node.effect.value(at: rank)
                    XCTAssertLessThan(next, previous)
                    previous = next
                }
                SkillTreeProgress.setLevel(node.maxLevel, for: id)
            }
            XCTAssertEqual(SkillTreeProgress.modifiers().cooldownMultiplier, 0.8 * 0.75 * 0.6, accuracy: 0.000_001)
            SkillTreeProgress.setLevel(3, for: "def_regen_1")
            XCTAssertEqual(SkillTreeProgress.modifiers().hpRegenPointsPerSecond, 0.03, accuracy: 0.000_001)
            XCTAssertEqual(SkillTreeData.node(byID: "def_regen_1")?.effect.formattedValue(at: 1), "0.01 HP/sec")
            XCTAssertEqual(SkillTreeData.node(byID: "abi_cd_1")?.effect.formattedValue(at: 2), "−15.0%")
        }
    }

    @MainActor
    func testActiveAndPassiveUpgradesShareOneBudget() {
        withStore(level: 3) {
            XCTAssertTrue(SkillProgress.upgrade(.pulseBlade))
            XCTAssertTrue(SkillTreeProgress.upgradeNode("atk_power_1"))
            XCTAssertTrue(SkillTreeProgress.upgradeNode("def_hp_1"))
            XCTAssertEqual(SkillTreeProgress.availablePoints(), 0)
            XCTAssertEqual(SkillProgress.availablePoints(), 0)
            XCTAssertEqual(SkillProgress.spentPoints(), 3)
            XCTAssertFalse(SkillProgress.upgrade(.tokenVolley))
            XCTAssertFalse(SkillTreeProgress.upgradeNode("eco_gold_1"))
            XCTAssertTrue(SkillTreeProgress.downgradeNode("def_hp_1"))
            XCTAssertTrue(SkillProgress.upgrade(.tokenVolley))
            XCTAssertEqual(SkillTreeProgress.availablePoints(), 0)
        }
    }

    @MainActor
    func testMigrationPreservesBothAllocationsAndRefundsCannotCreatePoints() {
        withStore(level: 3) {
            Defaults.set(3, forKey: DefaultsKey.skillRank("pulseBlade"))
            Defaults.set(2, forKey: DefaultsKey.skillRank("tokenVolley"))
            Defaults.set(2, forKey: DefaultsKey.skillTreeNode("atk_power_1"))
            Defaults.set(1, forKey: DefaultsKey.skillTreeNode("atk_power_2"))
            Defaults.set(999, forKey: DefaultsKey.skillTreeAvailablePoints)
            SkillProgress.setAutoCastEnabled(false, for: .pulseBlade)
            XCTAssertEqual(SkillTreeProgress.totalSpentPoints(), 8)
            XCTAssertEqual(SkillTreeProgress.migrationCredit, 5)
            XCTAssertEqual(SkillTreeProgress.availablePoints(), 0)
            XCTAssertEqual(SkillProgress.rank(for: .pulseBlade), 3)
            XCTAssertFalse(SkillProgress.isAutoCastEnabled(.pulseBlade))
            XCTAssertTrue(SkillTreeProgress.migrationNoticePending)
            SkillTreeProgress.dismissMigrationNotice()

            XCTAssertTrue(SkillTreeProgress.downgradeNode("atk_power_2"))
            XCTAssertTrue(SkillTreeProgress.downgradeNode("atk_power_1"))
            XCTAssertTrue(SkillTreeProgress.downgradeNode("atk_power_1"))
            for _ in 0..<2 { XCTAssertTrue(SkillProgress.downgrade(.tokenVolley)) }
            for _ in 0..<3 { XCTAssertTrue(SkillProgress.downgrade(.pulseBlade)) }
            for _ in 0..<5 {
                XCTAssertFalse(SkillProgress.downgrade(.pulseBlade))
                XCTAssertEqual(SkillTreeProgress.migrationCredit, 5)
                XCTAssertEqual(SkillTreeProgress.availablePoints(), 8)
                XCTAssertFalse(SkillTreeProgress.migrationNoticePending)
            }
            XCTAssertEqual(Defaults.int(forKey: DefaultsKey.skillRank("pulseBlade")), 3, "Old keys remain a backup, never a second budget")
            SkillProgress.saveHeroLevel(4)
            XCTAssertEqual(SkillTreeProgress.availablePoints(), 9)
            XCTAssertTrue(SkillProgress.upgrade(.pulseBlade))
            XCTAssertEqual(SkillTreeProgress.availablePoints(), 8)
        }
    }

    @MainActor
    func testMigrationClampsMalformedLegacyRanksBeforeCalculatingCredit() {
        withStore(level: 1) {
            Defaults.set(Int.max, forKey: DefaultsKey.skillRank("pulseBlade"))
            Defaults.set(-5, forKey: DefaultsKey.skillRank("tokenVolley"))
            Defaults.set(Int.max, forKey: DefaultsKey.skillTreeNode("atk_power_1"))
            XCTAssertEqual(SkillTreeProgress.totalSpentPoints(), 8)
            XCTAssertEqual(SkillTreeProgress.migrationCredit, 7)
            XCTAssertEqual(SkillProgress.rank(for: .pulseBlade), 3)
            XCTAssertEqual(SkillProgress.rank(for: .tokenVolley), 0)
        }
    }

    @MainActor
    func testStoredUnknownAndOutOfRangeRanksDoNotCorruptBudget() {
        withStore {
            let value: [String: Any] = [
                "nodeRanks": ["atk_power_1": 99, "def_hp_1": -2, "unknown": Int.max],
                "activeRanks": ["pulseBlade": 2], "migrationCredit": 0, "migrationNoticePending": false
            ]
            let data = try! JSONSerialization.data(withJSONObject: value)
            Defaults.set(String(data: data, encoding: .utf8)!, forKey: DefaultsKey.skillBuild)
            XCTAssertEqual(SkillTreeProgress.totalSpentPoints(), 7)
            XCTAssertEqual(SkillTreeProgress.availablePoints(), 13)
            XCTAssertEqual(SkillTreeProgress.modifiers().damageMultiplier, 1.17 * 1.1, accuracy: 0.000_001)
        }
    }

    @MainActor
    func testMalformedCreditAndExtremeLevelCannotOverflowPointBudget() {
        withStore(level: Int.max) {
            for credit in [Int.min, Int.max] {
                let value: [String: Any] = ["nodeRanks": [:], "activeRanks": [:],
                                           "migrationCredit": credit, "migrationNoticePending": false]
                let data = try! JSONSerialization.data(withJSONObject: value)
                Defaults.set(String(data: data, encoding: .utf8)!, forKey: DefaultsKey.skillBuild)
                XCTAssertEqual(SkillTreeProgress.availablePoints(), Int.max)
                XCTAssertGreaterThanOrEqual(SkillTreeProgress.migrationCredit, 0)
                XCTAssertLessThan(SkillTreeProgress.migrationCredit, 1000)
            }
        }
    }

    @MainActor
    func testRefundsOnlyBlockWhenARequiredRankWouldBeLost() {
        withStore {
            SkillTreeProgress.setLevel(3, for: "atk_power_1")
            SkillTreeProgress.setLevel(1, for: "atk_power_2")
            XCTAssertTrue(SkillTreeProgress.downgradeNode("atk_power_1"))
            XCTAssertTrue(SkillTreeProgress.downgradeNode("atk_power_1"))
            XCTAssertFalse(SkillTreeProgress.downgradeNode("atk_power_1"))
            XCTAssertNotNil(SkillTreeProgress.nodeRefundBlockReason("atk_power_1"))
            XCTAssertTrue(SkillTreeProgress.downgradeNode("atk_power_2"))
            XCTAssertTrue(SkillTreeProgress.downgradeNode("atk_power_1"))
            SkillProgress.setRank(3, for: .pulseBlade)
            SkillProgress.setRank(1, for: .wraithMark)
            XCTAssertTrue(SkillProgress.downgrade(.pulseBlade))
            XCTAssertFalse(SkillProgress.downgrade(.pulseBlade))
            XCTAssertTrue(SkillProgress.downgrade(.wraithMark))
            XCTAssertTrue(SkillProgress.downgrade(.pulseBlade))
        }
    }

    @MainActor
    func testCachedNodesResolveTheirNamesAndEffectUnitsInCurrentLanguage() {
        withStore {
            let node = SkillTreeData.node(byID: "atk_speed_1")!
            XCTAssertEqual(node.name, "Offensive Charge")
            Defaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: DefaultsKey.language)
            XCTAssertEqual(node.name, "攻势充能")
            XCTAssertEqual(SkillTreeData.node(byID: "def_regen_1")?.effect.formattedValue(at: 1), "每秒 0.01 生命点")
            Defaults.set(AppLanguage.japanese.rawValue, forKey: DefaultsKey.language)
            XCTAssertEqual(node.name, "攻勢チャージ")
            XCTAssertEqual(SkillTreeData.node(byID: "def_regen_1")?.effect.formattedValue(at: 1), "毎秒 0.01 HP")
        }
    }

    @MainActor
    func testTreeButtonsUpgradeRefundAndKeepRootVisible() {
        withStore(level: 4) {
            let tree = SkillTreeView(frame: NSRect(x: 0, y: 0, width: 592, height: 760))
            tree.layoutSubtreeIfNeeded()
            let root = tree.treeCanvas.subviews.compactMap { $0 as? NSButton }.first {
                $0.accessibilityLabel()?.hasPrefix("Power Strike I\n") == true
            }
            XCTAssertNotNil(root)
            XCTAssertTrue(tree.treeCanvas.visibleRect.contains(root!.frame))
            tree.detailPanel.upgradeButton.performClick(nil)
            XCTAssertEqual(SkillTreeProgress.level(for: "atk_power_1"), 1)
            tree.treeCanvas.selectNode(id: "atk_speed_1")
            tree.detailPanel.upgradeButton.performClick(nil)
            XCTAssertEqual(SkillTreeProgress.level(for: "atk_speed_1"), 1)
            tree.treeCanvas.selectNode(id: "atk_power_1")
            XCTAssertFalse(tree.detailPanel.downgradeButton.isEnabled)
            tree.treeCanvas.selectNode(id: "atk_speed_1")
            tree.detailPanel.downgradeButton.performClick(nil)
            XCTAssertEqual(SkillTreeProgress.level(for: "atk_speed_1"), 0)
        }
    }
}
