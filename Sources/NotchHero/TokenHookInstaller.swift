import Foundation

enum CodingToolHook: String, CaseIterable {
    case claude
    case codex
    case opencode

    var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .opencode: "OpenCode"
        }
    }

    var sourceArgument: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .opencode: "opencode"
        }
    }
}

struct TokenHookInstallState {
    let isInstalled: Bool
    let detail: String
}

enum TokenHookInstaller {
    private static let marker = "vibe-hero-token-hook"

    private static var manager: FileManager {
        FileManager.default
    }

    private static var home: URL {
        manager.homeDirectoryForCurrentUser
    }

    private static var hookRoot: URL {
        home.appendingPathComponent(".vibe-hero").appendingPathComponent("hooks")
    }

    private static var hookScript: URL {
        hookRoot.appendingPathComponent(marker)
    }

    private static var hookCommand: String {
        "\"$HOME/.vibe-hero/hooks/\(marker)\""
    }

    static func install(_ tool: CodingToolHook) throws {
        try installSharedHookScript()

        switch tool {
        case .claude:
            try installClaudeHook()
        case .codex:
            try installCodexHook()
        case .opencode:
            try installOpenCodeHook()
        }
    }

    static func state(for tool: CodingToolHook) -> TokenHookInstallState {
        switch tool {
        case .claude:
            let settingsURL = home.appendingPathComponent(".claude/settings.json")
            let installed = jsonFile(settingsURL, contains: marker)
            return TokenHookInstallState(
                isInstalled: installed,
                detail: installed ? L10n.text(.hookInstalledDetail) : L10n.text(.hookClaudeDetail)
            )
        case .codex:
            let hooksURL = home.appendingPathComponent(".codex/hooks.json")
            let installed = jsonFile(hooksURL, contains: marker)
            return TokenHookInstallState(
                isInstalled: installed,
                detail: installed ? L10n.text(.hookInstalledDetail) : L10n.text(.hookCodexDetail)
            )
        case .opencode:
            let pluginURL = home.appendingPathComponent(".config/opencode/plugins/vibe-hero-token.js")
            let configURL = home.appendingPathComponent(".config/opencode/config.json")
            let installed = manager.fileExists(atPath: pluginURL.path) && jsonFile(configURL, contains: "vibe-hero-token.js")
            return TokenHookInstallState(
                isInstalled: installed,
                detail: installed ? L10n.text(.hookInstalledDetail) : L10n.text(.hookOpenCodeDetail)
            )
        }
    }

    private static func installSharedHookScript() throws {
        try manager.createDirectory(at: hookRoot, withIntermediateDirectories: true)
        let script = """
        #!/bin/sh
        # vibe-hero-token-hook
        # Appends coding-tool hook payloads for Vibe Hero token scanning.
        SOURCE="${1:-hook}"
        ROOT="$HOME/.vibe-hero"
        LOG="$ROOT/token-events.jsonl"
        mkdir -p "$ROOT" || exit 0
        PAYLOAD="$(cat)"
        TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        if [ -z "$PAYLOAD" ]; then
          printf '{"timestamp":"%s","source":"%s","payload":{}}\\n' "$TS" "$SOURCE" >> "$LOG"
        else
          printf '{"timestamp":"%s","source":"%s","payload":%s}\\n' "$TS" "$SOURCE" "$PAYLOAD" >> "$LOG"
        fi
        exit 0
        """

        try script.write(to: hookScript, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScript.path)
    }

    private static func installClaudeHook() throws {
        let settingsURL = home.appendingPathComponent(".claude/settings.json")
        var root = try mutableJSONFile(at: settingsURL)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = "\(hookCommand) claude"

        addCommandHook(event: "PostToolUse", matcher: "*", command: command, timeout: 5, hooks: &hooks)
        addCommandHook(event: "Stop", matcher: nil, command: command, timeout: 5, hooks: &hooks)
        addCommandHook(event: "SessionEnd", matcher: nil, command: command, timeout: 5, hooks: &hooks)

        root["hooks"] = hooks
        try writeJSON(root, to: settingsURL)
    }

