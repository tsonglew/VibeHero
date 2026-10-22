import CryptoKit
import Foundation
import XCTest
@testable import VibeHero

final class KimiTokenUsageTests: XCTestCase {
    private var root: URL!
    private var calendar: Calendar!
    private let now = ISO8601DateFormatter().date(from: "2026-10-22T12:00:00Z")!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("vibehero-kimi-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testCurrentWireDisjointCountersAndBothUsageScopes() throws {
        let file = try currentFile(session: "a")
        let event = currentUsage(time: -30)
        var compaction = currentUsage(time: -20)
        compaction["usageScope"] = "session"
        var earlyVersion = currentUsage(time: -10)
        earlyVersion.removeValue(forKey: "agentId")
        earlyVersion.removeValue(forKey: "usageScope")
        try write([event, event, compaction, earlyVersion,
                   ["type": "context.append_loop_event", "time": milliseconds(-5), "event": event],
                   ["type": "agent.status.updated", "time": milliseconds(-5), "usage": event["usage"]!]], to: file)
        let ledger = makeLedger()
        let result = ledger.scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 540)
        XCTAssertEqual(result.inputTokens, 300)
        XCTAssertEqual(result.outputTokens, 60)
        XCTAssertEqual(result.cacheTokens, 180)
        XCTAssertEqual(result.eventCount, 3)
        XCTAssertEqual(result.nativeSourceBreakdown, ["Kimi": 540])
        XCTAssertEqual(result.sessionBreakdown["Kimi|a"]?.projectPath, "/projects/kimi")
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 540)
        XCTAssertEqual(ledger.latestSnapshot?.totalTokens, 540)
    }

    func testCurrentSubagentsCountOnlyTheirOwnDirectRecords() throws {
        let main = try currentFile(session: "a")
        let child = try currentFile(session: "a", agent: "agent-1")
        let childEvent = currentUsage(time: -10, agent: "agent-1")
        try write([currentUsage(time: -20), childEvent,
                   ["type": "agent.message.appended", "message": childEvent]], to: main)
        try write([childEvent], to: child)
        // A similarly named JSONL in a context directory is not an agent wire.
        try write([childEvent], to: root.appendingPathComponent("current/sessions/work/a/context/wire.jsonl"))
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 360)
        XCTAssertEqual(result.sessionBreakdown["Kimi|a"]?.totalTokens, 360)
        XCTAssertEqual(result.fileBreakdown[child.path]?.totalTokens, 180)
    }

    func testCurrentForkSkipsAllHistoryBeforeLastMarker() throws {
        let original = try currentFile(session: "original")
        let fork = try currentFile(session: "fork", forkedFrom: "original")
        try write([currentUsage(time: -40)], to: original)
        try write([currentUsage(time: -40), ["type": "forked", "time": milliseconds(-35)],
                   currentUsage(time: -30), ["type": "forked", "time": milliseconds(-20)],
                   currentUsage(time: -10)], to: fork)
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 360)
        XCTAssertEqual(result.sessionBreakdown["Kimi|fork"]?.totalTokens, 180)
    }

    func testCurrentChildRejectsCopiedParentUsageBeforeAForkMarkerArrives() throws {
        let main = try currentFile(session: "a")
        let child = try currentFile(session: "a", agent: "agent-1")
        let parentEvent = currentUsage(time: -40)
        try write([parentEvent], to: main)
        try write([parentEvent], to: child)
        let ledger = makeLedger()
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 180)
        try append([["type": "forked", "time": milliseconds(-30)],
                    currentUsage(time: -10, agent: "agent-1")], to: child)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 360)
    }

    func testNewChildInAForkedSessionDoesNotRequireACopiedHistoryMarker() throws {
        let child = try currentFile(session: "fork", agent: "new-agent", forkedFrom: "original")
        try write([["type": "metadata", "created_at": milliseconds(-20)],
                   currentUsage(time: -10, agent: "new-agent")], to: child)
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 180)
    }

    func testHalfCopiedForkWaitsForStateAndCompleteMarker() throws {
        let file = root.appendingPathComponent("current/sessions/work/fork/agents/main/wire.jsonl")
        try write([currentUsage(time: -40)], to: file)
        let ledger = makeLedger()
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 0)
        _ = try currentFile(session: "fork", forkedFrom: "original")
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 0)
        try append([["type": "forked", "time": milliseconds(-30)], currentUsage(time: -10)], to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 180)
    }

    func testLegacySecondsAndSubagentForwardingAreNotDoubleCounted() throws {
        let main = try legacyFile(session: "legacy")
        let child = try legacyFile(session: "legacy", agent: "child")
        let childEvent = legacyUsage(id: "child-call", time: -10)
        try write([legacyUsage(id: "main-call", time: -20),
                   ["timestamp": now.timeIntervalSince1970 - 10,
                    "message": ["type": "SubagentEvent", "payload": ["event": childEvent["message"]!]]]], to: main)
        try write([childEvent], to: child)
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 360)
        XCTAssertEqual(result.latestEventAt, now.addingTimeInterval(-10))
        XCTAssertEqual(result.sessionBreakdown["Kimi|legacy"]?.projectPath, "/projects/legacy")
    }

    func testLegacyForkCopiesAreDeduplicatedAndSharedHistoryIsUnattributed() throws {
        let original = try legacyFile(session: "original")
        let fork = try legacyFile(session: "fork")
        let old = legacyUsage(id: "provider-call", time: -30)
        try write([old], to: original)
        try write([old, legacyUsage(id: "new-call", time: -10)], to: fork)
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 360)
        XCTAssertEqual(result.sessionBreakdown["Kimi|fork"]?.totalTokens, 180)
        XCTAssertEqual(result.sessionBreakdown["Kimi|shared-legacy-history"]?.totalTokens, 180)
        XCTAssertNil(result.sessionBreakdown["Kimi|shared-legacy-history"]?.projectPath)
    }

    func testLegacyWithoutMessageIDUsesReplayFingerprint() throws {
        var event = legacyUsage(id: "unused", time: -10)
        var message = event["message"] as! [String: Any]
        var payload = message["payload"] as! [String: Any]
        payload.removeValue(forKey: "message_id")
        message["payload"] = payload
        event["message"] = message
        try write([event], to: legacyFile(session: "a"))
        try write([event], to: legacyFile(session: "b"))
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 180)
    }

    func testPartialLineAndTruncationDoNotDuplicateCurrentUsage() throws {
        let file = try currentFile(session: "a")
        let first = currentUsage(time: -20)
        try write([first], to: file)
        let ledger = makeLedger()
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 180)
        let second = try JSONSerialization.data(withJSONObject: currentUsage(time: -10), options: [.sortedKeys])
        try appendBytes(second, to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 180)
        try appendBytes(Data([0x0A]), to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 360)
        try write([first], to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 360)
        try append([currentUsage(time: -10)], to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 360)
    }

    func testDatesAndUnknownPayloadsDoNotInventUsage() throws {
        let file = try currentFile(session: "a")
        try write([currentUsage(time: -86_400), currentUsage(time: 10),
                   ["type": "prompt", "time": milliseconds(-1), "usage": ["inputOther": 99999]],
                   ["type": "usage.record", "time": "2026-10-22T11:00:00Z", "usage": ["inputOther": 99999]],
                   ["type": "usage.record", "time": milliseconds(-1), "usage": ["inputOther": true]]], to: file)
        XCTAssertFalse(makeLedger().scanToday(now: now).hasRealData)
    }

    func testAutomaticStatusRequiresTodaysNativeUsageAndNeverAnInstall() throws {
        let file = try currentFile(session: "a")
        let ledger = makeLedger()
        let waiting = ledger.scanToday(now: now)
        XCTAssertEqual(KimiUsageAvailability(snapshot: waiting, now: now, calendar: calendar), .waiting)
        try write([currentUsage(time: -10)], to: file)
        let received = ledger.scanToday(now: now)
        XCTAssertEqual(KimiUsageAvailability(snapshot: received, now: now, calendar: calendar), .reading)
        XCTAssertEqual(KimiUsageAvailability(snapshot: received, now: now.addingTimeInterval(86_400), calendar: calendar), .waiting)
        var hookOnly = received
        hookOnly.nativeSourceBreakdown = [:]
        XCTAssertEqual(KimiUsageAvailability(snapshot: hookOnly, now: now, calendar: calendar), .waiting)
        let state = TokenHookInstaller.kimiState(snapshot: received, now: now)
        XCTAssertTrue(state.isAutomatic)
        XCTAssertTrue(state.hasUsageData)
        XCTAssertFalse(state.isInstalled)
        XCTAssertTrue(CodingToolHook.kimi.usesNativeUsage)
        // The removed installation path exits before resolving any home paths.
        try TokenHookInstaller.install(.kimi)
        try TokenHookInstaller.install(.kimi)
    }

    private func makeLedger() -> TokenUsageLedger {
        TokenUsageLedger(sources: AgentSourceCatalog.kimiSources(home: root, environment: [
            "KIMI_CODE_HOME": root.appendingPathComponent("current").path,
            "KIMI_SHARE_DIR": root.appendingPathComponent("legacy").path
        ]), calendar: calendar)
    }

    private func currentFile(session: String, agent: String = "main", forkedFrom: String? = nil) throws -> URL {
        let directory = root.appendingPathComponent("current/sessions/work/\(session)")
        var state: [String: Any] = ["id": session, "cwd": "/projects/kimi", "createdAt": milliseconds(-100)]
        if let forkedFrom { state["forkedFrom"] = forkedFrom }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: state).write(to: directory.appendingPathComponent("state.json"))
        return directory.appendingPathComponent("agents/\(agent)/wire.jsonl")
    }

    private func legacyFile(session: String, agent: String? = nil) throws -> URL {
        let dataRoot = root.appendingPathComponent("legacy")
        try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        let project = "/projects/legacy"
        let metadata: [String: Any] = ["work_dirs": [["path": project, "kaos": "local"]]]
        try JSONSerialization.data(withJSONObject: metadata).write(to: dataRoot.appendingPathComponent("kimi.json"))
        let hash = Insecure.MD5.hash(data: Data(project.utf8)).map { String(format: "%02x", $0) }.joined()
        let suffix = agent.map { "subagents/\($0)/wire.jsonl" } ?? "wire.jsonl"
        return dataRoot.appendingPathComponent("sessions/\(hash)/\(session)/\(suffix)")
    }

    private func currentUsage(time: TimeInterval, agent: String = "main") -> [String: Any] {
        ["type": "usage.record", "agentId": agent, "model": "kimi-test", "usageScope": "turn", "time": milliseconds(time),
         "usage": ["inputOther": 100, "output": 20, "inputCacheRead": 50, "inputCacheCreation": 10]]
    }

    private func legacyUsage(id: String, time: TimeInterval) -> [String: Any] {
        ["timestamp": now.addingTimeInterval(time).timeIntervalSince1970,
         "message": ["type": "StatusUpdate", "payload": ["message_id": id,
            "token_usage": ["input_other": 100, "output": 20, "input_cache_read": 50, "input_cache_creation": 10]]]]
    }

    private func milliseconds(_ offset: TimeInterval) -> Double { now.addingTimeInterval(offset).timeIntervalSince1970 * 1_000 }

    private func write(_ events: [[String: Any]], to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: file)
        try append(events, to: file)
    }

    private func append(_ events: [[String: Any]], to file: URL) throws {
        for event in events {
            var bytes = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
            bytes.append(0x0A)
            try appendBytes(bytes, to: file)
        }
    }

    private func appendBytes(_ data: Data, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}
