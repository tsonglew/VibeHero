#!/usr/bin/env python3
"""Render deterministic AppKit layout fixtures without showing a desktop window.

Usage: python3 scripts/render-preview.py /absolute/output/directory
Requires macOS Command Line Tools. Uses a temporary defaults suite and disables
usage/session monitors. Tools previews only read installation status; no hook is
installed and no real agent usage is loaded.
"""
from pathlib import Path
import platform
import subprocess, tempfile, shutil, sys

project = Path(__file__).resolve().parent.parent
if len(sys.argv) != 2:
    raise SystemExit(__doc__)
out = Path(sys.argv[1]).expanduser().resolve()
out.mkdir(parents=True, exist_ok=True)
build = Path(tempfile.mkdtemp(prefix='vibehero-preview-build-'))
shutil.copytree(project/'Sources', build/'Sources')
main = build/'main.swift'
main.write_text(r'''
import AppKit
import QuartzCore
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let language = AppLanguage(rawValue: CommandLine.arguments[1]) ?? .english
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let suiteName = "VibeHero.Preview.\(UUID().uuidString)"
let store = UserDefaults(suiteName: suiteName)!
defer { store.removePersistentDomain(forName: suiteName) }
@MainActor func stripAnimations(_ view: NSView) {
    func strip(_ layer: CALayer) { layer.removeAllAnimations(); layer.sublayers?.forEach(strip) }
    if let layer = view.layer { strip(layer) }
    view.subviews.forEach(stripAnimations)
}
@MainActor func capture(_ view: NSView, name: String) throws {
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: view.frame.size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.isOpaque = false
    window.backgroundColor = .clear
    window.appearance = NSAppearance(named: name.contains("light") ? .aqua : .darkAqua)
    window.contentView = view
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()
    stripAnimations(view)
    view.displayIfNeeded()
    CATransaction.flush()
    let size = view.bounds.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width*2), pixelsHigh: Int(size.height*2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    view.cacheDisplay(in: view.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(language.rawValue)-\(name).png"))
    precondition(!window.isVisible)
    window.contentView = nil
}
try Defaults.withStore(store) {
    Defaults.set(language.rawValue, forKey: DefaultsKey.language)
    HeroExperience.saveTotalXP(1000)
    HeroRole.engineer.save()
    Defaults.set(1234567, forKey: DefaultsKey.inventoryGold)
    for slot in EquipmentSlot.allCases { Defaults.set(ItemRarity.rare.rawValue, forKey: DefaultsKey.equipment(slot: slot.rawValue)) }
    let styles = NotchStyle.styles(for: nil)
    let hud = NotchContentView(frame: NSRect(origin: .zero, size: styles.collapsed.windowSize), collapsedStyle: styles.collapsed, expandedStyle: styles.expanded, startMonitors: false)
    hud.hasRealUsageData = true
    hud.todayTokens = 98765432
    hud.xpRate = 123456
    hud.heroHealth = 0.72
    hud.monsterHealth = 0.68
    hud.updateGameLabels()
    hud.updateTitleLabel()
    try capture(hud, name: "collapsed")
    hud.setExpanded(true, animated: false)
    hud.setFrameSize(styles.expanded.windowSize)
    hud.layoutSubtreeIfNeeded()
    hud.battleScene.updateWorld(dt: 2)
    hud.battleScene.stopGameLoop()
    hud.battleScene.stopBackgroundSimulation()
    try capture(hud, name: "expanded")
    hud.setCamping(true)
    try capture(hud, name: "camp")
    hud.setExpanded(false, animated: false)
    hud.setFrameSize(styles.collapsed.windowSize)
    try capture(hud, name: "camp-collapsed")
    hud.setExpanded(true, animated: false)
    hud.setFrameSize(styles.expanded.windowSize)
    hud.setCamping(false)
    let encounter = MonsterEncounter(kind: .cacheGolem, stage: 10, isBoss: true)
    hud.battleScene.spawnMonsterBatch([encounter])
    hud.activateMonster(encounter, announce: false)
    hud.battleScene.updateWorld(dt: 20)
    hud.monsterHealth = 0.7
    hud.updateGameLabels()
    try capture(hud, name: "golem")
    hud.damageMonster(by: CGFloat(encounter.maxHP) * 0.6)
    hud.updateGameLabels()
    try capture(hud, name: "boss-phase2")
    hud.isDefeated = true
    hud.heroHealth = 0
    hud.setCamping(true)
    try capture(hud, name: "camp-defeated")
    hud.isDefeated = false
    hud.setCamping(false)
    let game = GameSettingsTab()
    game.view.frame = NSRect(x: 0, y: 0, width: 640, height: 540)
    game.refresh()
    try capture(game.view, name: "roles")
    try capture(game.view, name: "roles-light")
    let equipment = EquipmentSettingsTab()
    equipment.view.frame = NSRect(x: 0, y: 0, width: 640, height: 640)
    ItemSystem.recordHealing(0.5)
    _ = ItemSystem.addGold(35, kind: .bossGold)
    equipment.refresh()
    try capture(equipment.view, name: "equipment")
    try capture(equipment.view, name: "equipment-light")
    let general = GeneralSettingsTab()
    general.view.frame = NSRect(x: 0, y: 0, width: 640, height: 540)
    general.refresh()
    try capture(general.view, name: "general")
    let tools = ToolsSettingsTab()
    tools.view.frame = NSRect(x: 0, y: 0, width: 640, height: 540)
    tools.refresh()
    try capture(tools.view, name: "tools")
    let sessions = SessionListView(frame: NSRect(x: 0, y: 0, width: 640, height: 180))
    sessions.updateSessions(IDEType.allCases.enumerated().map { index, ide in
        IDESession(id: "preview-\(index)", ide: ide,
                   projectPath: "/sample/\(["pixel-quest", "docs-site", "sample-api", "design-system", "weekend-game", "cli-tools"][index])",
                   lastActivityAt: Date().addingTimeInterval(index % 2 == 0 ? 0 : -600),
                   tokenCount: index == 5 ? nil : (index + 1) * 12345)
    })
    try capture(sessions, name: "sessions")
    let skills = SkillTreeView(frame: NSRect(x: 0, y: 0, width: 592, height: 760))
    try capture(skills, name: "skills-passive")
    if let mode = skills.subviews.compactMap({ $0 as? NSSegmentedControl }).first(where: { $0.segmentCount == 2 }), let action = mode.action {
        mode.selectedSegment = 1
        NSApp.sendAction(action, to: mode.target, from: mode)
        try capture(skills, name: "skills-active")
    }
    hud.battleScene.stopGameLoop()
    hud.battleScene.stopBackgroundSimulation()
}
''')
sources = [str(p) for p in (build/'Sources/VibeHero').rglob('*.swift') if p.name!='main.swift']
cmd=['/Library/Developer/CommandLineTools/usr/bin/swiftc','-sdk','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-target',f'{platform.machine()}-apple-macosx14.0','-swift-version','6',*sources,str(main),'-o',str(build/'preview')]
try:
    subprocess.run(cmd, check=True, timeout=180)
    for lang in ['en','zh-Hans','ja']:
        subprocess.run([str(build/'preview'),lang,str(out)], check=True, timeout=60)
    print(out)
finally:
    shutil.rmtree(build)
