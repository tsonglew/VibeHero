import Foundation

/// Counts use disjoint buckets: input excludes cached input; output includes reasoning.
struct TokenUsageTotals: Sendable {
    var inputTokens = 0
    var outputTokens = 0
    var cacheTokens = 0
    var eventCount = 0
    var latestEventAt: Date?

    var totalTokens: Int { inputTokens + outputTokens + cacheTokens }

    fileprivate mutating func add(_ usage: TokenUsage, at timestamp: Date) {
        inputTokens += usage.input
        outputTokens += usage.output
        cacheTokens += usage.cache
        eventCount += 1
        latestEventAt = max(latestEventAt ?? timestamp, timestamp)
    }
}

struct TokenUsageSessionSummary: Sendable {
    let source: String
    let sessionID: String
    var projectPath: String?
    var totals = TokenUsageTotals()
    var filePaths: Set<String> = []

    var totalTokens: Int { totals.totalTokens }
    var latestEventAt: Date? { totals.latestEventAt }
}

struct TokenUsageSnapshot: Sendable {
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let recentTokens: Int
    let sourceBreakdown: [String: Int]
    let eventCount: Int
    let latestEventAt: Date?
    let generatedAt: Date
    // File keys are canonical paths (symlinks resolved). Copies/archives can
    // contain the same events. File totals are lookup values,
    // not additive; sessionBreakdown and the top-level total are deduplicated.
    var fileBreakdown: [String: TokenUsageTotals] = [:]
    var sessionBreakdown: [String: TokenUsageSessionSummary] = [:]
    /// Only verified native records, used by automatic-source status labels.
    var nativeSourceBreakdown: [String: Int] = [:]

    var hasRealData: Bool { eventCount > 0 }

    var dominantSource: String {
        sourceBreakdown.max { $0.value < $1.value }?.key ?? "No source"
    }
}

enum TokenUsageScanner {
    private static let ledger = TokenUsageLedger()

    static func scanToday(now: Date = Date()) -> TokenUsageSnapshot {
        ledger.scanToday(now: now)
    }

    static var latestSnapshot: TokenUsageSnapshot? { ledger.latestSnapshot }
}

/// An independently constructible ledger so fixtures never touch the user's logs.
/// Only accounting fields and session/project identities survive parsing. The lock
/// serializes scans, file cursors and Foundation's reusable date formatters.
final class TokenUsageLedger: @unchecked Sendable {
    private let sources: [AgentSource]
    private let calendar: Calendar
    private let lock = NSLock()
    private let snapshotLock = NSLock()
    private var cachedSnapshot: TokenUsageSnapshot?
    private var scanDay: Date?
    private var files: [String: FileCursor] = [:]
    private var records: [String: UsageRecord] = [:]
    private var priorCumulative: [String: UsageRecord] = [:]
    private var priorGenerations: [String: UsageRecord] = [:]
    private var sortedRecords: [UsageRecord] = []
    private var orderingDirty = false
    private let fractionalDate = ISO8601DateFormatter()
    private let plainDate = ISO8601DateFormatter()

    init(sources: [AgentSource] = AgentSourceCatalog.all, calendar: Calendar = .current) {
        self.sources = sources
        self.calendar = calendar
        fractionalDate.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        plainDate.formatOptions = [.withInternetDateTime]
    }

    var latestSnapshot: TokenUsageSnapshot? {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return cachedSnapshot
    }

    func scanToday(now: Date = Date()) -> TokenUsageSnapshot {
        lock.lock()
        defer { lock.unlock() }
        let startOfDay = calendar.startOfDay(for: now)
        if scanDay != startOfDay {
            scanDay = startOfDay
            files.removeAll(keepingCapacity: true)
            records.removeAll(keepingCapacity: true)
            priorCumulative.removeAll(keepingCapacity: true)
            priorGenerations.removeAll(keepingCapacity: true)
            sortedRecords.removeAll(keepingCapacity: true)
            orderingDirty = false
        }

        for source in sources {
            for file in transcriptFiles(for: source, modifiedSince: startOfDay) {
                ingest(file, source: source)
            }
        }
        let result = snapshot(startOfDay: startOfDay, now: now)
        snapshotLock.lock()
        cachedSnapshot = result
        snapshotLock.unlock()
        return result
    }

