import Foundation
import XCTest
@testable import VibeHero

final class TokenUsageTests: XCTestCase {
    private var root: URL!
    private var calendar: Calendar!
    private let now = ISO8601DateFormatter().date(from: "2026-10-22T12:00:00Z")!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("vibehero-ledger-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testCodexCumulativeDeltasDoNotAddCacheOrReasoningTwice() throws {
        let file = root.appendingPathComponent("sessions/2026/10/22/a.jsonl")
        try write([metadata("a"), codex(input: 100, output: 20, cache: 50, time: -30),
                   codex(input: 200, output: 40, cache: 100, time: -20),
                   codex(input: 200, output: 40, cache: 100, time: -10)], to: file)
        let ledger = makeLedger()
        let result = ledger.scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 240)
        XCTAssertEqual(result.inputTokens, 100)
        XCTAssertEqual(result.outputTokens, 40)
        XCTAssertEqual(result.cacheTokens, 100)
        XCTAssertEqual(result.eventCount, 2)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 240)
        XCTAssertEqual(result.fileBreakdown[file.path]?.totalTokens, 240)
        XCTAssertEqual(result.sessionBreakdown["Codex|a"]?.projectPath, "/projects/a")
    }

    func testFirstCumulativeSampleDoesNotAwardInheritedHistory() throws {
        try write([metadata("fork"), codex(input: 10_000, output: 2_000, time: -20)],
                  to: root.appendingPathComponent("sessions/fork.jsonl"))
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 120)
    }

    func testCumulativeOnlySampleEstablishesBaselineWithoutInventingSpend() throws {
        var first = codex(input: 100, output: 20, time: -20)
        var second = codex(input: 200, output: 40, time: -10)
        first = withoutLastUsage(first)
        second = withoutLastUsage(second)
        try write([metadata("a"), first, second], to: root.appendingPathComponent("sessions/a.jsonl"))
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 120)
    }

    func testLastUsageOnlyAndRepeatedRecordAreCountedOnce() throws {
        var event = codex(input: 100, output: 20, time: -10)
        var payload = event["payload"] as! [String: Any]
        var info = payload["info"] as! [String: Any]
        info.removeValue(forKey: "total_token_usage")
        payload["info"] = info
        event["payload"] = payload
        try write([metadata("a"), event, event], to: root.appendingPathComponent("sessions/a.jsonl"))
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 120)
    }

    func testCounterResetConsumesOnlyNewLastUsage() throws {
        try write([metadata("a"), codex(input: 100, output: 20, time: -40),
                   codex(input: 200, output: 40, time: -30),
                   codex(input: 100, output: 20, time: -20),
                   codex(input: 100, output: 20, time: -10)],
                  to: root.appendingPathComponent("sessions/a.jsonl"))
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 360)
    }

    func testPreviousDayBaselineAndOldDateBucketRemainDiscoverable() throws {
        // A resumed session stays in its creation-date folder.
        let file = root.appendingPathComponent("sessions/2026/10/01/a.jsonl")
        try write([metadata("a"), codex(input: 500, output: 100, time: -50_000),
                   codex(input: 650, output: 130, time: -10)], to: file)
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 180)
        XCTAssertEqual(result.eventCount, 1)
    }

    func testMidnightRescanPreservesPreviousDayBaseline() throws {
        let midnight = calendar.startOfDay(for: now)
        let previous = midnight.addingTimeInterval(-1)
        let next = midnight.addingTimeInterval(1)
        let file = root.appendingPathComponent("sessions/old/a.jsonl")
        try write([metadata("a"), codex(input: 100, output: 20, time: previous.timeIntervalSince(now))], to: file)
        let ledger = makeLedger()
        XCTAssertEqual(ledger.scanToday(now: previous).totalTokens, 120)
        try append([codex(input: 200, output: 40, time: next.timeIntervalSince(now))], to: file)
        XCTAssertEqual(ledger.scanToday(now: next).totalTokens, 120)
    }

    func testArchiveMoveAndCopiedTranscriptDoNotAwardTheSameUsageAgain() throws {
        let active = root.appendingPathComponent("sessions/a.jsonl")
        let archived = root.appendingPathComponent("archive/different-name.jsonl")
        try write([metadata("a"), codex(input: 100, output: 20, time: -10)], to: active)
        let ledger = makeLedger()
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 120)
        try FileManager.default.createDirectory(at: archived.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: active, to: archived)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 120)
        XCTAssertEqual(ledger.scanToday(now: now).fileBreakdown[archived.path]?.totalTokens, 120)
        try FileManager.default.copyItem(at: archived, to: active)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 120)
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 120)
    }

    func testCopiedPreForkEventsAreNotNewSpending() throws {
        let created = now.addingTimeInterval(-20)
        try write([metadata("fork", createdAt: created),
                   codex(input: 100, output: 20, time: -30),
                   codex(input: 200, output: 40, time: -10)],
                  to: root.appendingPathComponent("sessions/fork.jsonl"))
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 120)
    }

    func testPartialJSONLineIsRetriedAfterTheNewlineArrives() throws {
        let file = root.appendingPathComponent("sessions/a.jsonl")
        try write([metadata("a")], to: file)
        let bytes = try line(codex(input: 100, output: 20, time: -10))
        let split = bytes.count / 2
        try appendBytes(bytes.prefix(split), to: file)
        let ledger = makeLedger()
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 0)
        try appendBytes(bytes.dropFirst(split).dropLast(), to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 0)
        try appendBytes(Data([0x0A]), to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 120)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 120)
    }

    func testTruncationAndReplayDoNotUnspendOrRepeatAcceptedEvents() throws {
        let file = root.appendingPathComponent("sessions/a.jsonl")
        let first = codex(input: 100, output: 20, time: -30)
        let second = codex(input: 200, output: 40, time: -20)
        try write([metadata("a"), first, second], to: file)
        let ledger = makeLedger()
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 240)
        try write([metadata("a"), first], to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 240)
        try append([second, codex(input: 300, output: 60, time: -10)], to: file)
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 360)
    }

    func testReplacedFileWithANewSessionIsReadFromTheBeginning() throws {
        let file = root.appendingPathComponent("sessions/a.jsonl")
        try write([metadata("a"), codex(input: 100, output: 20, time: -20)], to: file)
        let ledger = makeLedger()
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 120)
        try write([metadata("b"), codex(input: 100, output: 20, time: -10)], to: file, atomic: true)
        let result = ledger.scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 240)
        XCTAssertEqual(result.sessionBreakdown.count, 2)
    }

    func testClaudeStreamingUpdatesAreGenerationDeltas() throws {
        let first = claude(message: "m1", output: 10, time: -30)
        let final = claude(message: "m1", output: 30, time: -20)
        try write([first, first, final, final, claude(message: "m2", output: 10, time: -10)],
                  to: root.appendingPathComponent("claude/project/a.jsonl"))
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 340) // (100 input + 50 cache) * 2 + 40 output
        XCTAssertEqual(result.outputTokens, 40)
        XCTAssertEqual(result.sessionBreakdown["Claude|claude-session"]?.totalTokens, 340)
    }

    func testClaudeGenerationCrossingMidnightDoesNotMoveOldInputIntoToday() throws {
        let midnight = calendar.startOfDay(for: now)
        try write([claude(message: "m1", output: 10, time: midnight.addingTimeInterval(-1).timeIntervalSince(now)),
                   claude(message: "m1", output: 30, time: midnight.addingTimeInterval(1).timeIntervalSince(now))],
                  to: root.appendingPathComponent("claude/project/a.jsonl"))
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 20)
        XCTAssertEqual(result.inputTokens, 0)
        XCTAssertEqual(result.cacheTokens, 0)
        XCTAssertEqual(result.outputTokens, 20)
    }

    func testPrimaryCoverageDoesNotSuppressAnotherSessionsHook() throws {
        try write([metadata("primary"), codex(input: 100, output: 20, time: -30)],
                  to: root.appendingPathComponent("sessions/a.jsonl"))
        try write([hook(source: "codex", session: "primary", total: 120, id: "one"),
                   hook(source: "codex", session: "hook-only", total: 80, id: "two")],
                  to: root.appendingPathComponent("hooks/events.jsonl"))
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.totalTokens, 200)
        XCTAssertEqual(result.sessionBreakdown["Codex|hook-only"]?.totalTokens, 80)
    }

    func testHookSourcesAndEventIDsRemainSupported() throws {
        let event = hook(source: "hermes", session: "hermes-a", total: 30, id: "event-a")
        try write([hook(source: "openclaw", session: "claw-a", total: 20, id: "event-b"), event, event],
                  to: root.appendingPathComponent("hooks/events.jsonl"))
        let result = makeLedger().scanToday(now: now)
        XCTAssertEqual(result.sourceBreakdown, ["OpenClaw": 20, "Hermes": 30])
    }

    func testUnknownNestedUsageAndFutureRecordsAreIgnored() throws {
        let injected: [String: Any] = [
            "timestamp": stamp(now.addingTimeInterval(-10)), "source": "hermes",
            "payload": ["tool_output": ["prompt": ["usage": ["total_tokens": 999999]]]]
        ]
        try write([injected], to: root.appendingPathComponent("hooks/events.jsonl"))
        try write([metadata("a"), codex(input: 100, output: 20, time: 60)],
                  to: root.appendingPathComponent("sessions/a.jsonl"))
        XCTAssertFalse(makeLedger().scanToday(now: now).hasRealData)
    }

    func testMalformedLineDoesNotDiscardTheNextValidRecord() throws {
        let file = root.appendingPathComponent("sessions/a.jsonl")
        try write([metadata("a")], to: file)
        try appendBytes(Data("{broken}\n".utf8), to: file)
        try append([codex(input: 100, output: 20, time: -10)], to: file)
        XCTAssertEqual(makeLedger().scanToday(now: now).totalTokens, 120)
    }

    func testLongHistoricalLogsKeepOnlyTheBaselineInTodaysAccounting() throws {
        let history = (1...2_000).map {
            codex(input: $0 * 100, output: $0 * 20, time: TimeInterval(-60_000 + $0))
        }
        try write([metadata("long")] + history + [codex(input: 200_100, output: 40_020, time: -10)],
                  to: root.appendingPathComponent("sessions/old/long.jsonl"))
        let oldHooks: [[String: Any]] = (0..<2_000).map { index in
            var record = hook(source: "hermes", session: "old", total: 30, id: "old-\(index)")
            record["timestamp"] = stamp(now.addingTimeInterval(TimeInterval(-60_000 + index)))
            return record
        }
        try write(oldHooks + [hook(source: "hermes", session: "today", total: 30, id: "today")],
                  to: root.appendingPathComponent("hooks/events.jsonl"))
        let ledger = makeLedger()
        let first = ledger.scanToday(now: now)
        XCTAssertEqual(first.totalTokens, 150)
        XCTAssertEqual(first.eventCount, 2)
        XCTAssertEqual(ledger.scanToday(now: now.addingTimeInterval(2)).totalTokens, 150)
    }

    func testDirectoryCreatedAfterFirstScanIsDiscovered() throws {
        let ledger = makeLedger()
        XCTAssertFalse(ledger.scanToday(now: now).hasRealData)
        try write([metadata("a"), codex(input: 100, output: 20, time: -10)],
                  to: root.appendingPathComponent("sessions/new/a.jsonl"))
        XCTAssertEqual(ledger.scanToday(now: now).totalTokens, 120)
    }

    private func makeLedger() -> TokenUsageLedger {
        TokenUsageLedger(sources: [
            AgentSource(label: "Claude", root: root.appendingPathComponent("claude"), layout: .projectTree, aliases: []),
            AgentSource(label: "Codex", root: root.appendingPathComponent("sessions"),
                        layout: .dateBucketedTree(archive: root.appendingPathComponent("archive")), aliases: []),
            AgentSource(label: "Hook", root: root.appendingPathComponent("hooks/events.jsonl"), layout: .singleLogFile, aliases: [])
        ], calendar: calendar)
    }

    private func metadata(_ id: String, createdAt: Date? = nil) -> [String: Any] {
        ["type": "session_meta", "timestamp": stamp(createdAt ?? now.addingTimeInterval(-86_400)),
         "payload": ["id": id, "cwd": "/projects/a"]]
    }

    private func codex(input: Int, output: Int, cache: Int = 0, time: TimeInterval) -> [String: Any] {
        ["type": "event_msg", "timestamp": stamp(now.addingTimeInterval(time)),
         "payload": ["type": "token_count", "info": [
            "total_token_usage": ["input_tokens": input, "output_tokens": output,
                                  "cached_input_tokens": cache, "reasoning_output_tokens": output / 2,
                                  "total_tokens": input + output],
            "last_token_usage": ["input_tokens": 100, "output_tokens": 20,
                                 "cached_input_tokens": min(cache, 50), "reasoning_output_tokens": 10,
                                 "total_tokens": 120]
         ]]]
    }

    private func withoutLastUsage(_ event: [String: Any]) -> [String: Any] {
        var event = event
        var payload = event["payload"] as! [String: Any]
        var info = payload["info"] as! [String: Any]
        info.removeValue(forKey: "last_token_usage")
        payload["info"] = info
        event["payload"] = payload
        return event
    }

    private func claude(message: String, output: Int, time: TimeInterval) -> [String: Any] {
        ["type": "assistant", "timestamp": stamp(now.addingTimeInterval(time)), "sessionId": "claude-session",
         "cwd": "/projects/claude", "requestId": "request-\(message)",
         "message": ["id": message, "role": "assistant",
                     "usage": ["input_tokens": 100, "output_tokens": output,
                               "cache_read_input_tokens": 40, "cache_creation_input_tokens": 10]]]
    }

    private func hook(source: String, session: String, total: Int, id: String) -> [String: Any] {
        ["timestamp": stamp(now.addingTimeInterval(-10)), "source": source,
         "payload": ["session_id": session, "event_id": id, "cwd": "/projects/\(session)",
                     "usage": ["total_tokens": total]]]
    }

    private func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    private func line(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(0x0A)
        return data
    }

    private func write(_ records: [[String: Any]], to file: URL, atomic: Bool = false) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try records.reduce(into: Data()) { $0.append(try line($1)) }
        try data.write(to: file, options: atomic ? .atomic : [])
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: file.path)
    }

    private func append(_ records: [[String: Any]], to file: URL) throws {
        for record in records { try appendBytes(line(record), to: file) }
    }

    private func appendBytes(_ data: Data, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: file.path)
    }
}
