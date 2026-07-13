import Foundation

struct TokenUsageSnapshot: Sendable {
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let recentTokens: Int
    let sourceBreakdown: [String: Int]
    let eventCount: Int
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

    static func scanToday(now: Date = Date()) -> TokenUsageSnapshot {
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        let home = FileManager.default.homeDirectoryForCurrentUser

        var accumulator = TokenUsageAccumulator(generatedAt: now)
        let claudeRoot = home.appendingPathComponent(".claude/projects")
        let codexRoot = home.appendingPathComponent(".codex/sessions")
        let codexArchiveRoot = home.appendingPathComponent(".codex/archived_sessions")

        for file in jsonlFiles(modifiedSince: startOfDay, under: claudeRoot) {
            scanFile(file, source: "Claude", startOfDay: startOfDay, endOfDay: endOfDay, now: now, accumulator: &accumulator)
        }

        for file in codexFiles(for: now, sessionsRoot: codexRoot, archiveRoot: codexArchiveRoot, startOfDay: startOfDay) {
            scanFile(file, source: "Codex", startOfDay: startOfDay, endOfDay: endOfDay, now: now, accumulator: &accumulator)
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

    private static func scanFile(
        _ file: URL,
        source: String,
        startOfDay: Date,
        endOfDay: Date,
        now: Date,
        accumulator: inout TokenUsageAccumulator
    ) {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else {
            return
        }

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard line.contains("\"usage\"") || line.contains("\"token_count\"") else {
                continue
            }

            guard let event = parseLine(line, fallbackSource: source),
                  event.timestamp >= startOfDay,
                  event.timestamp < endOfDay else {
                continue
            }

            accumulator.add(event, now: now)
        }
    }

    private static func parseLine(_ line: String, fallbackSource: String) -> TokenUsageEvent? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let timestamp = parseDate(object["timestamp"]) ?? parseDate(object["created_at"]) ?? Date.distantPast

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

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}

private struct TokenUsageEvent {
    let timestamp: Date
    let source: String
    let usage: TokenUsage
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
            generatedAt: generatedAt
        )
    }
}
