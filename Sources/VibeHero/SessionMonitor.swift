import AppKit
import Darwin

// MARK: - IDE Session Info

struct IDESession: Identifiable, Sendable {
    static let activeWindow: TimeInterval = 300

    let id: String
    let ide: IDEType
    let projectPath: String
    let lastActivityAt: Date
    let tokenCount: Int

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

/// Parses the timestamps in the hook log.
///
/// The writers do not agree on a format: the shell hook stamps `date -u` output
/// with whole seconds, while the OpenCode plugin and the Kimi MCP server both
/// use JavaScript's `toISOString()`, which carries milliseconds. The reader used
/// to demand fractional seconds, so on any install where the shell hook writes -
/// Claude Code and Codex - every single line failed to parse and the log was
/// silently ignored.
///
/// Instances are created per scan: `ISO8601DateFormatter` goes through ICU and
/// is expensive to build, but it is not `Sendable`, so it is not shared either.
struct HookTimestampParser {
    private let fractional = ISO8601DateFormatter()
    private let plain = ISO8601DateFormatter()

    init() {
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        plain.formatOptions = [.withInternetDateTime]
    }

    func date(from raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
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

    private var sessions: [IDESession] = []
    private var lastScanAt: Date?
    private let scanInterval: TimeInterval = 10 // Increased to 10 seconds
    private var isScanning = false

    // Cache: file path -> (modification date, token count)
    private var tokenCache: [String: (Date, Int)] = [:]

    // Cache: codex session file -> the cwd recorded in its session_meta line.
    // Immutable for the lifetime of a session file, so it is only read once.
    private var codexPathCache: [String: String] = [:]

    // Cache: claude project directory -> the cwd recorded in its transcripts.
    // Keyed by directory because every transcript in one shares the same cwd.
    private var claudePathCache: [String: String] = [:]

    // Multicast observers keyed by subscriber identity so several views (the
    // notch HUD and the settings window) can receive updates at the same time.
    // A single callback let whichever registered last silently steal updates
    // from the others - the HUD went blank once the settings Sessions tab had
    // been opened.
    private var observers: [ObjectIdentifier: ([IDESession]) -> Void] = [:]

    func addObserver(_ owner: AnyObject, handler: @escaping ([IDESession]) -> Void) {
        observers[ObjectIdentifier(owner)] = handler
        // Deliver the most recent scan immediately so a newly shown view isn't
        // blank until the next scan completes.
        if !sessions.isEmpty {
            handler(sessions)
        }
    }

    func removeObserver(_ owner: AnyObject) {
        observers.removeValue(forKey: ObjectIdentifier(owner))
    }

    private init() {}

    func startMonitoring() {
        Task {
            await scanSessionsAsync()
        }
    }

    func refreshIfNeeded() {
        guard !isScanning else { return }
        if let lastScan = lastScanAt, Date().timeIntervalSince(lastScan) < scanInterval {
            return
        }
        Task {
            await scanSessionsAsync()
        }
    }

    private func scanSessionsAsync() async {
        guard !isScanning else { return }
        isScanning = true
        lastScanAt = Date()

        // Perform file I/O on background thread
        let scan = await Task.detached(priority: .userInitiated) { [tokenCache, codexPathCache, claudePathCache] in
            var sessions: [IDESession] = []
            var newCache = tokenCache
            var newCodexPaths = codexPathCache
            var newClaudePaths = claudePathCache

            // Read once: the hook log needs this to place events that name no
            // project, and it is what filters the finished list.
            let openProjects = OpenProjectScanner.openProjects()

            // Scan Claude sessions
            sessions.append(contentsOf: Self.scanClaudeSessions(cache: &newCache, pathCache: &newClaudePaths))

            // Scan Codex sessions
            sessions.append(contentsOf: Self.scanCodexSessions(cache: &newCache, pathCache: &newCodexPaths))

            // Scan OpenCode/Kimi hook sessions
            sessions.append(contentsOf: Self.scanHookSessions(openProjects: openProjects))

            if let openProjects {
                sessions = Self.sessionsInOpenProjects(sessions, openProjects: openProjects)
            }

            return (sessions: sessions, tokens: newCache, codexPaths: newCodexPaths, claudePaths: newClaudePaths)
        }.value

        tokenCache = scan.tokens
        codexPathCache = scan.codexPaths
        claudePathCache = scan.claudePaths
        sessions = scan.sessions.sorted { $0.lastActivityAt > $1.lastActivityAt }
        isScanning = false
        for handler in observers.values {
            handler(sessions)
        }
    }

    /// Keeps one session per open project and agent, dropping everything else.
    ///
    /// A session matches on its recorded cwd, and only against the agents
    /// actually running there - a project open in Claude does not resurrect the
    /// three old Codex transcripts written in it earlier today. Recent Codex
    /// Desktop transcripts are also accepted, then collapsed to the newest row
    /// per project because the shared app-server has no project-specific cwd.
    nonisolated static func sessionsInOpenProjects(
        _ sessions: [IDESession],
        openProjects: [String: Set<IDEType>],
        now: Date = Date()
    ) -> [IDESession] {
        // A Claude transcript whose cwd could not be read still carries its
        // directory name, which is the cwd with every "/" replaced by "-".
        let byDirectoryName = Dictionary(
            openProjects.map { ($0.key.replacingOccurrences(of: "/", with: "-"), $0.value) },
            uniquingKeysWith: { $0.union($1) }
        )

        var mostRecent: [String: IDESession] = [:]

        for session in sessions {
            let path = SessionPath.normalize(session.projectPath)
            let liveAgents = openProjects[path] ?? byDirectoryName[session.id]
            let hasMatchingProcess = liveAgents?.contains(session.ide) == true

            // Codex Desktop uses one shared app-server whose cwd is the app's
            // launch directory, not the cwd of each visible task. Its session
            // JSONL is the per-task liveness signal, so retain recently written
            // Codex transcripts even when no project-scoped process is visible.
            let hasRecentCodexTranscript = session.ide == .codex && session.isActive(at: now)
            guard hasMatchingProcess || hasRecentCodexTranscript else {
                continue
            }

            let key = "\(path)|\(session.ide.rawValue)"
            if let existing = mostRecent[key], existing.lastActivityAt >= session.lastActivityAt {
                continue
            }
            mostRecent[key] = session
        }

        return Array(mostRecent.values)
    }

    // MARK: - Claude Sessions

    private nonisolated static func scanClaudeSessions(
        cache: inout [String: (Date, Int)],
        pathCache: inout [String: String]
    ) -> [IDESession] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeRoot = home.appendingPathComponent(".claude/projects")

        guard FileManager.default.fileExists(atPath: claudeRoot.path) else {
            return []
        }

        var sessions: [IDESession] = []
        let manager = FileManager.default

        guard let projects = try? manager.contentsOfDirectory(at: claudeRoot, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }

        for project in projects {
            guard project.hasDirectoryPath else { continue }

            // Find the most recent JSONL file in this project
            if let session = findMostRecentSession(in: project, ide: .claude, cache: &cache, pathCache: &pathCache) {
                sessions.append(session)
            }
        }

        return sessions
    }

