import Foundation

/// One coding agent VibeHero can read token usage and sessions from.
///
/// Before this table existed, every agent's log paths were spelled out inline in
/// three separate places (`TokenUsageScanner.scanToday`,
/// `SessionMonitor.scanClaudeSessions`/`scanCodexSessions`/the hook scan, and
/// `NotchContentView.startFileMonitor`), and the display-name aliases in a
/// fourth. Adding an agent meant finding all four. Now it is one entry here.
struct AgentSource {
    /// How transcripts for this agent are laid out on disk. Each case has a
    /// matching reader; a new agent that reuses one needs no reader changes.
    enum Layout {
        /// A directory tree of `.jsonl` transcripts, one subdirectory per project.
        case projectTree
        /// `.jsonl` transcripts bucketed by date (`<root>/YYYY/MM/DD/`), with a
        /// flat archive directory alongside.
        case dateBucketedTree(archive: URL)
        /// A single append-only `.jsonl` file written by our own installed hook.
        case singleLogFile
        /// Official Kimi wire records; other JSONL files contain replay copies.
        case kimiWireTree(format: KimiWireFormat)
    }

    /// Canonical display name, as it appears in the HUD and token breakdown.
    let label: String
    /// Root directory (or the log file itself, for `.singleLogFile`).
    let root: URL
    let layout: Layout
    /// Lowercased spellings that agents write into their `source` field, all of
    /// which normalize to `label`.
    let aliases: [String]

    /// Directories worth watching for filesystem change events.
    var watchRoots: [URL] {
        switch layout {
        case .projectTree, .kimiWireTree:
            return [root]
        case .dateBucketedTree(let archive):
            return [root, archive]
        case .singleLogFile:
            // Watch the containing directory: the hook rewrites the log, and a
            // descriptor on the file itself would go stale on replace.
            return [root.deletingLastPathComponent()]
        }
    }

    /// Hook events are a fallback and lose to an agent's own transcript when both
    /// report the same source on the same day.
    var isHookLog: Bool {
        if case .singleLogFile = layout {
            return true
        }
        return false
    }
}

enum AgentSourceCatalog {
    private static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// The agents whose logs we read directly.
    static var all: [AgentSource] {
        [claude, codex] + kimiSources() + [hook]
    }

    static var claude: AgentSource {
        AgentSource(
            label: "Claude",
            root: home.appendingPathComponent(".claude/projects"),
            layout: .projectTree,
            aliases: ["claude", "claude code", "claudecode"]
        )
    }

    static var codex: AgentSource {
        AgentSource(
            label: "Codex",
            root: home.appendingPathComponent(".codex/sessions"),
            layout: .dateBucketedTree(archive: home.appendingPathComponent(".codex/archived_sessions")),
            aliases: ["codex"]
        )
    }

    static func kimiSources(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [AgentSource] {
        func root(_ variable: String, fallback: String) -> URL {
            if let path = environment[variable], !path.isEmpty {
                return URL(fileURLWithPath: path).appendingPathComponent("sessions")
            }
            return home.appendingPathComponent(fallback).appendingPathComponent("sessions")
        }
        return [
            AgentSource(label: "Kimi", root: root("KIMI_CODE_HOME", fallback: ".kimi-code"),
                        layout: .kimiWireTree(format: .current), aliases: ["kimi", "kimi code", "kimicode"]),
            AgentSource(label: "Kimi", root: root("KIMI_SHARE_DIR", fallback: ".kimi"),
                        layout: .kimiWireTree(format: .legacy), aliases: [])
        ]
    }

    /// Fallback for agents with no readable transcript of their own: our shell
    /// hook appends their token counts here. See `TokenHookInstaller`.
    static var hook: AgentSource {
        AgentSource(
            label: "Hook",
            root: home.appendingPathComponent(".vibe-hero/token-events.jsonl"),
            layout: .singleLogFile,
            aliases: []
        )
    }

    /// Agents that only ever reach us through the hook log, so they need a
    /// display name but no reader.
    static let hookOnlyAliases: [String: [String]] = [
        "OpenCode": ["opencode", "open code"],
        "OpenClaw": ["openclaw", "open claw"],
        "Hermes": ["hermes"]
    ]

    /// Every directory worth attaching a filesystem watcher to, deduplicated.
    static var watchRoots: [URL] {
        var seen = Set<String>()
        var roots: [URL] = []
        for root in all.flatMap(\.watchRoots) where seen.insert(root.path).inserted {
            roots.append(root)
        }
        return roots
    }

    /// Maps whatever an agent wrote in its `source` field to a canonical label.
    /// Unrecognized values pass through unchanged, so a brand-new agent still
    /// shows up in the breakdown under its own name.
    static func normalizedLabel(for rawSource: String?) -> String? {
        guard let rawSource else {
            return nil
        }

        let needle = rawSource.lowercased()
        if let match = all.first(where: { $0.aliases.contains(needle) }) {
            return match.label
        }
        if let match = hookOnlyAliases.first(where: { $0.value.contains(needle) }) {
            return match.key
        }
        return rawSource
    }
}