    private func transcriptFiles(for source: AgentSource, modifiedSince: Date) -> [URL] {
        switch source.layout {
        case .projectTree:
            return jsonlFiles(under: source.root, modifiedSince: modifiedSince)
        case .dateBucketedTree(let archive):
            // A date bucket is the session's creation date, not its activity date.
            // Resume and midnight writes can target any older bucket.
            return jsonlFiles(under: source.root, modifiedSince: modifiedSince)
                + jsonlFiles(under: archive, modifiedSince: modifiedSince)
        case .singleLogFile:
            return [source.root]
        case .kimiWireTree:
            return jsonlFiles(under: source.root, modifiedSince: modifiedSince).filter { $0.lastPathComponent == "wire.jsonl" }
        }
    }

    private func jsonlFiles(under root: URL, modifiedSince: Date) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
            return []
        }
        var result: [URL] = []
        for case let file as URL in enumerator where file.pathExtension == "jsonl" {
            guard let attributes = try? file.resourceValues(forKeys: Set(keys)),
                  attributes.isRegularFile == true,
                  (attributes.contentModificationDate ?? .distantFuture) >= modifiedSince else { continue }
            result.append(file)
        }
        return result.sorted { $0.path < $1.path }
    }

    private func ingest(_ file: URL, source: AgentSource) {
        let path = file.resolvingSymlinksInPath().path
        guard let handle = try? FileHandle(forReadingFrom: file),
              let attributes = try? FileManager.default.attributesOfItem(atPath: path) else { return }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return }
        let identity = "\(attributes[.systemNumber] ?? ""):\(attributes[.systemFileNumber] ?? "")"
        let modifiedAt = attributes[.modificationDate] as? Date
        var cursor = files[path] ?? FileCursor(identity: identity)

        // Inode replacement, shrinking, and an in-place rewrite need a fresh
        // cursor. Accepted logical events remain in the day's ledger: rotating a
        // log cannot un-spend tokens, and replay is deduplicated below.
        let boundary = readBoundary(handle, offset: min(cursor.offset, size))
        if cursor.identity != identity || size < cursor.offset
            || (cursor.offset > 0 && boundary != cursor.boundary)
            || (size == cursor.offset && modifiedAt != cursor.modifiedAt) {
            cursor = FileCursor(identity: identity)
        }
        if case .kimiWireTree(let format) = source.layout, cursor.kimiContext == nil {
            guard let context = KimiWireUsage.context(for: file, root: source.root, format: format) else { return }
            cursor.kimiContext = context
            cursor.sessionID = context.sessionID
            cursor.projectPath = context.projectPath
            cursor.kimiForkReady = !context.requiresForkMarker
        }
        guard (try? handle.seek(toOffset: cursor.offset)) != nil,
              let data = try? handle.readToEnd(), !data.isEmpty else {
            cursor.modifiedAt = modifiedAt
            files[path] = cursor
            return
        }
        // A writer can be in the middle of a UTF-8 character or JSON record.
        guard let lastNewline = data.lastIndex(of: 0x0A) else {
            files[path] = cursor
            return
        }
        let complete = data.prefix(through: lastNewline)
        let lines = complete.split(separator: 0x0A)
        var firstLine = 0
        if case .kimiWireTree(format: .current) = source.layout {
            // A fork contains copied history followed by a marker. Find the
            // final marker before accepting any accounting from this chunk.
            if let marker = lines.lastIndex(where: { line in
                guard let value = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return false }
                return value["type"] as? String == "forked"
            }) {
                firstLine = marker + 1
                cursor.kimiForkReady = true
            }
            if !cursor.kimiForkReady, let context = cursor.kimiContext,
               let first = lines.first,
               let metadata = try? JSONSerialization.jsonObject(with: first) as? [String: Any],
               KimiWireUsage.isNewAgentMetadata(metadata, context: context) {
                cursor.kimiForkReady = true
            }
            guard cursor.kimiForkReady else { return }
        }
        for line in lines.dropFirst(firstLine) {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            if case .kimiWireTree(let format) = source.layout, let context = cursor.kimiContext {
                if let parsed = KimiWireUsage.parse(object, format: format, context: context) {
                    merge(UsageRecord(
                        id: parsed.identity, sessionKey: "Kimi|\(context.sessionID)", sessionID: context.sessionID,
                        source: "Kimi", projectPath: context.projectPath, timestamp: parsed.timestamp,
                        usage: TokenUsage(input: parsed.input, output: parsed.output, cache: parsed.cache),
                        cumulative: nil, isHook: false, hasSessionID: true, paths: [path]
                    ))
                }
                continue
            }
            if !source.isHookLog, source.label == "Codex", object["type"] as? String == "session_meta",
               let metadata = object["payload"] as? [String: Any] {
                cursor.sessionID = nonempty(metadata["id"])
                cursor.projectPath = nonempty(metadata["cwd"])
                cursor.createdAt = date(metadata["timestamp"]) ?? date(object["timestamp"])
                continue
            }
            if let record = parse(object, source: source, path: path, cursor: cursor) {
                merge(record)
            }
        }
        cursor.offset += UInt64(complete.count)
        cursor.boundary = readBoundary(handle, offset: cursor.offset)
        cursor.modifiedAt = modifiedAt
        files[path] = cursor
    }

    private func readBoundary(_ handle: FileHandle, offset: UInt64) -> Data {
        let length = min(offset, 256)
        guard (try? handle.seek(toOffset: offset - length)) != nil else { return Data() }
        return (try? handle.read(upToCount: Int(length))) ?? Data()
    }

    private func parse(_ object: [String: Any], source: AgentSource, path: String, cursor: FileCursor) -> UsageRecord? {
        guard let timestamp = date(object["timestamp"]) ?? date(object["created_at"]) else { return nil }
        let payload = object["payload"] as? [String: Any] ?? [:]
        let label = source.isHookLog
            ? (AgentSourceCatalog.normalizedLabel(for: nonempty(object["source"])) ?? source.label)
            : source.label
        let explicitSession = nonempty(object["sessionId"]) ?? nonempty(object["session_id"])
            ?? nonempty(payload["session_id"]) ?? nonempty(payload["sessionId"])
            ?? nonempty(payload["sessionID"]) ?? cursor.sessionID
        let project = nonempty(object["cwd"]) ?? nonempty(payload["cwd"]) ?? cursor.projectPath
        // A transcript filename survives archive moves. Hooks without a session
        // ID can only be attributed to their project, or remain unattributed.
        let sessionID = explicitSession ?? (source.isHookLog
            ? project.map { "project:\($0)" } ?? "unattributed"
            : "transcript:\(URL(fileURLWithPath: path).lastPathComponent)")
        let sessionKey = "\(label)|\(sessionID)"

        if label == "Codex", payload["type"] as? String == "token_count",
           let info = payload["info"] as? [String: Any] {
            // Forked rollouts may contain copied records from before the new
            // session metadata. Those records are history, not new spending.
            if let createdAt = cursor.createdAt, timestamp < createdAt { return nil }
            let cumulative = (info["total_token_usage"] as? [String: Any]).map(TokenUsage.codex)
            let last = (info["last_token_usage"] as? [String: Any]).map(TokenUsage.codex)
            guard cumulative != nil || last != nil else { return nil }
            let identity = "\(timestamp.timeIntervalSince1970)|\(cumulative?.signature ?? "")|\(last?.signature ?? "")"
            return UsageRecord(
                id: "\(sessionKey)|codex|\(identity)", sessionKey: sessionKey, sessionID: sessionID,
                source: label, projectPath: project, timestamp: timestamp,
                usage: last, cumulative: cumulative, isHook: source.isHookLog,
                hasSessionID: explicitSession != nil, paths: [path]
            )
        }

        var usage: TokenUsage?
        var eventID: String?
        var generationID: String?
        if label == "Claude", let message = object["message"] as? [String: Any],
           let counters = message["usage"] as? [String: Any] {
            usage = .claude(counters)
            // Multiple content blocks / streaming updates share one generation.
            eventID = nonempty(message["id"]) ?? nonempty(object["request_id"]) ?? nonempty(object["requestId"])
                ?? nonempty(object["uuid"])
            generationID = eventID.map { "\(sessionKey)|\($0)" }
        } else if source.isHookLog {
            // Explicit hook contracts only. In particular, never search tool
            // output or prompt text recursively for a dictionary called usage.
            if let counters = payload["usage"] as? [String: Any] ?? object["usage"] as? [String: Any] {
                usage = label == "Codex" ? .codex(counters) : .generic(counters)
            } else if let info = payload["info"] as? [String: Any],
                      let counters = info["last_token_usage"] as? [String: Any] {
                usage = .generic(counters)
            } else if TokenUsage.hasCounters(payload) {
                usage = .generic(payload)
            } else if TokenUsage.hasCounters(object) {
                usage = .generic(object)
            }
            eventID = nonempty(payload["event_id"]) ?? nonempty(object["event_id"])
                ?? nonempty(payload["message_id"]) ?? nonempty(payload["request_id"])
        }
        guard let usage, usage.total > 0 else { return nil }
        // Writers lacking event IDs have no exact-once contract. Deduplicate
        // identical timestamp + counters; equal-sized calls with distinct
        // timestamps remain separate. They should provide an event_id to make
        // same-timestamp calls distinguishable.
        let sampleID = "\(timestamp.timeIntervalSince1970)|\(usage.signature)"
        let identity = generationID.map { "\($0)|\(sampleID)" } ?? eventID ?? sampleID
        return UsageRecord(
            id: "\(sessionKey)|delta|\(identity)", sessionKey: sessionKey, sessionID: sessionID,
            source: label, projectPath: project, timestamp: timestamp,
            usage: usage, cumulative: nil, isHook: source.isHookLog,
            hasSessionID: explicitSession != nil, paths: [path], generationID: generationID
        )
    }

    private func merge(_ record: UsageRecord) {
        if let scanDay, record.timestamp < scanDay {
            // Old events are not part of today's working set. A cumulative
            // stream needs only its final pre-midnight sample; Claude needs one
            // baseline per generation that may receive another streaming update.
            // Plain historical hook deltas can be discarded immediately.
            let origin = record.isHook ? "hook" : "primary"
            if let counters = record.cumulative {
                let key = "\(record.sessionKey)|\(origin)"
                if let previous = priorCumulative[key],
                   previous.timestamp > record.timestamp
                    || (previous.timestamp == record.timestamp && (previous.cumulative?.total ?? 0) >= counters.total) {
                    return
                }
                priorCumulative[key] = record
            } else if let generation = record.generationID {
                let key = "\(generation)|\(origin)"
                if var previous = priorGenerations[key], let counters = record.usage {
                    previous.usage = previous.usage.map { $0.maximum(counters) } ?? counters
                    previous.timestamp = max(previous.timestamp, record.timestamp)
                    priorGenerations[key] = previous
                } else {
                    priorGenerations[key] = record
                }
            }
            return
        }
        orderingDirty = true
        guard var previous = records[record.id] else {
            records[record.id] = record
            return
        }
        previous.paths.formUnion(record.paths)
        if record.id.hasPrefix("kimi-legacy|"), previous.sessionKey != record.sessionKey {
            // Legacy fork copies have no origin metadata. Keep the global spend
            // once, without pretending we know which session incurred it.
            previous.sessionID = "shared-legacy-history"
            previous.sessionKey = "Kimi|shared-legacy-history"
            previous.projectPath = nil
        } else {
            previous.projectPath = record.projectPath ?? previous.projectPath
        }
        if previous.cumulative == nil, previous.generationID == nil, let usage = record.usage {
            // A hook event with an explicit ID may be reissued with more usage.
            previous.usage = previous.usage.map { $0.maximum(usage) } ?? usage
            previous.timestamp = max(previous.timestamp, record.timestamp)
        }
        previous.isHook = previous.isHook && record.isHook
        records[record.id] = previous
    }

    private func snapshot(startOfDay: Date, now: Date) -> TokenUsageSnapshot {
        // Polling without new records never sorts the day's ledger again.
        if orderingDirty {
            sortedRecords = records.values.sorted {
                if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
                // Repeated reports at one timestamp must advance smaller cumulative
                // counters first, regardless of file discovery order.
                if $0.cumulative?.total != $1.cumulative?.total {
                    return ($0.cumulative?.total ?? 0) < ($1.cumulative?.total ?? 0)
                }
                return $0.id < $1.id
            }
            orderingDirty = false
        }
        let ordered = sortedRecords.filter { $0.timestamp <= now }
        let primary = ordered.filter { !$0.isHook && $0.timestamp >= startOfDay }
        let coveredSessions = Set(primary.map(\.sessionKey))
        let coveredSources = Set(primary.map(\.source))
        var cumulativeBySession: [String: TokenUsage] = [:]
        var cumulativeByGeneration: [String: TokenUsage] = [:]
        func hookIsCovered(_ record: UsageRecord) -> Bool {
            record.isHook && (coveredSessions.contains(record.sessionKey)
                || (!record.hasSessionID && coveredSources.contains(record.source)))
        }
        var baselines: [String: UsageRecord] = [:]
        for record in priorCumulative.values where !hookIsCovered(record) {
            if let previous = baselines[record.sessionKey], previous.timestamp > record.timestamp { continue }
            baselines[record.sessionKey] = record
        }
        for (session, record) in baselines { cumulativeBySession[session] = record.cumulative }
        for record in priorGenerations.values where !hookIsCovered(record) {
            if let generation = record.generationID, let counters = record.usage {
                cumulativeByGeneration[generation] = counters
            }
        }
        var totals = TokenUsageTotals()
        var recentTokens = 0
        var sources: [String: Int] = [:]
        var nativeSources: [String: Int] = [:]
        var perFile: [String: TokenUsageTotals] = [:]
        var perSession: [String: TokenUsageSessionSummary] = [:]

        for record in ordered {
            if hookIsCovered(record) { continue }
            var usage = record.usage ?? .zero
            if let generation = record.generationID, let counters = record.usage {
                let previous = cumulativeByGeneration[generation] ?? .zero
                let current = previous.maximum(counters)
                usage = current.difference(from: previous)
                cumulativeByGeneration[generation] = current
            }
            if let cumulative = record.cumulative {
                if let previous = cumulativeBySession[record.sessionKey] {
                    // Counter resets (e.g. context changes) establish a new
                    // baseline and may report one real last-token delta.
                    usage = cumulative.total < previous.total
                        ? record.usage ?? .zero
                        : cumulative.difference(from: previous)
                }
                // The first cumulative sample can include inherited history.
                // Only its explicit last usage is a proven new generation. An
                // earlier day's sample remains a baseline for today's first hit.
                cumulativeBySession[record.sessionKey] = cumulative
            }
            guard record.timestamp >= startOfDay, usage.total > 0 else { continue }
            totals.add(usage, at: record.timestamp)
            sources[record.source, default: 0] += usage.total
            if !record.isHook { nativeSources[record.source, default: 0] += usage.total }
            if now.timeIntervalSince(record.timestamp) <= 10 * 60 { recentTokens += usage.total }
            for path in record.paths { perFile[path, default: TokenUsageTotals()].add(usage, at: record.timestamp) }
            var session = perSession[record.sessionKey] ?? TokenUsageSessionSummary(
                source: record.source, sessionID: record.sessionID, projectPath: record.projectPath
            )
            session.projectPath = record.projectPath ?? session.projectPath
            session.filePaths.formUnion(record.paths)
            session.totals.add(usage, at: record.timestamp)
            perSession[record.sessionKey] = session
        }
        return TokenUsageSnapshot(
            totalTokens: totals.totalTokens, inputTokens: totals.inputTokens,
            outputTokens: totals.outputTokens, cacheTokens: totals.cacheTokens,
            recentTokens: recentTokens, sourceBreakdown: sources,
            eventCount: totals.eventCount, latestEventAt: totals.latestEventAt, generatedAt: now,
            fileBreakdown: perFile, sessionBreakdown: perSession, nativeSourceBreakdown: nativeSources
        )
    }

    private func nonempty(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }

    private func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        return fractionalDate.date(from: text) ?? plainDate.date(from: text)
    }
}