    // MARK: - Codex Sessions

    private nonisolated static func scanCodexSessions(cache: inout [String: (Date, Int)], pathCache: inout [String: String]) -> [IDESession] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let codexRoot = home.appendingPathComponent(".codex/sessions")

        guard FileManager.default.fileExists(atPath: codexRoot.path) else {
            return []
        }

        var sessions: [IDESession] = []
        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: today)

        let dayRoot = codexRoot
            .appendingPathComponent(String(format: "%04d", components.year ?? 0))
            .appendingPathComponent(String(format: "%02d", components.month ?? 0))
            .appendingPathComponent(String(format: "%02d", components.day ?? 0))

        guard FileManager.default.fileExists(atPath: dayRoot.path),
              let files = try? FileManager.default.contentsOfDirectory(at: dayRoot, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }

        for file in files where file.pathExtension == "jsonl" {
            // Codex groups sessions by date, so the containing folder is a day
            // number ("28") - useless as a label. The real project lives in the
            // session_meta line at the head of the file.
            let projectPath = codexProjectPath(for: file, pathCache: &pathCache)
            if let session = createSession(from: file, ide: .codex, projectPath: projectPath, cache: &cache) {
                sessions.append(session)
            }
        }

        return sessions
    }

    // MARK: - Hook Sessions (OpenCode/Kimi)

    /// Sessions rebuilt from the log Vibe Hero's own hooks append to.
    ///
    /// Unlike a transcript this is one file shared by every tool the hooks are
    /// installed in, so a line is an event, not a session: the tail is folded
    /// into one session per project and tool.
    private nonisolated static func scanHookSessions(openProjects: [String: Set<IDEType>]?) -> [IDESession] {
        struct Aggregate {
            let ide: IDEType
            let projectPath: String
            var lastActivityAt: Date
            var tokenCount: Int
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let hookLog = home.appendingPathComponent(".vibe-hero/token-events.jsonl")
        let timestamps = HookTimestampParser()
        var aggregates: [String: Aggregate] = [:]

        for line in hookLogTail(hookLog) {
            guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let source = json["source"] as? String,
                  let ide = hookIDE(for: source),
                  let raw = json["timestamp"] as? String,
                  let timestamp = timestamps.date(from: raw) else {
                continue
            }

            let payload = json["payload"] as? [String: Any] ?? [:]
            let tokenCount = hookTokenCount(in: payload)

            for path in hookProjectPaths(payload: payload, ide: ide, openProjects: openProjects) {
                let key = "\(path)|\(ide.rawValue)"
                var aggregate = aggregates[key] ?? Aggregate(
                    ide: ide,
                    projectPath: path,
                    lastActivityAt: .distantPast,
                    tokenCount: 0
                )
                aggregate.lastActivityAt = max(aggregate.lastActivityAt, timestamp)
                aggregate.tokenCount += tokenCount
                aggregates[key] = aggregate
            }
        }

        return aggregates.map { key, aggregate in
            IDESession(
                id: "hook-\(key)",
                ide: aggregate.ide,
                projectPath: aggregate.projectPath,
                lastActivityAt: aggregate.lastActivityAt,
                tokenCount: aggregate.tokenCount
            )
        }
    }

    /// Claude and Codex events are dropped: both keep transcripts, which the
    /// scans above already read for activity and token counts, so a hook event
    /// would only duplicate the row from worse data. (The old mapping sent every
    /// non-Kimi source to OpenCode, so a Claude event showed up as an OpenCode
    /// session.)
    private nonisolated static func hookIDE(for source: String) -> IDEType? {
        switch source.lowercased() {
        case "opencode": .opencode
        case "kimi": .kimi
        case "openclaw": .openclaw
        case "hermes": .hermes
        default: nil
        }
    }

    /// Which projects a hook event belongs to.
    ///
    /// The shell hook forwards the tool's own payload, which carries `cwd`. The
    /// OpenCode plugin and the Kimi MCP server forward their event objects,
    /// which name no directory at all, so those events fall back to the projects
    /// that tool currently has open - the process table is the only other place
    /// a project name appears.
    private nonisolated static func hookProjectPaths(
        payload: [String: Any],
        ide: IDEType,
        openProjects: [String: Set<IDEType>]?
    ) -> [String] {
        if let cwd = payload["cwd"] as? String, !cwd.isEmpty {
            return [SessionPath.normalize(cwd)]
        }

        guard let openProjects else {
            return []
        }

        return openProjects.filter { $0.value.contains(ide) }.map(\.key)
    }

    /// Tokens a hook event reports, across the shapes the three writers use.
    ///
    /// The hook log's file size used to stand in for this, which credited a
    /// single session with every token the shared log had ever recorded - tens of
    /// millions of them.
    private nonisolated static func hookTokenCount(in payload: [String: Any]) -> Int {
        if let total = payload["total_tokens"] as? Int {
            return total
        }

        if let usage = payload["usage"] as? [String: Any] {
            return hookTokenCount(in: usage)
        }

        if let info = payload["info"] as? [String: Any],
           let usage = info["last_token_usage"] as? [String: Any] {
            return hookTokenCount(in: usage)
        }

        let input = payload["input_tokens"] as? Int ?? 0
        let output = payload["output_tokens"] as? Int ?? 0
        return input + output
    }

    /// The last complete lines of the hook log.
    ///
    /// Hook payloads embed whole tool responses, so one line runs to tens of
    /// kilobytes; the old 4KB window usually held no complete line at all, which
    /// meant nothing parsed no matter what else was fixed. The window is capped
    /// in bytes rather than lines, and the first line of a truncated read is
    /// dropped because it starts mid-record.
    private nonisolated static func hookLogTail(_ file: URL, maxBytes: UInt64 = 512 * 1024) -> [Data] {
        guard let handle = try? FileHandle(forReadingFrom: file) else {
            return []
        }
        defer { try? handle.close() }

        guard let fileSize = try? handle.seekToEnd(), fileSize > 0 else {
            return []
        }

        let offset = fileSize > maxBytes ? fileSize - maxBytes : 0
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.readToEnd() else {
            return []
        }

        var lines = data.split(separator: 0x0A).map { Data($0) }
        if offset > 0, !lines.isEmpty {
            lines.removeFirst()
        }

        return lines
    }

    // MARK: - Helpers

    private nonisolated static func findMostRecentSession(
        in projectDir: URL,
        ide: IDEType,
        cache: inout [String: (Date, Int)],
        pathCache: inout [String: String]
    ) -> IDESession? {
        // Claude stores JSONL files directly in project directory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return nil
        }

        var mostRecentFile: URL?
        var mostRecentDate: Date?

        for file in files where file.pathExtension == "jsonl" {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modifiedAt = values.contentModificationDate else {
                continue
            }

            if mostRecentDate == nil || modifiedAt > mostRecentDate! {
                mostRecentDate = modifiedAt
                mostRecentFile = file
            }
        }

        // Also check subdirectories for nested JSONL files
        if mostRecentFile == nil {
            guard let enumerator = FileManager.default.enumerator(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else {
                return nil
            }

            for case let file as URL in enumerator where file.pathExtension == "jsonl" {
                guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modifiedAt = values.contentModificationDate else {
                    continue
                }

                if mostRecentDate == nil || modifiedAt > mostRecentDate! {
                    mostRecentDate = modifiedAt
                    mostRecentFile = file
                }
            }
        }

        guard let file = mostRecentFile, let date = mostRecentDate else {
            return nil
        }

        let tokenCount = getCachedTokenCount(for: file, cache: &cache)
        let projectPath = claudeProjectPath(for: file, projectDir: projectDir, pathCache: &pathCache)

        return IDESession(
            id: projectDir.lastPathComponent,
            ide: ide,
            projectPath: projectPath ?? projectDir.path,
            lastActivityAt: date,
            tokenCount: tokenCount
        )
    }

    private nonisolated static func createSession(
        from file: URL,
        ide: IDEType,
        projectPath: String? = nil,
        cache: inout [String: (Date, Int)]
    ) -> IDESession? {
        guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
              let modifiedAt = values.contentModificationDate else {
            return nil
        }

        let tokenCount = getCachedTokenCount(for: file, cache: &cache)

        return IDESession(
            id: file.deletingPathExtension().lastPathComponent,
            ide: ide,
            projectPath: projectPath ?? file.deletingLastPathComponent().path,
            lastActivityAt: modifiedAt,
            tokenCount: tokenCount
        )
    }

    /// Reads the `cwd` recorded on a Claude transcript record.
    ///
    /// Claude names a project directory after its path with every "/" replaced
    /// by "-", which cannot be reversed - project names contain dashes too - so
    /// the raw directory name ("-Users-me-Documents-notch-hero") is the only
    /// label available without opening a transcript. `cwd` shows up within the
    /// first handful of records, so a bounded prefix is enough, and the answer is
    /// the same for every transcript in the directory, hence the per-directory
    /// cache.
    private nonisolated static func claudeProjectPath(
        for file: URL,
        projectDir: URL,
        pathCache: inout [String: String]
    ) -> String? {
        if let cached = pathCache[projectDir.path] {
            return cached
        }

        guard let handle = try? FileHandle(forReadingFrom: file) else {
            return nil
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 256 * 1024) else {
            return nil
        }

        // The trailing chunk is likely a line the read cut in half; it simply
        // fails to parse and is skipped.
        for line in data.split(separator: 0x0A).prefix(24) {
            guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let cwd = json["cwd"] as? String,
                  !cwd.isEmpty else {
                continue
            }

            pathCache[projectDir.path] = cwd
            return cwd
        }

        return nil
    }

    /// Reads the `cwd` out of a Codex session's leading `session_meta` record.
    /// That line embeds the base instructions and can be tens of KB, so only a
    /// bounded prefix is read, and the result is cached per file.
    private nonisolated static func codexProjectPath(for file: URL, pathCache: inout [String: String]) -> String? {
        if let cached = pathCache[file.path] {
            return cached
        }

        guard let handle = try? FileHandle(forReadingFrom: file) else {
            return nil
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 512 * 1024),
              let newlineIndex = data.firstIndex(of: 0x0A) else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data[data.startIndex..<newlineIndex]) as? [String: Any],
              let payload = json["payload"] as? [String: Any],
              let cwd = payload["cwd"] as? String,
              !cwd.isEmpty else {
            return nil
        }

        pathCache[file.path] = cwd
        return cwd
    }

    private nonisolated static func getCachedTokenCount(for file: URL, cache: inout [String: (Date, Int)]) -> Int {
        let path = file.path

        guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let modifiedAt = values.contentModificationDate,
              let fileSize = values.fileSize else {
            return 0
        }

        // Check cache - if file hasn't changed, return cached count
        if let cached = cache[path], cached.0 == modifiedAt {
            return cached.1
        }

        // Estimate token count from file size (fast approximation)
        // Average ~50 tokens per line, ~100 bytes per line
        let estimatedTokens = fileSize / 100 * 50

        // For small files, do actual count
        if fileSize < 100_000 {
            let actualCount = countTokensInFile(file)
            cache[path] = (modifiedAt, actualCount)
            return actualCount
        }

        // For large files, use estimate and cache it
        cache[path] = (modifiedAt, estimatedTokens)
        return estimatedTokens
    }

    private nonisolated static func countTokensInFile(_ file: URL) -> Int {
        guard let data = try? Data(contentsOf: file),
              let text = String(data: data, encoding: .utf8) else {
            return 0
        }

        var total = 0
        for line in text.split(separator: "\n") {
            guard line.contains("\"total_tokens\"") || line.contains("\"input_tokens\""),
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let payload = json["payload"] as? [String: Any],
               let tokens = payload["total_tokens"] as? Int {
                total += tokens
            } else if let usage = json["usage"] as? [String: Any] {
                let input = (usage["input_tokens"] as? Int) ?? 0
                let output = (usage["output_tokens"] as? Int) ?? 0
                total += input + output
            }
        }

        return total
    }
}

