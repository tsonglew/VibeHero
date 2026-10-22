import AppKit
import XCTest
@testable import VibeHero

final class HUDLayoutTests: XCTestCase {
    @MainActor
    private func withDefaults(_ body: () -> Void) {
        _ = NSApplication.shared
        let name = "VibeHero.HUDLayout.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        defer { store.removePersistentDomain(forName: name) }
        Defaults.withStore(store) { body() }
    }

    @MainActor
    private func withView(_ body: (NotchContentView) -> Void) {
        withDefaults {
            let styles = NotchStyle.styles(for: nil)
            let view = NotchContentView(frame: NSRect(origin: .zero, size: styles.collapsed.windowSize),
                collapsedStyle: styles.collapsed, expandedStyle: styles.expanded, startMonitors: false, presentationVisible: true, reduceMotion: false)
            body(view)
            view.monsterRespawnWorkItem?.cancel()
            view.tokenActivityExpirationWorkItem?.cancel()
            view.battleScene.stopGameLoop()
            view.battleScene.stopBackgroundSimulation()
        }
    }

    @MainActor
    func testLargeStatisticsNeverCoverActionsAndBattleRemainsReadableInEveryLanguage() {
        withView { view in
            view.hasRealUsageData = true
            view.todayTokens = 98_765_432
            view.xpRate = 123_456
            view.heroLevel = 999
            view.currentMonsterStage = 999
            ItemSystem.addGold(1_234_567)
            view.setExpanded(true, animated: false)
            view.setFrameSize(view.expandedStyle.windowSize)
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                view.reloadLocalizedText()
                view.needsLayout = true
                view.layoutSubtreeIfNeeded()
                let actions = [view.viewToggleButton.frame, view.settingsButton.frame, view.reservedHeaderActionFrame]
                XCTAssertGreaterThanOrEqual(view.battleScene.frame.height, 70)
                XCTAssertTrue(view.expandedHUD.bounds.contains(view.battleScene.frame))
                XCTAssertLessThanOrEqual(view.titleLabel.frame.maxX, actions.map(\.minX).min()! - 4)
                for label in [view.titleLabel, view.tokenLabel, view.goldLabel, view.skillLabel] {
                    let rect = label.convert(label.bounds, to: view.expandedHUD)
                    for action in actions { XCTAssertFalse(rect.intersects(action), "\(language): \(label.stringValue)") }
                    XCTAssertLessThanOrEqual(label.intrinsicContentSize.width, label.bounds.width + 1,
                                             "Common large values must remain fully readable: \(language) \(label.stringValue)")
                }
                XCTAssertEqual(view.settingsButton.accessibilityLabel(), L10n.text(.settingsTitle))
                XCTAssertEqual(view.viewToggleButton.accessibilityLabel(), L10n.text(.showSessions))
            }
            view.todayTokens = Int.max
            ItemSystem.addGold(Int.max)
            view.updateGameLabels()
            view.layoutSubtreeIfNeeded()
            for label in [view.tokenLabel, view.goldLabel] {
                XCTAssertFalse(label.stringValue.isEmpty)
                XCTAssertTrue(view.gameHUD.bounds.contains(label.frame))
                XCTAssertNotNil(label.toolTip, "Extreme abbreviated values retain exact statistics in a tooltip")
            }
        }
    }

    @MainActor
    func testCollapsedHUDKeepsSavedLevelWithoutTodayUsageAndHidesTinyExactStatistics() {
        withView { view in
            view.heroLevel = 37
            view.hasRealUsageData = false
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                view.reloadLocalizedText()
                view.layoutSubtreeIfNeeded()
                XCTAssertTrue(view.compactLevelLabel.stringValue.contains("37"))
                XCTAssertGreaterThanOrEqual(view.compactLevelLabel.font?.pointSize ?? 0, 10)
                XCTAssertGreaterThanOrEqual(view.compactTokenLabel.font?.pointSize ?? 0, 10)
                XCTAssertTrue(view.compactHPLabel.isHidden)
                XCTAssertTrue(view.compactXPLabel.isHidden)
                XCTAssertFalse(view.compactStatusLabel.stringValue.isEmpty)
                XCTAssertFalse(view.compactLevelLabel.frame.intersects(view.compactTokenLabel.frame))
            }
        }
    }

    @MainActor
    func testSessionModeReusesTheHeaderWithoutShowingBattleStatistics() {
        withView { view in
            view.setExpanded(true, animated: false)
            view.setFrameSize(view.expandedStyle.windowSize)
            view.toggleView()
            view.layoutSubtreeIfNeeded()
            XCTAssertTrue(view.gameHUD.isHidden)
            XCTAssertFalse(view.sessionListView.isHidden)
            XCTAssertEqual(view.titleLabel.stringValue, L10n.text(.activeSessions))
            XCTAssertLessThan(view.sessionListView.frame.maxY, view.titleLabel.frame.minY)
            XCTAssertEqual(view.viewToggleButton.accessibilityLabel(), L10n.text(.showBattle))
        }
    }

    @MainActor
    func testRoleCardsFillThreeEqualColumnsAndExposeKeyboardActionsInEveryLanguage() {
        withDefaults {
            let game = GameSettingsTab()
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 540),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = game.view
            game.view.frame.size = NSSize(width: 640, height: 540)
            defer { window.contentView = nil }
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                game.refresh()
                game.view.layoutSubtreeIfNeeded()
                XCTAssertEqual(game.roleChoiceViews.count, 6)
                let widths = game.roleChoiceViews.map { $0.frame.width }
                XCTAssertGreaterThan(widths.min() ?? 0, 170)
                XCTAssertEqual(widths.min()!, widths.max()!, accuracy: 1)
                for card in game.roleChoiceViews {
                    XCTAssertTrue(card.clickButton.isEnabled)
                    XCTAssertFalse(card.clickButton.refusesFirstResponder)
                    XCTAssertTrue(card.clickButton.accessibilityLabel()?.contains(card.role.label) == true)
                    XCTAssertEqual(card.perkLabel.stringValue, card.compactAttributes)
                    XCTAssertLessThanOrEqual(card.nameLabel.intrinsicContentSize.width, card.nameLabel.bounds.width + 1)
                    card.clickButton.performClick(nil)
                    XCTAssertEqual(HeroRole.load(), card.role)
                    XCTAssertEqual(card.clickButton.state, .on)
                    XCTAssertTrue(game.roleChoiceViews.filter { $0 !== card }.allSatisfy { $0.clickButton.state == .off })
                }
            }
            XCTAssertFalse(window.isVisible)
        }
    }
}
