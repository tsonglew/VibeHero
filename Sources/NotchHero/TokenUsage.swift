import Foundation

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

    var hasRealData: Bool {
        eventCount > 0
    }

    var dominantSource: String {
        sourceBreakdown.max { $0.value < $1.value }?.key ?? "No source"
    }
}

enum TokenUsageScanner {
    private static let calendar = Calendar.current
    fileprivate static let recentWindow: TimeInterval = 10 * 60

    // Incremental scan state. Files are append-only JSONL logs, so after the first
    // full read we only tail bytes appended since the previous scan and keep the
    // day's parsed events in memory. All access is serialized by the lock.
    private final class ScanState: @unchecked Sendable {
        let lock = NSLock()
        var scanDay: Date?
        var todayEvents: [TokenUsageEvent] = []
        var fileCursors: [String: UInt64] = [:]

        // Formatter creation goes through ICU and is expensive; reuse shared
        // instances. Safe because all use happens under the lock.
        let fractionalISO8601Formatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        let plainISO8601Formatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()
    }

    private static let state = ScanState()

    static func scanToday(now: Date = Date()) -> TokenUsageSnapshot {
        state.lock.lock()
        defer { state.lock.unlock() }

        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        if state.scanDay != startOfDay {
            state.scanDay = startOfDay
            state.todayEvents = []
            state.fileCursors = [:]
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeRoot = home.appendingPathComponent(".claude/projects")
        let codexRoot = home.appendingPathComponent(".codex/sessions")
        let codexArchiveRoot = home.appendingPathComponent(".codex/archived_sessions")
        let hookLog = home
            .appendingPathComponent(".vibe-hero")
            .appendingPathComponent("token-events.jsonl")

        for file in jsonlFiles(modifiedSince: startOfDay, under: claudeRoot) {
            ingestFile(file, source: "Claude", isHook: false, startOfDay: startOfDay, endOfDay: endOfDay)
        }

        for file in codexFiles(for: now, sessionsRoot: codexRoot, archiveRoot: codexArchiveRoot, startOfDay: startOfDay) {
            ingestFile(file, source: "Codex", isHook: false, startOfDay: startOfDay, endOfDay: endOfDay)
        }

        ingestFile(hookLog, source: "Hook", isHook: true, startOfDay: startOfDay, endOfDay: endOfDay)

        // Primary Claude/Codex logs win over the hook fallback: hook events whose
        // source already has real primary-log events today are skipped, matching
        // the previous full-rescan behavior (including its self-correction when a
        // lagging primary log catches up).
        var coveredSources = Set<String>()
        for event in state.todayEvents where !event.isHook && event.usage.total > 0 {
            coveredSources.insert(event.source)
        }

        var accumulator = TokenUsageAccumulator(generatedAt: now)
        for event in state.todayEvents {
            if event.isHook, coveredSources.contains(event.source) {
                continue
            }
            accumulator.add(event, now: now)
        }
        return accumulator.snapshot
    }

    private static func codexFiles(
        for now: Date,
        sessionsRoot: URL,
        archiveRoot: URL,
        startOfDay: Date
    ) -> [URL] {
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let dayRoot = sessionsRoot
            .appendingPathComponent(String(format: "%04d", components.year ?? 0))
            .appendingPathComponent(String(format: "%02d", components.month ?? 0))
            .appendingPathComponent(String(format: "%02d", components.day ?? 0))

        var files = jsonlFiles(modifiedSince: nil, under: dayRoot)
        files.append(contentsOf: jsonlFiles(modifiedSince: startOfDay, under: archiveRoot))
        return files
    }

    private static func jsonlFiles(modifiedSince: Date?, under root: URL) -> [URL] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: root.path) else {
            return []
        }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else {
            return []
        }

        var result: [URL] = []
        for case let file as URL in enumerator {
            guard file.pathExtension == "jsonl" else {
                continue
            }

            guard let values = try? file.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }

            if let modifiedSince,
               let modifiedAt = values.contentModificationDate,
               modifiedAt < modifiedSince {
                continue
            }