    private static func installCodexHook() throws {
        let hooksURL = home.appendingPathComponent(".codex/hooks.json")
        var root = try mutableJSONFile(at: hooksURL)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = "\(hookCommand) codex"

        addCommandHook(event: "UserPromptSubmit", matcher: nil, command: command, timeout: 5, hooks: &hooks)
        addCommandHook(event: "PostToolUse", matcher: "", command: command, timeout: 5, hooks: &hooks)
        addCommandHook(event: "Stop", matcher: nil, command: command, timeout: 5, hooks: &hooks)
        addCommandHook(event: "SessionStart", matcher: nil, command: command, timeout: 5, hooks: &hooks)

        root["hooks"] = hooks
        try writeJSON(root, to: hooksURL)
        try enableCodexHooksFeature()
    }

    private static func installOpenCodeHook() throws {
        let configRoot = home.appendingPathComponent(".config/opencode")
        let pluginRoot = configRoot.appendingPathComponent("plugins")
        let pluginURL = pluginRoot.appendingPathComponent("vibe-hero-token.js")
        let configURL = configRoot.appendingPathComponent("config.json")

        try manager.createDirectory(at: pluginRoot, withIntermediateDirectories: true)
        try openCodePluginSource.write(to: pluginURL, atomically: true, encoding: .utf8)

        var root = try mutableJSONFile(at: configURL)
        let pluginPath = pluginURL.absoluteString
        var plugins = root["plugin"] as? [String] ?? []
        if !plugins.contains(pluginPath) {
            plugins.append(pluginPath)
        }
        root["plugin"] = plugins
        try writeJSON(root, to: configURL)
    }

    private static func addCommandHook(
        event: String,
        matcher: String?,
        command: String,
        timeout: Int,
        hooks: inout [String: Any]
    ) {
        var entries = hooks[event] as? [[String: Any]] ?? []
        let alreadyInstalled = entries.contains { entry in
            guard let hookItems = entry["hooks"] as? [[String: Any]] else {
                return false
            }
            return hookItems.contains { ($0["command"] as? String)?.contains(marker) == true }
        }
        guard !alreadyInstalled else {
            return
        }

        var entry: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": command,
                "timeout": timeout
            ]]
        ]
        if let matcher {
            entry["matcher"] = matcher
        }
        entries.append(entry)
        hooks[event] = entries
    }

    private static func mutableJSONFile(at url: URL) throws -> [String: Any] {
        guard manager.fileExists(atPath: url.path) else {
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            return [:]
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private static func writeJSON(_ object: [String: Any], to url: URL) throws {
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private static func enableCodexHooksFeature() throws {
        let configURL = home.appendingPathComponent(".codex/config.toml")
        var content = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""

        if content.contains("codex_hooks = true") {
            return
        }

        if content.contains("codex_hooks = false") {
            content = content.replacingOccurrences(of: "codex_hooks = false", with: "codex_hooks = true")
        } else if let range = content.range(of: "[features]") {
            let insertIndex = content[range.upperBound...].firstIndex(of: "\n") ?? content.endIndex
            content.insert(contentsOf: "\ncodex_hooks = true", at: insertIndex)
        } else {
            if !content.isEmpty && !content.hasSuffix("\n") {
                content.append("\n")
            }
            content.append("\n[features]\ncodex_hooks = true\n")
        }

        try manager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private static func jsonFile(_ url: URL, contains needle: String) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }
        return content.contains(needle)
    }

    private static let openCodePluginSource = """
    // vibe-hero-token-plugin
    import { appendFileSync, mkdirSync } from "fs";
    import { homedir } from "os";
    import { join } from "path";

    const root = join(homedir(), ".vibe-hero");
    const logFile = join(root, "token-events.jsonl");

    function append(event) {
      try {
        mkdirSync(root, { recursive: true });
        appendFileSync(logFile, JSON.stringify({
          timestamp: new Date().toISOString(),
          source: "opencode",
          payload: event || {}
        }) + "\\n");
      } catch {}
    }

    export default async () => ({
      "event": async ({ event }) => {
        const type = event?.type || "";
        if (
          type === "message.updated" ||
          type === "message.part.updated" ||
          type === "session.status" ||
          type.includes("usage") ||
          type.includes("token")
        ) {
          append(event);
        }
      }
    });
    """
}
