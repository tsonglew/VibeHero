import AppKit
import XCTest
@testable import VibeHero

final class SessionPresentationTests: XCTestCase {
    @MainActor
    func testTabOnlyPollsWhileVisibleAndRestartsAfterReturning() async {
        _ = NSApplication.shared
        let provider = PresentationSessionProvider()
        provider.projects = ["/fixture/first": [.codex]]
        let monitor = SessionMonitor(
            snapshotProvider: { nil },
            openProjectsProvider: { provider.readProjects() },
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            scanInterval: 0
        )
        let tab = SessionsSettingsTab(monitor: monitor)
        _ = tab.view
        XCTAssertNil(tab.refreshTimer)
        XCTAssertEqual(provider.readCount, 0)

        tab.viewWillAppear()
        let firstTimer = tab.refreshTimer
        tab.viewWillAppear()
        XCTAssertTrue(tab.refreshTimer === firstTimer)
        await monitor.waitForPendingScan()
        XCTAssertEqual(provider.readCount, 1)
        XCTAssertTrue(text(in: tab.view).contains("first"))

        provider.projects = ["/fixture/second": [.claude]]
        firstTimer?.fire()
        await monitor.waitForPendingScan()
        XCTAssertEqual(provider.readCount, 2)
        XCTAssertTrue(text(in: tab.view).contains("second"))

        tab.viewWillDisappear()
        XCTAssertNil(tab.refreshTimer)
        XCTAssertEqual(firstTimer?.isValid, false)
        provider.projects = ["/fixture/third": [.kimi]]
        monitor.startMonitoring()
        await monitor.waitForPendingScan()
        XCTAssertTrue(text(in: tab.view).contains("second"), "A hidden tab must release its subscription")
        XCTAssertFalse(text(in: tab.view).contains("third"))

        provider.projects = [:]
        tab.viewWillAppear()
        XCTAssertFalse(tab.refreshTimer === firstTimer)
        await monitor.waitForPendingScan()
        XCTAssertEqual(provider.readCount, 4)
        XCTAssertFalse(text(in: tab.view).contains("second"), "Returning must replace even a nonempty cached roster with an empty result")
        XCTAssertFalse(text(in: tab.view).contains("third"))
        tab.viewWillDisappear()
    }

    @MainActor
    func testExistingSessionRowsAndToggleAccessibilityFollowLanguageChanges() {
        withView { view in
            let now = Date()
            view.sessionListView.updateSessions([
                IDESession(id: "active", ide: .codex, projectPath: "/fixture/active", lastActivityAt: now, tokenCount: 12),
                IDESession(id: "idle", ide: .claude, projectPath: "/fixture/idle", lastActivityAt: .distantPast, tokenCount: nil),
                IDESession(id: "unknown", ide: .hermes, projectPath: "", lastActivityAt: now, tokenCount: 7, isUnattributed: true)
            ])
            view.toggleView()
            let cases: [(AppLanguage, String, String, String, String, String, String)] = [
                (.english, "● Active", "○ Idle", "Unknown project", "Show battle", "Show sessions", "Active IDE Sessions"),
                (.simplifiedChinese, "● 活跃", "○ 空闲", "未知项目", "显示战斗", "显示会话", "活跃 IDE 会话"),
                (.japanese, "● アクティブ", "○ 待機中", "不明なプロジェクト", "バトルを表示", "セッションを表示", "アクティブ IDE セッション")
            ]
            for (language, active, idle, unknown, battleAction, sessionAction, title) in cases {
                AppLanguage.save(language)
                let strings = text(in: view.sessionListView)
                XCTAssertTrue(strings.contains(active))
                XCTAssertTrue(strings.contains(idle))
                XCTAssertTrue(strings.contains(unknown))
                XCTAssertEqual(view.titleLabel.stringValue, title)
                XCTAssertEqual(view.viewToggleButton.toolTip, battleAction)
                XCTAssertEqual(view.viewToggleButton.accessibilityLabel(), battleAction)
                view.toggleView()
                XCTAssertEqual(view.viewToggleButton.toolTip, sessionAction)
                XCTAssertEqual(view.viewToggleButton.accessibilityLabel(), sessionAction)
                view.toggleView()
            }
        }
    }

