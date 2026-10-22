import AppKit
import XCTest
@testable import VibeHero

final class EncounterPresentationTests: XCTestCase {
    @MainActor
    private func withView(camping: Bool = false, _ body: (NotchContentView) -> Void) {
        _ = NSApplication.shared
        let suite = "VibeHero.EncounterPresentation.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        Defaults.withStore(store) {
            CampProgress.save(camping)
            let styles = NotchStyle.styles(for: nil)
            var view: NotchContentView? = NotchContentView(
                frame: NSRect(origin: .zero, size: styles.expanded.windowSize),
                collapsedStyle: styles.collapsed, expandedStyle: styles.expanded,
                startMonitors: false, presentationVisible: true, reduceMotion: false
            )
            view!.setExpanded(true, animated: false)
            view!.layoutSubtreeIfNeeded()
            body(view!)
            view?.monsterRespawnWorkItem?.cancel()
            view?.tokenActivityExpirationWorkItem?.cancel()
            view?.battleScene.stopGameLoop()
            view?.battleScene.stopBackgroundSimulation()
            view = nil
        }
    }

    @MainActor
    private func engage(_ view: NotchContentView, kind: MonsterKind, isBoss: Bool = false) -> MonsterEncounter {
        let encounter = MonsterEncounter(kind: kind, stage: 5, isBoss: isBoss)
        view.battleScene.spawnMonsterBatch([encounter])
        view.activateMonster(encounter, announce: false)
        view.battleScene.updateWorld(dt: 2)
        view.layoutSubtreeIfNeeded()
        return encounter
    }

    @MainActor
    func testCampButtonLoadsRestPreferenceAndProvidesAKeyboardActionInEveryLanguage() {
        withView(camping: true) { view in
            XCTAssertTrue(view.isCamping)
            XCTAssertTrue(view.battleScene.combatPaused)
            XCTAssertEqual(view.campButton.frame, view.reservedHeaderActionFrame)
            XCTAssertFalse(view.campButton.refusesFirstResponder)
            XCTAssertFalse(view.campButton.frame.intersects(view.viewToggleButton.frame))
            XCTAssertFalse(view.campButton.frame.intersects(view.settingsButton.frame))
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                view.reloadLocalizedText()
                XCTAssertEqual(view.campButton.state, .on)
                XCTAssertEqual(view.campButton.accessibilityLabel(), L10n.text(.campLeave))
                XCTAssertEqual(view.campButton.accessibilityHelp(), L10n.text(.campRules))
                XCTAssertTrue(view.campButton.toolTip?.contains(L10n.text(.campRules)) == true)
                view.campButton.performClick(nil)
                XCTAssertFalse(view.isCamping)
                XCTAssertFalse(CampProgress.load())
                XCTAssertEqual(view.campButton.state, .off)
                XCTAssertEqual(view.campButton.accessibilityLabel(), L10n.text(.campEnter))
                view.campButton.performClick(nil)
                XCTAssertTrue(view.isCamping)
                XCTAssertTrue(CampProgress.load())
            }
        }
    }

    @MainActor
    func testCampRemainsVisibleWithoutUsageAndWhileSessionsAreOpen() {
        withView(camping: true) { view in
            view.hasRealUsageData = false
            view.heroHealth = 0
            view.isDefeated = true
            view.skillEnergy = 12_500
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                view.reloadLocalizedText()
                XCTAssertEqual(view.compactStatusLabel.stringValue, L10n.text(.campStatusShort))
                XCTAssertEqual(view.mechanicLabel.stringValue, L10n.text(.campRecovering))
                XCTAssertEqual(view.skillEnergyLabel.stringValue,
                    L10n.string(.campPausedSkill, view.formatTokens(12_500), view.formatTokens(40_000)))
                XCTAssertLessThanOrEqual(view.skillEnergyLabel.intrinsicContentSize.width, view.skillEnergyLabel.bounds.width + 1)
                XCTAssertTrue(view.compactHeroView.accessibilityLabel()?.contains(L10n.text(.campStatusShort)) == true)
            }
            view.toggleView()
            XCTAssertTrue(view.gameHUD.isHidden)
            XCTAssertFalse(view.campButton.isHidden)
            XCTAssertEqual(view.titleLabel.stringValue, L10n.text(.activeSessions))
            view.campButton.performClick(nil)
            XCTAssertFalse(view.isCamping)
            XCTAssertEqual(view.titleLabel.stringValue, L10n.text(.activeSessions))
        }
    }

    @MainActor
    func testShieldAndBossPhaseUseASeparateLocalizedLineWithoutReplacingRewards() {
        withView { view in
            let encounter = engage(view, kind: .cacheGolem, isBoss: true)
            let maximumHP = CGFloat(encounter.maxHP)
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                view.monsterMechanics = MonsterMechanicsState(encounter: encounter)
                view.monsterHealth = 1
                let reward = L10n.string(.lootPotionExactSummary, "0.5")
                view.combatLabel.stringValue = reward
                view.refreshEncounterPresentation()
                XCTAssertTrue(view.mechanicLabel.stringValue.contains(L10n.text(.bossPhase1Status)))
                XCTAssertTrue(view.mechanicLabel.stringValue.contains(L10n.string(.monsterShieldStatus,
                    Double(view.monsterMechanics.shieldPoints), Double(view.monsterMechanics.maxShieldPoints))))
                _ = view.monsterMechanics.applyDamage(view.monsterMechanics.shieldPoints + maximumHP * 0.5,
                    remainingHP: maximumHP, maximumHP: maximumHP)
                view.monsterHealth = 0.5
                view.refreshEncounterPresentation()
                XCTAssertTrue(view.mechanicLabel.stringValue.contains(L10n.string(.bossPhase2Status, 50)))
                XCTAssertEqual(view.combatLabel.stringValue, reward)
                XCTAssertTrue(view.mechanicLabel.toolTip?.contains(L10n.text(.bossPhaseDetails)) == true)
                XCTAssertLessThanOrEqual(view.mechanicLabel.intrinsicContentSize.width, view.mechanicLabel.bounds.width + 1)
                XCTAssertFalse(view.mechanicLabel.frame.intersects(view.combatLabel.frame))
                let actor = view.battleScene.heroView.convert(view.battleScene.heroView.bounds, to: view.gameHUD)
                XCTAssertGreaterThanOrEqual(view.mechanicLabel.frame.minY, actor.maxY)
            }
        }
    }

    @MainActor
    func testSlimeRecoveryDistinguishesIdleAndActiveThenClearsForAnOrdinaryMonster() {
        withView { view in
            _ = engage(view, kind: .tokenSlime)
            let now = Date()
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                view.tokenActivityExpiresAt = nil
                view.refreshEncounterPresentation(now: now)
                XCTAssertEqual(view.mechanicLabel.stringValue, L10n.string(.monsterRegenerationStatus, 0.1))
                view.tokenActivityExpiresAt = now.addingTimeInterval(15)
                view.refreshEncounterPresentation(now: now)
                XCTAssertEqual(view.mechanicLabel.stringValue, L10n.string(.monsterRegenerationPausedStatus, 0.1))
                XCTAssertTrue(view.mechanicLabel.accessibilityHelp()?.contains(L10n.text(.monsterRegenerationDetails)) == true)
            }
            _ = engage(view, kind: .promptWraith)
            view.refreshEncounterPresentation(now: now)
            XCTAssertTrue(view.mechanicLabel.isHidden)
            XCTAssertTrue(view.mechanicLabel.stringValue.isEmpty)
        }
    }
}