// MARK: - Session List View

/// Flipped so the scrolled rows stack downward from the top.
private final class SessionRowsView: NSView {
    override var isFlipped: Bool { true }
}

/// Frame-based list, deliberately not Auto Layout.
///
/// The notch HUD positions all of its children with explicit frames, and an
/// `NSStackView` of rows wanted ~245pt inside a 92pt slot, so Auto Layout
/// resolved the conflict by compressing every arranged subview: the header and
/// the last rows ended up 0pt tall and the HUD rendered an empty dark box even
/// though the rows existed and were not hidden. Laying the rows out by hand
/// keeps every row at full height.
///
/// The header stays pinned and the rows live in a scroll view: the HUD grows
/// the notch panel toward `preferredContentHeight`, and anything that still
/// does not fit scrolls instead of disappearing.
final class SessionListView: NSView {
    private enum Metrics {
        static let horizontalInset: CGFloat = 8
        static let verticalInset: CGFloat = 4
        static let headerHeight: CGFloat = 12
        static let headerGap: CGFloat = 3
        static let rowHeight: CGFloat = 17
        static let rowGap: CGFloat = 2
        static let overflowHeight: CGFloat = 11
        static let emptyHeight: CGFloat = 14
        /// Rows are cheap but not free, and a list this long is a browser, not a
        /// glance; the tail collapses into "+N more" and the header still
        /// reports the true total.
        static let maxRows = 60
    }

