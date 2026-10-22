import AppKit
import XCTest
@testable import VibeHero

/// `AgentSourceCatalog` is now the single source of truth for agent log paths,
/// which previously appeared inline in `TokenUsage`, `SessionMonitor` and
/// `NotchContentView` independently.
final class AgentSourceCatalogTests: XCTestCase {
    func testKnownAliasesNormalizeToTheirDisplayLabel() {
        let expected: [String: String] = [
            "claude": "Claude",
            "claude code": "Claude",
            "claudecode": "Claude",
            "codex": "Codex",
            "opencode": "OpenCode",
            "open code": "OpenCode",
            "kimi": "Kimi",
            "kimi code": "Kimi",
            "kimicode": "Kimi",
            "openclaw": "OpenClaw",
            "open claw": "OpenClaw",
            "hermes": "Hermes"
        ]

        for (raw, label) in expected {
            XCTAssertEqual(AgentSourceCatalog.normalizedLabel(for: raw), label)
        }
    }

    func testAliasMatchingIsCaseInsensitive() {
        XCTAssertEqual(AgentSourceCatalog.normalizedLabel(for: "CLAUDE"), "Claude")
        XCTAssertEqual(AgentSourceCatalog.normalizedLabel(for: "Claude Code"), "Claude")
        XCTAssertEqual(AgentSourceCatalog.normalizedLabel(for: "OpenClaw"), "OpenClaw")
    }

    /// An agent we have never seen should still appear in the breakdown under
    /// whatever name it reported, rather than being dropped or relabeled.
    func testUnknownSourcePassesThroughUnchanged() {
        XCTAssertEqual(AgentSourceCatalog.normalizedLabel(for: "brand-new-agent"), "brand-new-agent")
        XCTAssertNil(AgentSourceCatalog.normalizedLabel(for: nil))
    }

    func testAliasesAreLowercasedSoLookupCanNeverMiss() {
        for source in AgentSourceCatalog.all {
            for alias in source.aliases {
                XCTAssertEqual(alias, alias.lowercased(), "alias '\(alias)' on \(source.label) is not lowercased")
            }
        }
        for (label, aliases) in AgentSourceCatalog.hookOnlyAliases {
            for alias in aliases {
                XCTAssertEqual(alias, alias.lowercased(), "alias '\(alias)' on \(label) is not lowercased")
            }
        }
    }

    func testNoAliasIsClaimedByTwoSources() {
        var owners: [String: String] = [:]
        for source in AgentSourceCatalog.all {
            for alias in source.aliases {
                XCTAssertNil(owners[alias], "'\(alias)' is claimed by both \(owners[alias] ?? "") and \(source.label)")
                owners[alias] = source.label
            }
        }
        for (label, aliases) in AgentSourceCatalog.hookOnlyAliases {
            for alias in aliases {
                XCTAssertNil(owners[alias], "'\(alias)' is claimed by both \(owners[alias] ?? "") and \(label)")
                owners[alias] = label
            }
        }
    }

    func testOnlyTheHookLogIsTreatedAsAFallbackSource() {
        XCTAssertFalse(AgentSourceCatalog.claude.isHookLog)
        XCTAssertFalse(AgentSourceCatalog.codex.isHookLog)
        XCTAssertTrue(AgentSourceCatalog.hook.isHookLog)
        XCTAssertTrue(AgentSourceCatalog.kimiSources().allSatisfy { !$0.isHookLog })
    }

    func testKimiRootsHonorInjectedHomesAndEnvironment() {
        let home = URL(fileURLWithPath: "/fixture-home")
        let defaults = AgentSourceCatalog.kimiSources(home: home, environment: [:])
        XCTAssertEqual(defaults.map(\.root.path), ["/fixture-home/.kimi-code/sessions", "/fixture-home/.kimi/sessions"])
        let customized = AgentSourceCatalog.kimiSources(home: home, environment: [
            "KIMI_CODE_HOME": "/fixture/current", "KIMI_SHARE_DIR": "/fixture/legacy"
        ])
        XCTAssertEqual(customized.map(\.root.path), ["/fixture/current/sessions", "/fixture/legacy/sessions"])
        XCTAssertEqual(customized.flatMap(\.watchRoots), customized.map(\.root))
    }

    /// The file monitor watches these. A single-file source has to contribute its
    /// parent directory, because a watcher on a replaced file goes stale.
    func testWatchRootsCoverEverySourceAndAreDirectories() {
        let roots = AgentSourceCatalog.watchRoots

        XCTAssertTrue(roots.contains(AgentSourceCatalog.claude.root))
        XCTAssertTrue(roots.contains(AgentSourceCatalog.codex.root))
        XCTAssertTrue(roots.contains(AgentSourceCatalog.hook.root.deletingLastPathComponent()))
        XCTAssertFalse(roots.contains(AgentSourceCatalog.hook.root))

        // Previously only ~/.claude/projects was watched, so Codex and hook
        // activity waited for the next poll.
        XCTAssertGreaterThanOrEqual(roots.count, 3)
        XCTAssertEqual(roots.count, Set(roots.map(\.path)).count, "watchRoots should be deduplicated")
    }

    func testCodexArchiveIsWatchedAlongsideItsSessionsRoot() {
        guard case .dateBucketedTree(let archive) = AgentSourceCatalog.codex.layout else {
            return XCTFail("Codex should use a date-bucketed layout")
        }

        XCTAssertTrue(AgentSourceCatalog.codex.watchRoots.contains(archive))
        XCTAssertTrue(AgentSourceCatalog.watchRoots.contains(archive))
    }

    func testSourcePathsStillPointWhereTheAgentsActuallyWrite() {
        XCTAssertTrue(AgentSourceCatalog.claude.root.path.hasSuffix(".claude/projects"))
        XCTAssertTrue(AgentSourceCatalog.codex.root.path.hasSuffix(".codex/sessions"))
        XCTAssertTrue(AgentSourceCatalog.hook.root.path.hasSuffix(".vibe-hero/token-events.jsonl"))
    }
}
