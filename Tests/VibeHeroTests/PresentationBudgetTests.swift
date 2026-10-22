import AppKit
import XCTest
@testable import VibeHero

final class PresentationBudgetTests: XCTestCase {
    private struct Outcome {
        let monsterHP: CGFloat
        let heroHP: CGFloat
        let energy: CGFloat
        let pendingTokens: Decimal
        let pendingDamage: CGFloat
        let kills: Int
    }

    @MainActor
    func testVisibilityAndReducedMotionCannotChangeEarnedDamageHealingOrAutomaticSkills() {
        _ = NSApplication.shared
        var results: [Outcome] = []
        // Include a mode change while 172K tokens still wait in the ledger.
        for mode in 0..<5 {
            let suiteName = "VibeHero.PresentationBudget.\(UUID().uuidString)"
            let store = UserDefaults(suiteName: suiteName)!
            defer { store.removePersistentDomain(forName: suiteName) }
            Defaults.withStore(store) {
                SkillProgress.setRank(1, for: .pulseBlade)
                let view = NotchContentView(
                    frame: NSRect(origin: .zero, size: NotchStyle.fallbackCollapsed.windowSize),
                    collapsedStyle: .fallbackCollapsed, expandedStyle: .fallbackExpanded,
                    startMonitors: false, presentationVisible: true, reduceMotion: false
                )
                defer {
                    view.monsterRespawnWorkItem?.cancel()
                    view.tokenActivityExpirationWorkItem?.cancel()
                    view.battleScene.stopGameLoop()
                    view.battleScene.stopBackgroundSimulation()
                }
                view.setExpanded(mode != 1, animated: false)
                view.setPresentation(visible: mode != 2, reduceMotion: mode == 3)
                let enemy = MonsterEncounter(kind: .promptWraith, stage: 10_000, isBoss: false)
                view.battleScene.spawnMonsterBatch([enemy])
                view.activateMonster(enemy, announce: false)
                view.battleScene.updateWorld(dt: 2)
                XCTAssertTrue(view.battleScene.monsterEngaged)
                let now = Date()
                view.lastPassiveRecoveryAt = now
                view.heroHealth = 0.2
                view.hasRealUsageData = true
                view.tokenActivityExpiresAt = now.addingTimeInterval(100)
                view.tokenAccounting = TokenCombatAccounting(seed: 42)
                view.tickBattle(tokenDelta: 300_000, now: now)
                XCTAssertEqual(view.tokenAccounting.pendingTokenCount, 172_000)
                if mode == 4 { view.setPresentation(visible: false, reduceMotion: true) }
                view.tickMonsterAttack(now: now.addingTimeInterval(2))
                view.tickMonsterAttack(now: now.addingTimeInterval(4))
                results.append(Outcome(monsterHP: view.monsterHealth, heroHP: view.heroHealth,
                    energy: view.skillEnergy, pendingTokens: view.tokenAccounting.pendingTokenCount,
                    pendingDamage: view.damageBank.pendingPoints, kills: view.totalKills))
            }
        }
        let first = results[0]
        XCTAssertLessThan(first.monsterHP, 1)
        XCTAssertEqual(first.heroHP, 1)
        XCTAssertEqual(first.pendingTokens, 0)
        XCTAssertEqual(first.pendingDamage, 0)
        XCTAssertLessThan(first.energy, SkillCharge.maximumEnergy, "A real automatic skill must have cast")
        for result in results.dropFirst() {
            XCTAssertEqual(result.monsterHP, first.monsterHP, accuracy: 0.000_001)
            XCTAssertEqual(result.heroHP, first.heroHP, accuracy: 0.000_001)
            XCTAssertEqual(result.energy, first.energy, accuracy: 0.000_001)
            XCTAssertEqual(result.pendingTokens, first.pendingTokens)
            XCTAssertEqual(result.pendingDamage, first.pendingDamage)
            XCTAssertEqual(result.kills, first.kills)
        }
    }
}
