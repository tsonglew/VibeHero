import Foundation
import XCTest
@testable import VibeHero

final class SessionMonitorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testRecentCodexTranscriptSurvivesMissingProjectProcess() {
        let session = makeSession(id: "desktop", lastActivityAt: now.addingTimeInterval(-20))

        let result = SessionMonitor.sessionsInOpenProjects(
            [session],
            openProjects: [:],
            now: now
        )

        XCTAssertEqual(result.map(\.id), ["desktop"])
    }

    func testStaleCodexTranscriptStillRequiresMatchingProcess() {
        let session = makeSession(id: "finished", lastActivityAt: now.addingTimeInterval(-600))

        let withoutProcess = SessionMonitor.sessionsInOpenProjects(
            [session],
            openProjects: [:],
            now: now
        )
        let withProcess = SessionMonitor.sessionsInOpenProjects(
            [session],
            openProjects: ["/Users/test/Documents/agents": [.codex]],
            now: now
        )

        XCTAssertTrue(withoutProcess.isEmpty)
        XCTAssertEqual(withProcess.map(\.id), ["finished"])
    }

    func testCodexSubsessionsCollapseToMostRecentProjectRow() {
        let parent = makeSession(id: "parent", lastActivityAt: now.addingTimeInterval(-40))
        let subagent = makeSession(id: "subagent", lastActivityAt: now.addingTimeInterval(-5))

        let result = SessionMonitor.sessionsInOpenProjects(
            [parent, subagent],
            openProjects: [:],
            now: now
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "subagent")
    }

    private func makeSession(id: String, lastActivityAt: Date) -> IDESession {
        IDESession(
            id: id,
            ide: .codex,
            projectPath: "/Users/test/Documents/agents",
            lastActivityAt: lastActivityAt,
            tokenCount: 0
        )
    }
}