            result.append(file)
        }
        return result
    }

    private static func ingestFile(
        _ file: URL,
        source: String,
        isHook: Bool,
        startOfDay: Date,
        endOfDay: Date
    ) {
        let path = file.path
        guard let handle = try? FileHandle(forReadingFrom: file) else {
            return
        }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd() else {
            return
        }

        var offset = state.fileCursors[path] ?? 0
        if offset > size {
            // Truncated or rotated: drop previously ingested lines from this file
            // and re-read it from the start.
            offset = 0
            state.todayEvents.removeAll { $0.path == path }
        }

        do {
            try handle.seek(toOffset: offset)
        } catch {
            return
        }

        guard let data = try? handle.readToEnd(), !data.isEmpty else {
            state.fileCursors[path] = offset
            return
        }

        // Consume only up to the last complete line; a writer may be mid-line.
        var consumed = data.count
        if data.last != 0x0A {
            guard let lastNewline = data.lastIndex(of: 0x0A) else {
                state.fileCursors[path] = offset
                return
            }
            consumed = data.index(after: lastNewline)
        }
        state.fileCursors[path] = offset + UInt64(consumed)

        guard let text = String(data: data.prefix(consumed), encoding: .utf8) else {
            return
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard line.contains("\"usage\"") ||
                    line.contains("\"token_count\"") ||
                    line.contains("\"payload\"") ||
                    line.contains("\"total_tokens\"") ||
                    line.contains("\"input_tokens\"") else {
                continue
            }

            guard var event = parseLine(line, fallbackSource: source),
                  event.timestamp >= startOfDay,
                  event.timestamp < endOfDay else {
                continue
            }

            event.isHook = isHook
            event.path = path
            state.todayEvents.append(event)
        }
    }

    private static func parseLine(_ line: String, fallbackSource: String) -> TokenUsageEvent? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let timestamp = parseDate(object["timestamp"]) ?? parseDate(object["created_at"]) ?? Date.distantPast
        let source = normalizedSource(object["source"] as? String) ?? fallbackSource

        if let payload = object["payload"] as? [String: Any],
           let usage = bestUsage(in: payload) {
            return TokenUsageEvent(timestamp: timestamp, source: source, usage: usage)
        }

        if fallbackSource == "Codex",
           let payload = object["payload"] as? [String: Any],
           payload["type"] as? String == "token_count",
           let info = payload["info"] as? [String: Any],
           let usage = info["last_token_usage"] as? [String: Any] {
            return TokenUsageEvent(timestamp: timestamp, source: "Codex", usage: usageFromCodex(usage))
        }

        if let message = object["message"] as? [String: Any],
           let usage = message["usage"] as? [String: Any] {
            return TokenUsageEvent(timestamp: timestamp, source: "Claude", usage: usageFromClaude(usage))
        }

        if let usage = object["usage"] as? [String: Any] {
            return TokenUsageEvent(timestamp: timestamp, source: fallbackSource, usage: usageFromClaude(usage))
        }

        if let usage = bestUsage(in: object) {
            return TokenUsageEvent(timestamp: timestamp, source: source, usage: usage)
        }

        return nil
    }

    private static func usageFromClaude(_ usage: [String: Any]) -> TokenUsage {
        let input = intValue(usage["input_tokens"])
        let output = intValue(usage["output_tokens"])
        let cache = intValue(usage["cache_creation_input_tokens"]) + intValue(usage["cache_read_input_tokens"])
        return TokenUsage(input: input, output: output, cache: cache)
    }

    private static func usageFromCodex(_ usage: [String: Any]) -> TokenUsage {
        let total = intValue(usage["total_tokens"])
        let input = intValue(usage["input_tokens"])
        let output = intValue(usage["output_tokens"]) + intValue(usage["reasoning_output_tokens"])
        let cache = intValue(usage["cached_input_tokens"])

        if total > 0 {
            return TokenUsage(input: max(0, total - output), output: output, cache: cache)
        }

        return TokenUsage(input: input, output: output, cache: cache)
    }

    private static func bestUsage(in object: Any) -> TokenUsage? {
        var candidates: [TokenUsage] = []
        collectUsage(in: object, into: &candidates)
        return candidates.max { $0.total < $1.total }
    }

    private static func collectUsage(in object: Any, into candidates: inout [TokenUsage]) {
        if let dictionary = object as? [String: Any] {
            let usage = usageFromGeneric(dictionary)
            if usage.total > 0 {
                candidates.append(usage)
            }

            for value in dictionary.values {
                collectUsage(in: value, into: &candidates)
            }
            return
        }

        if let array = object as? [Any] {
            for value in array {
                collectUsage(in: value, into: &candidates)
            }
        }
    }

    private static func usageFromGeneric(_ usage: [String: Any]) -> TokenUsage {
        let input = intValue(usage["input_tokens"]) + intValue(usage["inputTokens"])
        let output = intValue(usage["output_tokens"]) +
            intValue(usage["outputTokens"]) +
            intValue(usage["reasoning_output_tokens"])
        let cache = intValue(usage["cache_creation_input_tokens"]) +
            intValue(usage["cache_read_input_tokens"]) +
            intValue(usage["cached_input_tokens"]) +
            intValue(usage["cacheTokens"])
        let explicitTotal = intValue(usage["total_tokens"]) + intValue(usage["totalTokens"])

        if input + output + cache > 0 {
            return TokenUsage(input: input, output: output, cache: cache)
        }

        if explicitTotal > 0 {
            return TokenUsage(input: explicitTotal, output: 0, cache: 0)
        }

        return TokenUsage(input: 0, output: 0, cache: 0)
    }

    private static func normalizedSource(_ rawSource: String?) -> String? {
        guard let rawSource else {
            return nil
        }

        switch rawSource.lowercased() {
        case "claude", "claude code", "claudecode":
            return "Claude"
        case "codex":
            return "Codex"
        case "opencode", "open code":
            return "OpenCode"
        default:
            return rawSource
        }
    }

    private static func intValue(_ value: Any?) -> Int {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string) ?? 0
        }
        return 0
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let raw = value as? String else {
            return nil
        }

        if let date = state.fractionalISO8601Formatter.date(from: raw) {
            return date
        }

        return state.plainISO8601Formatter.date(from: raw)
    }
}

