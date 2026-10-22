import CryptoKit
import Foundation

enum KimiWireFormat {
    case current
    case legacy
}

struct KimiWireContext {
    let sessionID: String
    let agentID: String
    let projectPath: String?
    let requiresForkMarker: Bool
    var sessionCreatedAt: Date? = nil
}

struct KimiWireUsage {
    let identity: String
    let timestamp: Date
    let input: Int
    let output: Int
    let cache: Int

    /// Only the official, direct accounting records are accepted. Replay records
    /// and parent SubagentEvent wrappers can contain the same usage again.
    static func parse(_ object: [String: Any], format: KimiWireFormat, context: KimiWireContext) -> KimiWireUsage? {
        let usage: [String: Any]
        let timestamp: Date
        let identity: String
        let input: Int
        let output: Int
        let cache: Int
        switch format {
        case .current:
            guard object["type"] as? String == "usage.record",
                  let counters = object["usage"] as? [String: Any],
                  let time = epoch(object["time"], divisor: 1_000),
                  object["agentId"] == nil || object["agentId"] as? String == context.agentID else { return nil }
            usage = counters
            timestamp = time
            input = count(usage["inputOther"])
            output = count(usage["output"])
            cache = count(usage["inputCacheRead"]) + count(usage["inputCacheCreation"])
            // Native wire has no request ID. Timestamp + model + counters is a
            // replay fingerprint; two identical calls in the same millisecond
            // cannot be distinguished. Session/agent identity separates peers.
            identity = "kimi-current|\(context.sessionID)|\(context.agentID)|\(time.timeIntervalSince1970)|\(object["model"] as? String ?? "")|\(input),\(output),\(cache)"
        case .legacy:
            guard let message = object["message"] as? [String: Any],
                  message["type"] as? String == "StatusUpdate",
                  let payload = message["payload"] as? [String: Any],
                  let counters = payload["token_usage"] as? [String: Any],
                  let time = epoch(object["timestamp"], divisor: 1) else { return nil }
            usage = counters
            timestamp = time
            input = count(usage["input_other"])
            output = count(usage["output"])
            cache = count(usage["input_cache_read"]) + count(usage["input_cache_creation"])
            // Legacy forks copy wire history without a fork marker. Provider
            // message IDs survive the copy, so deduplicate across sessions.
            // Older records without IDs use a timestamp/counter fingerprint;
            // identical simultaneous calls are indistinguishable in that format.
            let messageID = nonempty(payload["message_id"])
            identity = "kimi-legacy|" + (messageID ?? "\(time.timeIntervalSince1970)|\(input),\(output),\(cache)")
        }
        guard input + output + cache > 0 else { return nil }
        return KimiWireUsage(identity: identity, timestamp: timestamp, input: input, output: output, cache: cache)
    }

    static func context(for file: URL, root: URL, format: KimiWireFormat) -> KimiWireContext? {
        let prefix = root.standardizedFileURL.path + "/"
        let path = file.standardizedFileURL.path
        guard path.hasPrefix(prefix) else { return nil }
        let parts = path.dropFirst(prefix.count).split(separator: "/").map(String.init)
        guard parts.last == "wire.jsonl" else { return nil }
        switch format {
        case .current:
            guard parts.count == 5, parts[2] == "agents" else { return nil }
            let sessionRoot = root.appendingPathComponent(parts[0]).appendingPathComponent(parts[1])
            // Session fork writes state.json only after all copied wire records
            // and fork markers are complete. Do not consume a half-copied fork.
            guard let state = json(at: sessionRoot.appendingPathComponent("state.json")),
                  nonempty(state["id"]) == parts[1] else { return nil }
            return KimiWireContext(sessionID: parts[1], agentID: parts[3],
                                   projectPath: nonempty(state["cwd"]),
                                   requiresForkMarker: nonempty(state["forkedFrom"]) != nil,
                                   sessionCreatedAt: epoch(state["createdAt"], divisor: 1_000))
        case .legacy:
            guard parts.count == 3 || (parts.count == 5 && parts[2] == "subagents") else { return nil }
            let metadata = json(at: root.deletingLastPathComponent().appendingPathComponent("kimi.json"))
            let workDirs = metadata?["work_dirs"] as? [[String: Any]] ?? []
            let project = workDirs.first { entry in
                guard let path = nonempty(entry["path"]), (entry["kaos"] as? String ?? "local") == "local" else { return false }
                let hash = Insecure.MD5.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
                return hash == parts[0]
            }.flatMap { nonempty($0["path"]) }
            return KimiWireContext(sessionID: parts[1], agentID: parts.count == 3 ? "main" : parts[3],
                                   projectPath: project, requiresForkMarker: false)
        }
    }

    /// A child spawned after a session fork has a fresh wire, not a copied one,
    /// and therefore no fork marker. Its own metadata proves that distinction.
    static func isNewAgentMetadata(_ object: [String: Any], context: KimiWireContext) -> Bool {
        guard context.agentID != "main", object["type"] as? String == "metadata",
              let sessionCreatedAt = context.sessionCreatedAt,
              let wireCreatedAt = epoch(object["created_at"], divisor: 1_000) else { return false }
        return wireCreatedAt >= sessionCreatedAt
    }

    private static func json(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func epoch(_ value: Any?, divisor: Double) -> Date? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue > 0 else { return nil }
        return Date(timeIntervalSince1970: number.doubleValue / divisor)
    }

    private static func count(_ value: Any?) -> Int {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return 0 }
        // Reject nonintegral/invalid counters and keep malformed data from
        // overflowing when the four disjoint fields are added.
        let count = number.doubleValue
        guard count.isFinite, count >= 0, count.rounded(.down) == count, count < Double(Int.max / 8) else { return 0 }
        return Int(count)
    }

    private static func nonempty(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }
}

enum KimiUsageAvailability: Equatable {
    case waiting
    case reading

    init(snapshot: TokenUsageSnapshot?, now: Date = Date(), calendar: Calendar = .current) {
        guard let snapshot, calendar.isDate(snapshot.generatedAt, inSameDayAs: now),
              snapshot.nativeSourceBreakdown["Kimi", default: 0] > 0 else {
            self = .waiting
            return
        }
        self = .reading
    }
}
