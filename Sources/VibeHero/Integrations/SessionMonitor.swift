import AppKit
import Darwin

// MARK: - IDE Session Info

struct IDESession: Identifiable, Sendable {
    static let activeWindow: TimeInterval = 300

    let id: String
    let ide: IDEType
    let projectPath: String
    let lastActivityAt: Date
    /// Nil means no verified usage is available for this project today.
    let tokenCount: Int?
    var isUnattributed = false

    var isActive: Bool {
        isActive(at: Date())
    }

    func isActive(at date: Date) -> Bool {
        date.timeIntervalSince(lastActivityAt) < Self.activeWindow
    }

    var displayName: String {
        let url = URL(fileURLWithPath: projectPath)
        return url.lastPathComponent.isEmpty ? projectPath : url.lastPathComponent
    }
}

enum IDEType: String, CaseIterable, Sendable {
    case claude = "Claude"
    case codex = "Codex"
    case opencode = "OpenCode"
    case kimi = "Kimi"
    case openclaw = "OpenClaw"
    case hermes = "Hermes"

    /// Same wording as the hook installer uses, so a session row and the tools
    /// tab call the same agent by the same name.
    var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .opencode: "OpenCode"
        case .kimi: "Kimi Code"
        case .openclaw: "OpenClaw"
        case .hermes: "Hermes"
        }
    }

    var icon: String {
        switch self {
        case .claude: "🤖"
        case .codex: "💻"
        case .opencode: "🔧"
        case .kimi: "🌙"
        case .openclaw: "🦞"
        case .hermes: "📬"
        }
    }

    var color: NSColor {
        switch self {
        case .claude: NSColor(red: 0.0, green: 0.72, blue: 0.78, alpha: 1)
        case .codex: NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1)
        case .opencode: NSColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 1)
        case .kimi: NSColor(red: 0.6, green: 0.4, blue: 0.95, alpha: 1)
        case .openclaw: NSColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1)
        case .hermes: NSColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)
        }
    }
}

// MARK: - Open Projects

/// Which projects are open right now, and in which agent CLI.
///
/// Transcripts outlive the runs that wrote them - `~/.claude/projects` keeps a
/// directory per project ever opened, which is how a machine with 5 live
/// sessions listed 21 of them. Agent CLIs keep their project as the process cwd;
/// Codex Desktop is the exception because every task shares one app-server, so
/// its recently written transcript is used as a second liveness signal below.
enum OpenProjectScanner {
    /// Maps each open project path to the agent CLIs running in it. Returns
    /// `nil` when the process table cannot be read (a sandboxed build, for
    /// instance) so callers can fall back to the unfiltered list instead of
    /// showing an empty one.
    static func openProjects() -> [String: Set<IDEType>]? {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else {
            return nil
        }

        // proc_listallpids returns a pid count, not a byte count.
        var pids = [pid_t](repeating: 0, count: Int(capacity) + 64)
        let found = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard found > 0 else {
            return nil
        }

        var projects: [String: Set<IDEType>] = [:]
        for pid in pids.prefix(min(Int(found), pids.count)) where pid > 0 {
            // A helper process parked at the filesystem root is not a project.
            guard let ide = agentType(of: pid),
                  let cwd = workingDirectory(of: pid),
                  cwd != "/" else {
                continue
            }
            projects[cwd, default: []].insert(ide)
        }

        return projects
    }

    /// Substring match because the binaries are not consistently named: Claude
    /// ships as "claude" from the VS Code extension and "claude.exe" from the
    /// standalone CLI.
    private static func agentType(of pid: pid_t) -> IDEType? {
        var buffer = [UInt8](repeating: 0, count: 1024)
        let length = buffer.withUnsafeMutableBytes { proc_name(pid, $0.baseAddress, UInt32($0.count)) }
        guard length > 0 else {
            return nil
        }

        let name = String(decoding: buffer.prefix(Int(length)), as: UTF8.self).lowercased()
        return IDEType.allCases.first { name.contains($0.rawValue.lowercased()) }
    }

    private static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, Int32(MemoryLayout<proc_vnodepathinfo>.size))
        // Fails for processes owned by another user; those are not ours anyway.
        guard size > 0 else {
            return nil
        }

        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
        }

        return path.isEmpty ? nil : SessionPath.normalize(path)
    }
}

enum SessionPath {
    /// A cwd read from the kernel has its symlinks resolved, one copied out of a
    /// transcript does not, so both sides are normalized before comparison.
    static func normalize(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }
}

// MARK: - Session Monitor

@MainActor
final class SessionMonitor {
    static let shared = SessionMonitor()

    typealias SnapshotProvider = @Sendable () -> TokenUsageSnapshot?
    typealias OpenProjectsProvider = @Sendable () -> [String: Set<IDEType>]?