private struct TokenUsageEvent {
    let timestamp: Date
    let source: String
    let usage: TokenUsage
    var isHook = false
    var path = ""
}

private struct TokenUsage {
    let input: Int
    let output: Int
    let cache: Int

    var total: Int {
        input + output + cache
    }
}

private struct TokenUsageAccumulator {
    var inputTokens = 0
    var outputTokens = 0
    var cacheTokens = 0
    var recentTokens = 0
    var sourceBreakdown: [String: Int] = [:]
    var eventCount = 0
    var latestEventAt: Date?
    let generatedAt: Date

    mutating func add(_ event: TokenUsageEvent, now: Date) {
        let total = event.usage.total
        guard total > 0 else {
            return
        }

        inputTokens += event.usage.input
        outputTokens += event.usage.output
        cacheTokens += event.usage.cache
        sourceBreakdown[event.source, default: 0] += total
        eventCount += 1
        if latestEventAt.map({ event.timestamp > $0 }) ?? true {
            latestEventAt = event.timestamp
        }

        if now.timeIntervalSince(event.timestamp) <= TokenUsageScanner.recentWindow {
            recentTokens += total
        }
    }

    var snapshot: TokenUsageSnapshot {
        TokenUsageSnapshot(
            totalTokens: inputTokens + outputTokens + cacheTokens,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheTokens: cacheTokens,
            recentTokens: recentTokens,
            sourceBreakdown: sourceBreakdown,
            eventCount: eventCount,
            latestEventAt: latestEventAt,
            generatedAt: generatedAt
        )
    }
}