private struct FileCursor {
    let identity: String
    var offset: UInt64 = 0
    var boundary = Data()
    var modifiedAt: Date?
    var sessionID: String?
    var projectPath: String?
    var createdAt: Date?
    var kimiContext: KimiWireContext?
    var kimiForkReady = false
}

private struct UsageRecord {
    let id: String
    var sessionKey: String
    var sessionID: String
    let source: String
    var projectPath: String?
    var timestamp: Date
    var usage: TokenUsage?
    let cumulative: TokenUsage?
    var isHook: Bool
    let hasSessionID: Bool
    var paths: Set<String>
    var generationID: String? = nil
}

private struct TokenUsage {
    let input: Int
    let output: Int
    let cache: Int
    static let zero = TokenUsage(input: 0, output: 0, cache: 0)
    var total: Int { input + output + cache }
    var signature: String { "\(input),\(output),\(cache)" }

    func maximum(_ other: TokenUsage) -> TokenUsage {
        TokenUsage(input: max(input, other.input), output: max(output, other.output), cache: max(cache, other.cache))
    }

    func difference(from previous: TokenUsage) -> TokenUsage {
        let delta = max(0, total - previous.total)
        let outputDelta = min(delta, max(0, output - previous.output))
        let cacheDelta = min(delta - outputDelta, max(0, cache - previous.cache))
        return TokenUsage(input: delta - outputDelta - cacheDelta, output: outputDelta, cache: cacheDelta)
    }