    private let snapshotProvider: SnapshotProvider
    private let openProjectsProvider: OpenProjectsProvider
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let scanInterval: TimeInterval
    private var sessions: [IDESession] = []
    private var lastScanAt: Date?
    private var scanTask: Task<Void, Never>?
    private var observers: [ObjectIdentifier: ([IDESession]) -> Void] = [:]

    /// Construction does no work. The app's usage poll owns transcript I/O;
    /// this monitor consumes its cached snapshot and reads only process liveness.
    init(
        snapshotProvider: @escaping SnapshotProvider = { TokenUsageScanner.latestSnapshot },
        openProjectsProvider: @escaping OpenProjectsProvider = { OpenProjectScanner.openProjects() },
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current,
        scanInterval: TimeInterval = 2
    ) {
        self.snapshotProvider = snapshotProvider
        self.openProjectsProvider = openProjectsProvider
        self.now = now
        self.calendar = calendar
        self.scanInterval = scanInterval
    }

    func addObserver(_ owner: AnyObject, handler: @escaping ([IDESession]) -> Void) {
        observers[ObjectIdentifier(owner)] = handler
        handler(sessions)
    }

    func removeObserver(_ owner: AnyObject) {
        observers.removeValue(forKey: ObjectIdentifier(owner))
    }

    func startMonitoring() {
        requestRefresh(force: true)
    }

    func refreshIfNeeded() {
        requestRefresh(force: false)
    }

    /// Lets callers await an already requested refresh without triggering a
    /// second process scan (also keeps fixture-based lifecycle tests deterministic).
    func waitForPendingScan() async {
        await scanTask?.value
    }

    private func requestRefresh(force: Bool) {
        guard scanTask == nil else { return }
        let date = now()
        if !force, let lastScanAt, date.timeIntervalSince(lastScanAt) >= 0,
           date.timeIntervalSince(lastScanAt) < scanInterval { return }
        lastScanAt = date
        let snapshotProvider = snapshotProvider
        let openProjectsProvider = openProjectsProvider
        let calendar = calendar
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                let projects = openProjectsProvider()
                return Self.sessions(from: snapshotProvider(), openProjects: projects, now: date, calendar: calendar)
            }.value
            guard let self else { return }
            self.sessions = result
            self.scanTask = nil
            for handler in self.observers.values { handler(result) }
        }
    }

    /// The ledger has already deduplicated requests, streaming updates, archives
    /// and native/hook overlap. Aggregate every session in a project before
    /// deciding whether that project is live; selecting the newest transcript
    /// would silently discard usage from its other sessions and subagents.
    nonisolated static func sessions(
        from snapshot: TokenUsageSnapshot?,
        openProjects: [String: Set<IDEType>]?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [IDESession] {
        var rows: [String: IDESession] = [:]
        let projects = openProjects.map { projects in
            Dictionary(projects.map { (SessionPath.normalize($0.key), $0.value) }, uniquingKeysWith: { $0.union($1) })
        }
        // Never carry yesterday's token labels into a new day while waiting for
        // the first fresh usage poll. A process-only row remains explicitly unknown.
        if let snapshot, calendar.isDate(snapshot.generatedAt, inSameDayAs: now) {
            for summary in snapshot.sessionBreakdown.values {
                guard let ide = IDEType(rawValue: summary.source) else { continue }
                let project = summary.projectPath.flatMap { $0.isEmpty ? nil : SessionPath.normalize($0) }
                let key = project.map { "\(ide.rawValue)|\($0)" } ?? "\(ide.rawValue)|unattributed"
                let previous = rows[key]
                rows[key] = IDESession(
                    id: key, ide: ide, projectPath: project ?? "",
                    lastActivityAt: max(previous?.lastActivityAt ?? .distantPast, summary.latestEventAt ?? .distantPast),
                    tokenCount: (previous?.tokenCount ?? 0) + summary.totalTokens,
                    isUnattributed: project == nil
                )
            }
        }

        if let projects {
            // Native desktop/daemon agents do not always expose a project cwd in
            // their process. Recent verified usage is also a liveness signal,
            // consistently for all supported agents, including hook-only sources.
            rows = rows.filter { _, session in
                let running = !session.isUnattributed && projects[session.projectPath]?.contains(session.ide) == true
                return running || session.isActive(at: now)
            }
            for (path, agents) in projects {
                for ide in agents {
                    let key = "\(ide.rawValue)|\(path)"
                    if rows[key] == nil {
                        rows[key] = IDESession(id: key, ide: ide, projectPath: path,
                                              lastActivityAt: .distantPast, tokenCount: nil)
                    }
                }
            }
        }
        return rows.values.sorted {
            if $0.lastActivityAt != $1.lastActivityAt { return $0.lastActivityAt > $1.lastActivityAt }
            return $0.id < $1.id
        }
    }
}
