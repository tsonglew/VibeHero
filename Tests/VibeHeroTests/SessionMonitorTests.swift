import Foundation
import XCTest
@testable import VibeHero

final class SessionMonitorTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-22T12:00:00Z")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testEverySessionInAProjectContributesToTheSameDailyRow() {
        let snapshot = makeSnapshot([
            summary(id: "parent", tokens: 120, time: -40),
            summary(id: "subagent", tokens: 80, time: -5)
        ])
        let rows = sessions(snapshot, projects: [:])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.tokenCount, snapshot.totalTokens)
        XCTAssertEqual(rows.first?.lastActivityAt, now.addingTimeInterval(-5))
        XCTAssertEqual(rows.first?.id, "Codex|/projects/work")
    }

    func testProjectAndAgentBoundariesStaySeparate() {
        let snapshot = makeSnapshot([
            summary(id: "one", tokens: 120),
            summary(id: "two", source: .claude, tokens: 50),
            summary(id: "three", project: "/projects/other", tokens: 30)
        ])
        let rows = sessions(snapshot, projects: [:])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.compactMap(\.tokenCount).reduce(0, +), snapshot.totalTokens)
    }

    func testAllSixAgentsUseRecentUsageAsLivenessEvidence() {
        let snapshot = makeSnapshot(IDEType.allCases.map {
            summary(id: $0.rawValue, source: $0, tokens: 10)
        })
        let rows = sessions(snapshot, projects: [:])
        XCTAssertEqual(Set(rows.map(\.ide)), Set(IDEType.allCases))
        XCTAssertTrue(rows.allSatisfy { $0.tokenCount == 10 })
    }

    func testStaleUsageRequiresTheMatchingProjectAndAgentProcess() {
        let snapshot = makeSnapshot([summary(id: "old", tokens: 120, time: -600)])
        XCTAssertTrue(sessions(snapshot, projects: [:]).isEmpty)
        let correct = sessions(snapshot, projects: ["/projects/work": [.codex]])
        XCTAssertEqual(correct.first?.tokenCount, 120)
        let wrongAgent = sessions(snapshot, projects: ["/projects/work": [.claude]])
        XCTAssertEqual(wrongAgent.map(\.ide), [.claude])
        XCTAssertNil(wrongAgent.first?.tokenCount)
    }

    func testUnattributedUsageIsNeverCopiedIntoOpenProjects() {
        let snapshot = makeSnapshot([
            summary(id: "no-cwd-a", source: .opencode, project: nil, tokens: 80),
            summary(id: "no-cwd-b", source: .opencode, project: nil, tokens: 20)
        ])
        let rows = sessions(snapshot, projects: ["/projects/one": [.opencode], "/projects/two": [.opencode]])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.compactMap(\.tokenCount).reduce(0, +), 100)
        XCTAssertEqual(rows.filter(\.isUnattributed).count, 1)
        XCTAssertEqual(rows.first(where: \.isUnattributed)?.tokenCount, 100)
        XCTAssertTrue(rows.filter { !$0.isUnattributed }.allSatisfy { $0.tokenCount == nil })
    }

    func testKnownZeroIsPreservedWhileMissingUsageStaysUnknown() {
        let snapshot = makeSnapshot([summary(id: "verified-zero", tokens: 0)])
        let rows = sessions(snapshot, projects: ["/projects/work": [.codex], "/projects/empty": [.codex]])
        XCTAssertEqual(rows.first { $0.projectPath == "/projects/work" }?.tokenCount, 0)
        XCTAssertNil(rows.first { $0.projectPath == "/projects/empty" }?.tokenCount)
    }

    func testMidnightDoesNotDisplayYesterdaysCachedTokens() {
        let midnight = calendar.startOfDay(for: now)
        let stale = makeSnapshot([summary(id: "yesterday", tokens: 900)], generatedAt: midnight.addingTimeInterval(-1))
        let rows = SessionMonitor.sessions(from: stale, openProjects: ["/projects/work": [.codex]],
                                           now: midnight.addingTimeInterval(1), calendar: calendar)
        XCTAssertEqual(rows.count, 1)
        XCTAssertNil(rows.first?.tokenCount)
        XCTAssertTrue(SessionMonitor.sessions(from: stale, openProjects: [:], now: midnight.addingTimeInterval(1), calendar: calendar).isEmpty)
    }

    func testUnreadableProcessTableFallsBackToVerifiedSnapshotRows() {
        let snapshot = makeSnapshot([summary(id: "old", tokens: 120, time: -600)])
        XCTAssertEqual(sessions(snapshot, projects: nil).first?.tokenCount, 120)
    }

    func testLargeTranscriptWithoutUsageCannotBecomeEstimatedTokens() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("project/large.jsonl")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let object: [String: Any] = ["timestamp": ISO8601DateFormatter().string(from: now.addingTimeInterval(-10)),
                                   "sessionId": "large", "cwd": "/projects/work", "type": "user",
                                   "message": ["content": String(repeating: "x", count: 120_000)]]
        var bytes = try JSONSerialization.data(withJSONObject: object)
        bytes.append(0x0A)
        try bytes.write(to: file)
        let ledger = TokenUsageLedger(sources: [AgentSource(label: "Claude", root: root, layout: .projectTree, aliases: [])], calendar: calendar)
        let snapshot = ledger.scanToday(now: now)
        XCTAssertEqual(snapshot.totalTokens, 0)
        let rows = sessions(snapshot, projects: ["/projects/work": [.claude]])
        XCTAssertEqual(rows.count, 1)
        XCTAssertNil(rows.first?.tokenCount)
    }

    func testRealHookLedgerAndSessionRowsAgreeWithoutInventingProjectAttribution() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("events.jsonl")
        let hook: [String: Any] = ["timestamp": ISO8601DateFormatter().string(from: now.addingTimeInterval(-10)),
                                  "source": "hermes", "payload": ["event_id": "once", "usage": ["total_tokens": 80]]]
        var line = try JSONSerialization.data(withJSONObject: hook)
        line.append(0x0A)
        try (line + line).write(to: file)
        let ledger = TokenUsageLedger(sources: [AgentSource(label: "Hook", root: file, layout: .singleLogFile, aliases: [])], calendar: calendar)
        let snapshot = ledger.scanToday(now: now)
        let rows = sessions(snapshot, projects: ["/projects/one": [.hermes], "/projects/two": [.hermes]])
        XCTAssertEqual(snapshot.totalTokens, 80)
        XCTAssertEqual(rows.compactMap(\.tokenCount).reduce(0, +), snapshot.sourceBreakdown["Hermes"])
        XCTAssertEqual(rows.filter(\.isUnattributed).first?.tokenCount, 80)
    }

    @MainActor
    func testConstructionDoesNotScanAndOverlappingRequestsShareOneRefresh() async {
        let counts = SessionProviderCounts()
        let snapshot = makeSnapshot([summary(id: "one", tokens: 120)])
        let fixedNow = now
        let monitor = SessionMonitor(snapshotProvider: { counts.readSnapshot(); return snapshot },
                                     openProjectsProvider: { counts.readProcesses(); return [:] },
                                     now: { fixedNow }, calendar: calendar)
        XCTAssertEqual(counts.reads, [0, 0])
        let owner = NSObject()
        var observed: [IDESession] = []
        monitor.addObserver(owner) { observed = $0 }
        XCTAssertTrue(observed.isEmpty)
        XCTAssertEqual(counts.reads, [0, 0])
        monitor.startMonitoring()
        monitor.startMonitoring()
        monitor.refreshIfNeeded()
        await monitor.waitForPendingScan()
        XCTAssertEqual(counts.reads, [1, 1])
        XCTAssertEqual(observed.first?.tokenCount, 120)
        monitor.refreshIfNeeded()
        await monitor.waitForPendingScan()
        XCTAssertEqual(counts.reads, [1, 1])
        monitor.startMonitoring() // A newly visible consumer forces a fresh snapshot.
        await monitor.waitForPendingScan()
        XCTAssertEqual(counts.reads, [2, 2])
    }

    @MainActor
    func testRemovingOneObserverPreservesOtherConsumers() async {
        let snapshot = makeSnapshot([summary(id: "one", tokens: 120)])
        let fixedNow = now
        let monitor = SessionMonitor(snapshotProvider: { snapshot }, openProjectsProvider: { [:] },
                                     now: { fixedNow }, calendar: calendar)
        let first = NSObject()
        let second = NSObject()
        var firstCalls = 0
        var secondCalls = 0
        monitor.addObserver(first) { _ in firstCalls += 1 }
        monitor.addObserver(second) { _ in secondCalls += 1 }
        monitor.removeObserver(first)
        monitor.startMonitoring()
        await monitor.waitForPendingScan()
        XCTAssertEqual(firstCalls, 1)
        XCTAssertEqual(secondCalls, 2)
    }

    private func sessions(_ snapshot: TokenUsageSnapshot?, projects: [String: Set<IDEType>]?) -> [IDESession] {
        SessionMonitor.sessions(from: snapshot, openProjects: projects, now: now, calendar: calendar)
    }

    private func summary(id: String, source: IDEType = .codex, project: String? = "/projects/work", tokens: Int, time: TimeInterval = -10) -> TokenUsageSessionSummary {
        var summary = TokenUsageSessionSummary(source: source.rawValue, sessionID: id, projectPath: project)
        summary.totals = TokenUsageTotals(inputTokens: tokens, outputTokens: 0, cacheTokens: 0,
                                          eventCount: 1, latestEventAt: now.addingTimeInterval(time))
        return summary
    }

    private func makeSnapshot(_ summaries: [TokenUsageSessionSummary], generatedAt: Date? = nil) -> TokenUsageSnapshot {
        let total = summaries.reduce(0) { $0 + $1.totalTokens }
        let sources = Dictionary(summaries.map { ($0.source, $0.totalTokens) }, uniquingKeysWith: +)
        return TokenUsageSnapshot(totalTokens: total, inputTokens: total, outputTokens: 0, cacheTokens: 0,
                                  recentTokens: total, sourceBreakdown: sources, eventCount: summaries.count,
                                  latestEventAt: summaries.compactMap(\.latestEventAt).max(), generatedAt: generatedAt ?? now,
                                  sessionBreakdown: Dictionary(uniqueKeysWithValues: summaries.map { ("\($0.source)|\($0.sessionID)", $0) }))
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("vibehero-sessions-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

private final class SessionProviderCounts: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshotReads = 0
    private var processReads = 0
    var reads: [Int] { lock.lock(); defer { lock.unlock() }; return [snapshotReads, processReads] }
    func readSnapshot() { lock.lock(); snapshotReads += 1; lock.unlock() }
    func readProcesses() { lock.lock(); processReads += 1; lock.unlock() }
}
