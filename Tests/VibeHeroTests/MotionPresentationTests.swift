import AppKit
import XCTest
@testable import VibeHero

final class MotionPresentationTests: XCTestCase {
    @MainActor
    private func withView(_ body: (NotchContentView) -> Void) {
        _ = NSApplication.shared
        let suite = "VibeHero.MotionTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        Defaults.withStore(store) {
            let view = NotchContentView(
                frame: NSRect(origin: .zero, size: NotchStyle.fallbackExpanded.windowSize),
                collapsedStyle: .fallbackCollapsed, expandedStyle: .fallbackExpanded,
                startMonitors: false, presentationVisible: true, reduceMotion: false
            )
            defer {
                view.monsterRespawnWorkItem?.cancel()
                view.tokenActivityExpirationWorkItem?.cancel()
                view.battleScene.stopGameLoop()
                view.battleScene.stopBackgroundSimulation()
            }
            body(view)
        }
    }

    @MainActor
    private func animationKeys(_ layer: CALayer?) -> [String] {
        guard let layer else { return [] }
        return (layer.animationKeys() ?? []) + (layer.sublayers ?? []).flatMap { animationKeys($0) }
    }

    func testPresentationPolicySeparatesCompactBattleAndSessions() {
        let hidden = HUDPresentationPolicy(isVisible: false, isExpanded: true, showsSessions: false, reduceMotion: false)
        XCTAssertFalse(hidden.showsBattle)
        XCTAssertFalse(hidden.animatesBattle)
        XCTAssertFalse(hidden.animatesCompact)
        let compact = HUDPresentationPolicy(isVisible: true, isExpanded: false, showsSessions: false, reduceMotion: false)
        XCTAssertTrue(compact.animatesCompact)
        XCTAssertFalse(compact.showsBattle)
        let sessions = HUDPresentationPolicy(isVisible: true, isExpanded: true, showsSessions: true, reduceMotion: false)
        XCTAssertFalse(sessions.showsBattle)
        let reduced = HUDPresentationPolicy(isVisible: true, isExpanded: true, showsSessions: false, reduceMotion: true)
        XCTAssertTrue(reduced.showsBattle)
        XCTAssertFalse(reduced.animatesBattle)
        XCTAssertFalse(reduced.animatesWindow)
    }

    @MainActor
    func testHiddenAndReducedModesUseLogicTimerAndDetachStopsBothClocks() {
        withView { view in
            let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
            // Never order the test window front. Explicit policy simulates visibility.
            window.contentView = view
            defer { window.contentView = nil }
            view.setExpanded(true, animated: false)
            XCTAssertNotNil(view.battleScene.displayLink)
            XCTAssertNil(view.battleScene.backgroundSimulationTimer)
            view.setPresentation(visible: false, reduceMotion: false)
            XCTAssertNil(view.battleScene.displayLink)
            XCTAssertNotNil(view.battleScene.backgroundSimulationTimer)
            let oldPosition = view.battleScene.heroWorldX
            view.battleScene.updateWorld(dt: 0.1)
            XCTAssertGreaterThan(view.battleScene.heroWorldX, oldPosition)
            view.setPresentation(visible: true, reduceMotion: true)
            XCTAssertNil(view.battleScene.displayLink)
            XCTAssertNotNil(view.battleScene.backgroundSimulationTimer)
            view.setPresentation(visible: true, reduceMotion: false)
            XCTAssertNotNil(view.battleScene.displayLink)
            XCTAssertNil(view.battleScene.backgroundSimulationTimer)
            view.setExpanded(false, animated: false)
            XCTAssertNil(view.battleScene.displayLink)
            XCTAssertNotNil(view.battleScene.backgroundSimulationTimer)
            window.contentView = nil
            XCTAssertNil(view.battleScene.displayLink)
            XCTAssertNil(view.battleScene.backgroundSimulationTimer)
        }
    }

    @MainActor
    func testReducedMotionRetainsStaticFeedbackAndDoesNotRestartAnimations() {
        withView { view in
            view.setPresentation(visible: true, reduceMotion: true)
            view.setExpanded(true, animated: false)
            let scene = view.battleScene
            scene.updateWorld(dt: 2)
            for _ in 0..<3 {
                view.setTokenActivity(true)
                view.heroHPBar.isWarning = true
                view.heroHPBar.value -= 0.05
                XCTAssertTrue(scene.playAttack(damageText: "25", isCrit: true))
                scene.playMonsterAttack(damage: 0.2)
                scene.playHeroReviveHeal(restoredHP: 28)
                scene.playLevelUp()
                scene.playLootDrop(LootDrop(kind: .gold, amount: 3))
                scene.updateWorld(dt: 0.1)
            }
            XCTAssertTrue(scene.heroAttackQueue.isEmpty)
            XCTAssertFalse(scene.isAttackInProgress)
            XCTAssertTrue(animationKeys(scene.heroView.layer).isEmpty)
            XCTAssertTrue(animationKeys(scene.monsterView.layer).isEmpty)
            XCTAssertTrue(animationKeys(scene.effectsLayer).isEmpty)
            XCTAssertTrue(animationKeys(view.heroHPBar.layer).isEmpty)
            XCTAssertTrue(animationKeys(view.glowLayer).isEmpty)
            XCTAssertEqual(view.glowLayer.opacity, 0)
            XCTAssertTrue(scene.floatingTextLabels.contains { $0.alphaValue == 1 && !$0.stringValue.isEmpty })
            XCTAssertTrue(scene.floatingTextLabels.allSatisfy { animationKeys($0.layer).isEmpty })
            scene.reloadLocalization()
            XCTAssertTrue(scene.floatingTextLabels.allSatisfy { $0.alphaValue == 0 })
            XCTAssertTrue((scene.backdropView.layer?.sublayers ?? []).allSatisfy { $0.speed == 0 })
            view.setExpanded(false, animated: false)
            view.playCompactHeroAttack()
            view.playCompactMonsterAttack()
            view.playReviveEffects(restoredHP: 28)
            XCTAssertTrue(animationKeys(view.compactHeroView.layer).isEmpty)
            XCTAssertTrue(animationKeys(view.compactHPBar.layer).isEmpty)
        }
    }

    @MainActor
    func testReducedMotionKeepsFightPoseWhileWorldStillApproaches() {
        let scene = BattleSceneView(frame: NSRect(x: 0, y: 0, width: 420, height: 80))
        scene.setPresentation(visible: true, reduceMotion: true)
        scene.spawnMonsterBatch([MonsterEncounter(kind: .promptWraith, stage: 1, isBoss: false)])
        scene.layout()
        let pose = scene.monsterView.frame
        XCTAssertFalse(scene.monsterEngaged)
        scene.updateWorld(dt: 0.1)
        XCTAssertGreaterThan(scene.heroWorldX, 0)
        XCTAssertEqual(scene.monsterView.frame, pose)
        scene.updateWorld(dt: 2)
        XCTAssertTrue(scene.monsterEngaged)
        XCTAssertEqual(scene.monsterView.frame, pose)
    }

    @MainActor
    func testOldAttackCompletionCannotConsumeNewVisibleQueue() {
        withView { view in
            view.setExpanded(true, animated: false)
            let scene = view.battleScene
            scene.updateWorld(dt: 2)
            scene.playAttack(damageText: "10")
            scene.playAttack(damageText: "20")
            let staleGeneration = scene.visualGeneration
            XCTAssertTrue(scene.isAttackInProgress)
            XCTAssertEqual(scene.heroAttackQueue.count, 1)
            view.setPresentation(visible: false, reduceMotion: false)
            XCTAssertTrue(scene.heroAttackQueue.isEmpty)
            XCTAssertTrue(animationKeys(scene.effectsLayer).isEmpty)
            view.setPresentation(visible: true, reduceMotion: false)
            scene.playAttack(damageText: "30")
            scene.playAttack(damageText: "40")
            scene.finishHeroAttack(generation: staleGeneration)
            XCTAssertTrue(scene.isAttackInProgress)
            XCTAssertEqual(scene.heroAttackQueue.count, 1)
            scene.finishHeroAttack(generation: scene.visualGeneration)
            XCTAssertTrue(scene.heroAttackQueue.isEmpty)
        }
    }

    @MainActor
    func testActivitySurvivesMotionToggleAndHiddenLogicCannotRestartIt() {
        withView { view in
            view.setTokenActivity(true)
            XCTAssertNotNil(view.compactHeroView.layer?.animation(forKey: "tokenActivityBob"))
            view.setPresentation(visible: false, reduceMotion: false)
            view.setTokenActivity(true)
            view.playCompactHeroAttack()
            view.playCompactMonsterAttack()
            view.updateGameLabels()
            XCTAssertTrue(animationKeys(view.compactHeroView.layer).isEmpty)
            view.setPresentation(visible: true, reduceMotion: false)
            XCTAssertNotNil(view.compactHeroView.layer?.animation(forKey: "tokenActivityBob"))
            view.setPresentation(visible: true, reduceMotion: true)
            XCTAssertTrue(animationKeys(view.compactHeroView.layer).isEmpty)
        }
    }

    @MainActor
    func testWindowOrderOutImmediatelyUpdatesPresentationWithoutShowingWindow() {
        _ = NSApplication.shared
        let suite = "VibeHero.WindowMotionTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        Defaults.withStore(store) {
            let window = NotchWindow(startMonitors: false, observeSystemEvents: false, reduceMotion: false)
            let view = window.notchView
            view.setPresentation(visible: true, reduceMotion: false)
            view.setExpanded(true, animated: false)
            XCTAssertNotNil(view.battleScene.displayLink)
            window.orderOut(nil)
            XCTAssertFalse(view.presentationPolicy.isVisible)
            XCTAssertNil(view.battleScene.displayLink)
            XCTAssertNotNil(view.battleScene.backgroundSimulationTimer)
            window.contentView = nil
            XCTAssertNil(view.battleScene.backgroundSimulationTimer)
        }
    }
}