    @MainActor
    func testUnknownUsageIsDistinctFromVerifiedZeroInEveryLanguage() {
        withDefaults {
            let unknown = IDESession(id: "unknown", ide: .codex, projectPath: "/fixture/work", lastActivityAt: .distantPast, tokenCount: nil)
            let zero = IDESession(id: "zero", ide: .codex, projectPath: "/fixture/work", lastActivityAt: .distantPast, tokenCount: 0)
            let row = SessionRowView(session: unknown)
            for language in AppLanguage.allCases {
                Defaults.set(language.rawValue, forKey: DefaultsKey.language)
                row.update(session: unknown)
                XCTAssertTrue(text(in: row).contains("—"))
                XCTAssertFalse(text(in: row).contains("0"))
                let placeholder = labels(in: row).first { $0.stringValue == "—" }
                XCTAssertEqual(placeholder?.accessibilityLabel(), L10n.text(.sessionUnknownTokenUsage))
                row.update(session: zero)
                XCTAssertTrue(text(in: row).contains("0"))
                XCTAssertFalse(text(in: row).contains("—"))
            }
        }
    }

    @MainActor
    func testBackgroundCombatAndPreferenceRefreshKeepTheSessionTitle() {
        withView { view in
            view.toggleView()
            XCTAssertEqual(view.titleLabel.stringValue, "Active IDE Sessions")
            view.battleScene.updateWorld(dt: 2)
            let maxHP = StageProgress.maxHP(stage: view.currentStage, monster: view.currentMonster, isBoss: view.currentMonsterIsBoss)
            view.enqueueHeroStrike(ResolvedHeroStrike(damagePoints: CGFloat(maxHP) + 10, isCrit: false))
            XCTAssertEqual(view.totalKills, 1)
            XCTAssertEqual(view.titleLabel.stringValue, "Active IDE Sessions")
            view.advanceMonsterAfterDefeat()
            XCTAssertEqual(view.titleLabel.stringValue, "Active IDE Sessions")
            view.reloadPreferences()
            XCTAssertEqual(view.titleLabel.stringValue, "Active IDE Sessions")
            view.toggleView()
            XCTAssertTrue(view.titleLabel.stringValue.contains(L10n.string(.stageTag, view.currentStage)))
            XCTAssertNotEqual(view.titleLabel.stringValue, "Active IDE Sessions")
        }
    }

    @MainActor
    private func withDefaults(_ body: () -> Void) {
        _ = NSApplication.shared
        let name = "VibeHero.SessionPresentation.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        defer { store.removePersistentDomain(forName: name) }
        Defaults.withStore(store) {
            Defaults.set(AppLanguage.english.rawValue, forKey: DefaultsKey.language)
            body()
        }
    }

    @MainActor
    private func withView(_ body: (NotchContentView) -> Void) {
        withDefaults {
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
    private func labels(in view: NSView) -> [NSTextField] {
        (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
    }

    @MainActor
    private func text(in view: NSView) -> [String] {
        labels(in: view).map(\.stringValue)
    }
}

private final class PresentationSessionProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var storedProjects: [String: Set<IDEType>] = [:]
    private var reads = 0

    var projects: [String: Set<IDEType>] {
        get { lock.lock(); defer { lock.unlock() }; return storedProjects }
        set { lock.lock(); storedProjects = newValue; lock.unlock() }
    }

    var readCount: Int {
        lock.lock(); defer { lock.unlock() }; return reads
    }

    func readProjects() -> [String: Set<IDEType>] {
        lock.lock(); defer { lock.unlock() }
        reads += 1
        return storedProjects
    }
}