    private let headerLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    private let overflowLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let rowsView = SessionRowsView()
    private var rowViews: [SessionRowView] = []
    private var sessions: [IDESession] = []
    private var displayedIds: [String] = []

    /// Height at which nothing has to scroll. The HUD asks for this much room
    /// for the panel and settles for less.
    var preferredContentHeight: CGFloat {
        intrinsicContentSize.height
    }

    // Top-down coordinates make the list layout read in the order it draws.
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        // Dark background matching HUD style
        layer?.backgroundColor = NSColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 0.95).cgColor
        layer?.cornerRadius = 8
        clipsToBounds = true

        headerLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        headerLabel.textColor = NSColor.white.withAlphaComponent(0.7)

        emptyLabel.font = .systemFont(ofSize: 11)
        emptyLabel.textColor = NSColor.white.withAlphaComponent(0.5)

        overflowLabel.font = .systemFont(ofSize: 9)
        overflowLabel.textColor = NSColor.white.withAlphaComponent(0.45)

        for label in [headerLabel, emptyLabel, overflowLabel] {
            label.maximumNumberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
        }
        // Set before the first scan lands so the empty state is not a blank card.
        emptyLabel.stringValue = L10n.text(.noActiveSessions)
        addSubview(headerLabel)
        addSubview(emptyLabel)

        // Overlay scrollers so the rows keep the full width when idle.
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = rowsView
        addSubview(scrollView)

        rowsView.addSubview(overflowLabel)
    }

    func updateSessions(_ sessions: [IDESession]) {
        let rowSessions = Array(sessions.prefix(Metrics.maxRows))
        let ids = rowSessions.map(\.id)

        self.sessions = sessions
        headerLabel.stringValue = headerText(for: sessions)
        emptyLabel.stringValue = L10n.text(.noActiveSessions)

        // Reuse the existing rows whenever the roster is unchanged - a reorder
        // is handled by re-applying content per index, so only a membership or
        // count change needs to rebuild.
        if Set(ids) == Set(displayedIds), rowViews.count == rowSessions.count {
            for (index, session) in rowSessions.enumerated() {
                rowViews[index].update(session: session)
            }
        } else {
            rowViews.forEach { $0.removeFromSuperview() }
            rowViews = rowSessions.map { session in
                let row = SessionRowView(session: session)
                rowsView.addSubview(row)
                return row
            }
        }

        displayedIds = ids
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    /// Total plus a per-agent breakdown, so a mixed list says which agents it is
    /// made of before any row is read. Agent names are product names and stay in
    /// English in every language, like they do in the tools tab. The header
    /// truncates at the tail in the narrow HUD, which keeps the total visible.
    private func headerText(for sessions: [IDESession]) -> String {
        let total = L10n.string(.sessionCount, sessions.count)
        guard sessions.count > 1 else {
            return total
        }

        let breakdown = IDEType.allCases.compactMap { ide -> String? in
            let count = sessions.filter { $0.ide == ide }.count
            return count > 0 ? "\(ide.displayName) \(count)" : nil
        }

        // A single agent is already spelled out on every row.
        guard breakdown.count > 1 else {
            return total
        }
        return total + " · " + breakdown.joined(separator: " · ")
    }

    /// Full height of the list with nothing scrolled away. The HUD reads this
    /// through `preferredContentHeight` to size the expanded panel, and the
    /// settings window uses it directly, where the list is driven by Auto Layout
    /// inside a scroll view with no height of its own.
    override var intrinsicContentSize: NSSize {
        let vertical = Metrics.verticalInset * 2

        guard !sessions.isEmpty else {
            return NSSize(width: NSView.noIntrinsicMetric, height: vertical + Metrics.emptyHeight)
        }

        var height = vertical + Metrics.headerHeight
        if !rowViews.isEmpty {
            height += Metrics.headerGap
            height += CGFloat(rowViews.count) * Metrics.rowHeight
            height += CGFloat(rowViews.count - 1) * Metrics.rowGap
        }
        if sessions.count > rowViews.count {
            height += Metrics.rowGap + Metrics.overflowHeight
        }

        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    override func layout() {
        super.layout()

        let inset = Metrics.horizontalInset
        let contentWidth = max(0, bounds.width - inset * 2)
        var y = Metrics.verticalInset

        guard !sessions.isEmpty else {
            headerLabel.isHidden = true
            scrollView.isHidden = true
            emptyLabel.isHidden = false
            emptyLabel.frame = NSRect(x: inset, y: y, width: contentWidth, height: Metrics.emptyHeight)
            return
        }

        emptyLabel.isHidden = true
        headerLabel.isHidden = false
        scrollView.isHidden = false
        headerLabel.frame = NSRect(x: inset, y: y, width: contentWidth, height: Metrics.headerHeight)
        y += Metrics.headerHeight + Metrics.headerGap

        let scrollHeight = max(0, bounds.height - Metrics.verticalInset - y)
        scrollView.frame = NSRect(x: inset, y: y, width: contentWidth, height: scrollHeight)
        layoutRows(width: contentWidth, visibleHeight: scrollHeight)
    }

    /// Lays the rows out inside the scrolled document view. The document is
    /// never shorter than the clip view: an undersized flipped document would be
    /// parked at the bottom of the (unflipped) clip view, leaving the rows
    /// floating below the header.
    private func layoutRows(width: CGFloat, visibleHeight: CGFloat) {
        var y: CGFloat = 0

        for row in rowViews {
            row.frame = NSRect(x: 0, y: y, width: width, height: Metrics.rowHeight)
            y += Metrics.rowHeight + Metrics.rowGap
        }

        let remaining = sessions.count - rowViews.count
        if remaining > 0 {
            overflowLabel.isHidden = false
            overflowLabel.stringValue = L10n.string(.moreSessions, remaining)
            overflowLabel.frame = NSRect(x: 0, y: y, width: width, height: Metrics.overflowHeight)
            y += Metrics.overflowHeight
        } else {
            overflowLabel.isHidden = true
            y = max(0, y - Metrics.rowGap)
        }

        rowsView.frame = NSRect(x: 0, y: 0, width: width, height: max(y, visibleHeight))

        // The panel grows to fit, so a list that needed scrolling a moment ago
        // may fit now; scroll back to the top so the header is not left above a
        // stale offset with empty space under the last row.
        if y <= visibleHeight, scrollView.contentView.bounds.origin.y != 0 {
            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}

final class SessionRowView: NSView {
    private enum Metrics {
        static let iconWidth: CGFloat = 16
        static let statusWidth: CGFloat = 46
        static let tokenWidth: CGFloat = 44
        static let gap: CGFloat = 6
        static let agentHeight: CGFloat = 13
        static let agentPadding: CGFloat = 5

        @MainActor static let agentFont = NSFont.systemFont(ofSize: 9, weight: .semibold)

        /// One column wide enough for every agent name: the tags line up down the
        /// list, and none of them gets truncated to something unreadable like
        /// "Claude C…" - telling the agents apart is the whole point of the tag.
        /// Measured through a field built by the same factory as the real tag: a
        /// label configured for truncation reports a wider fit than a bare one,
        /// and measuring the bare one is what clipped "Claude Code".
        @MainActor static let agentWidth: CGFloat = {
            let ruler = SessionRowView.makeAgentLabel()
            let widest = IDEType.allCases
                .map { ide -> CGFloat in
                    ruler.stringValue = ide.displayName
                    return ruler.fittingSize.width
                }
                .max() ?? 0
            return (widest + agentPadding * 2).rounded(.up)
        }()
    }

    private static func makeAgentLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = Metrics.agentFont
        label.alignment = .center
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private let iconLabel = NSTextField(labelWithString: "")
    private let agentChip = NSView()
    private let agentLabel = SessionRowView.makeAgentLabel()
    private let nameLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let tokenLabel = NSTextField(labelWithString: "")

    init(session: IDESession) {
        super.init(frame: .zero)
        setup()
        update(session: session)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        iconLabel.font = .systemFont(ofSize: 12)

        agentChip.wantsLayer = true
        agentChip.layer?.cornerRadius = 4
        addSubview(agentChip)
        agentChip.addSubview(agentLabel)

        nameLabel.font = .systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingMiddle

        statusLabel.font = .systemFont(ofSize: 8)

        tokenLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        tokenLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        tokenLabel.alignment = .right

        for label in [iconLabel, nameLabel, statusLabel, tokenLabel] {
            label.maximumNumberOfLines = 1
            addSubview(label)
        }
    }

    override func layout() {
        super.layout()

        func centeredY(_ height: CGFloat) -> CGFloat {
            ((bounds.height - height) / 2).rounded()
        }

        iconLabel.frame = NSRect(x: 0, y: centeredY(14), width: Metrics.iconWidth, height: 14)
        tokenLabel.frame = NSRect(
            x: max(0, bounds.width - Metrics.tokenWidth),
            y: centeredY(11),
            width: Metrics.tokenWidth,
            height: 11
        )
        statusLabel.frame = NSRect(
            x: max(0, tokenLabel.frame.minX - Metrics.gap - Metrics.statusWidth),
            y: centeredY(10),
            width: Metrics.statusWidth,
            height: 10
        )

        agentChip.frame = NSRect(
            x: iconLabel.frame.maxX + Metrics.gap,
            y: centeredY(Metrics.agentHeight),
            width: Metrics.agentWidth,
            height: Metrics.agentHeight
        )
        agentLabel.frame = NSRect(
            x: Metrics.agentPadding,
            y: ((Metrics.agentHeight - 11) / 2).rounded(),
            width: Metrics.agentWidth - Metrics.agentPadding * 2,
            height: 11
        )

        let nameX = agentChip.frame.maxX + Metrics.gap
        nameLabel.frame = NSRect(
            x: nameX,
            y: centeredY(12),
            width: max(0, statusLabel.frame.minX - Metrics.gap - nameX),
            height: 12
        )
    }

    func update(session: IDESession) {
        // The icon and the agent tag live here rather than in setup so a reordered
        // roster can be re-applied per index without rebuilding the row views.
        iconLabel.stringValue = session.ide.icon
        agentLabel.stringValue = session.ide.displayName
        agentLabel.textColor = session.ide.color
        agentChip.layer?.backgroundColor = session.ide.color.withAlphaComponent(0.16).cgColor
        nameLabel.stringValue = session.displayName
        nameLabel.toolTip = "\(session.ide.displayName) · \(session.projectPath)"
        statusLabel.stringValue = session.isActive ? "● Active" : "○ Idle"
        statusLabel.textColor = session.isActive
            ? NSColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1)
            : NSColor.white.withAlphaComponent(0.4)
        tokenLabel.stringValue = formatTokens(session.tokenCount)
    }

    private func formatTokens(_ count: Int) -> String {
        // Token counts: abbreviated with K/M
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