    static func claude(_ value: [String: Any]) -> TokenUsage {
        TokenUsage(
            input: count(value["input_tokens"]), output: count(value["output_tokens"]),
            cache: count(value["cache_creation_input_tokens"]) + count(value["cache_read_input_tokens"])
        )
    }

    static func codex(_ value: [String: Any]) -> TokenUsage {
        let output = count(value["output_tokens"])
        let total = count(value["total_tokens"])
        let boundedOutput = total > 0 ? min(output, total) : output
        let input = total > 0 ? total - boundedOutput : count(value["input_tokens"])
        let cache = min(input, count(value["cached_input_tokens"]))
        return TokenUsage(input: input - cache, output: boundedOutput, cache: cache)
    }

    static func generic(_ value: [String: Any]) -> TokenUsage {
        if value["cached_input_tokens"] != nil || value["reasoning_output_tokens"] != nil { return codex(value) }
        let input = count(value["input_tokens"] ?? value["inputTokens"])
        let output = count(value["output_tokens"] ?? value["outputTokens"])
        let cache = count(value["cache_creation_input_tokens"]) + count(value["cache_read_input_tokens"])
            + count(value["cacheTokens"])
        if input + output + cache > 0 { return TokenUsage(input: input, output: output, cache: cache) }
        return TokenUsage(input: count(value["total_tokens"] ?? value["totalTokens"]), output: 0, cache: 0)
    }

    static func hasCounters(_ value: [String: Any]) -> Bool {
        ["input_tokens", "output_tokens", "total_tokens", "inputTokens", "outputTokens", "totalTokens"]
            .contains { value[$0] != nil }
    }

    private static func count(_ value: Any?) -> Int {
        if let value = value as? Int { return max(0, value) }
        if let value = value as? String, let number = Int(value) { return max(0, number) }
        return 0
    }
}
