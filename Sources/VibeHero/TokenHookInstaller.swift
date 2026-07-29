import Foundation

enum CodingToolHook: String, CaseIterable {
    case claude
    case codex
    case opencode
    case kimi
    case openclaw
    case hermes

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

    var sourceArgument: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .opencode: "opencode"
        case .kimi: "kimi"
        case .openclaw: "openclaw"
        case .hermes: "hermes"
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
        case .kimi:
            try installKimiHook()
        case .openclaw:
            try installOpenClawHook()
        case .hermes:
            try installHermesHook()
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
        case .kimi:
            let configURL = home.appendingPathComponent(".kimi-code/config.toml")
            let mcpURL = home.appendingPathComponent(".vibe-hero/mcp/kimi-token-server.js")
            let installed = manager.fileExists(atPath: mcpURL.path) && tomlFile(configURL, contains: "kimi-token-server")
            return TokenHookInstallState(
                isInstalled: installed,
                detail: installed ? L10n.text(.hookInstalledDetail) : L10n.text(.hookKimiDetail)
            )
        case .openclaw:
            let hooksURL = home.appendingPathComponent(".openclaw/hooks/vibe-hero-token.sh")
            let installed = manager.fileExists(atPath: hooksURL.path)
            return TokenHookInstallState(
                isInstalled: installed,
                detail: installed ? L10n.text(.hookInstalledDetail) : "Adds a hook script to ~/.openclaw/hooks."
            )
        case .hermes:
            let hooksURL = home.appendingPathComponent(".hermes/hooks/vibe-hero-token.sh")
            let installed = manager.fileExists(atPath: hooksURL.path)
            return TokenHookInstallState(
                isInstalled: installed,
                detail: installed ? L10n.text(.hookInstalledDetail) : "Adds a hook script to ~/.hermes/hooks."
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

    private static func installOpenClawHook() throws {
        let hooksRoot = home.appendingPathComponent(".openclaw/hooks")
        let hookURL = hooksRoot.appendingPathComponent("vibe-hero-token.sh")
        
        try manager.createDirectory(at: hooksRoot, withIntermediateDirectories: true)
        
        let script = """
        #!/bin/sh
        # Vibe Hero Token Hook for OpenClaw
        "\(hookCommand)" openclaw
        """
        
        try script.write(to: hookURL, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookURL.path)
    }
    
    private static func installHermesHook() throws {
        let hooksRoot = home.appendingPathComponent(".hermes/hooks")
        let hookURL = hooksRoot.appendingPathComponent("vibe-hero-token.sh")
        
        try manager.createDirectory(at: hooksRoot, withIntermediateDirectories: true)
        
        let script = """
        #!/bin/sh
        # Vibe Hero Token Hook for Hermes
        "\(hookCommand)" hermes
        """
        
        try script.write(to: hookURL, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookURL.path)
    }
    
    private static func installKimiHook() throws {
        // Kimi Code uses MCP (Model Context Protocol). We install an MCP server
        // that intercepts LLM responses and logs token usage.
        let mcpRoot = home.appendingPathComponent(".vibe-hero/mcp")
        let serverURL = mcpRoot.appendingPathComponent("kimi-token-server.js")
        let configURL = home.appendingPathComponent(".kimi-code/config.toml")

        try manager.createDirectory(at: mcpRoot, withIntermediateDirectories: true)
        try kimiMCPSource.write(to: serverURL, atomically: true, encoding: .utf8)

        // Make the script executable
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: serverURL.path)

        // Update Kimi Code config to use our MCP server
        var content = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""

        // Check if already configured
        if content.contains("kimi-token-server") {
            return
        }

        // Add MCP server configuration
        let mcpConfig = """

# Vibe Hero Token Tracking MCP Server
[mcp.servers.kimi-token-server]
command = "node"
args = ["\(serverURL.path)"]
"""
        content.append(mcpConfig)
        try content.write(to: configURL, atomically: true, encoding: .utf8)
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

    private static func tomlFile(_ url: URL, contains needle: String) -> Bool {
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

    private static let kimiMCPSource = """
    #!/usr/bin/env node
    // Vibe Hero Token MCP Server for Kimi Code
    // Intercepts LLM responses and logs token usage to ~/.vibe-hero/token-events.jsonl

    const { appendFileSync, mkdirSync } = require("fs");
    const { join } = require("path");
    const { homedir } = require("os");

    const root = join(homedir(), ".vibe-hero");
    const logFile = join(root, "token-events.jsonl");

    function logEvent(event) {
      try {
        mkdirSync(root, { recursive: true });
        const entry = {
          timestamp: new Date().toISOString(),
          source: "kimi",
          payload: event
        };
        appendFileSync(logFile, JSON.stringify(entry) + "\\n");
      } catch (e) {
        // Silent fail - don't disrupt the user's workflow
      }
    }

    function logTokenUsage(usage) {
      if (!usage || typeof usage !== "object") return;
      logEvent({
        type: "token_count",
        info: {
          last_token_usage: {
            input_tokens: usage.input_tokens || 0,
            output_tokens: usage.output_tokens || 0,
            total_tokens: usage.total_tokens || 0
          }
        }
      });
    }

    // MCP Protocol handlers
    const handlers = {
      initialize: () => ({
        protocolVersion: "2024-11-05",
        capabilities: {},
        serverInfo: { name: "kimi-token-server", version: "1.0.0" }
      }),

      tools/list: () => ({
        tools: []
      }),

      tools/call: () => ({
        content: []
      }),

      // Intercept LLM responses to extract token usage
      "prompts/execute": (params) => {
        const result = params.result;
        if (result?.usage) {
          logTokenUsage(result.usage);
        }
        return null;
      }
    };

    // Read JSON-RPC messages from stdin
    let buffer = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      buffer += chunk;
      while (true) {
        const contentLengthMatch = buffer.match(/Content-Length: (\\d+)\\r\\n/);
        if (!contentLengthMatch) break;
        const contentLength = parseInt(contentLengthMatch[1], 10);
        const headerEnd = buffer.indexOf("\\r\\n\\r\\n");
        if (headerEnd === -1) break;
        const messageStart = headerEnd + 4;
        if (buffer.length < messageStart + contentLength) break;
        const message = buffer.slice(messageStart, messageStart + contentLength);
        buffer = buffer.slice(messageStart + contentLength);
        try {
          const request = JSON.parse(message);
          const handler = handlers[request.method];
          if (handler) {
            const response = {
              jsonrpc: "2.0",
              id: request.id,
              result: handler(request.params || {})
            };
            const responseStr = JSON.stringify(response);
            process.stdout.write(`Content-Length: ${responseStr.length}\\r\\n\\r\\n${responseStr}`);
          }
        } catch (e) {
          // Invalid JSON, ignore
        }
      }
    });

    process.stdin.on("end", () => {
      process.exit(0);
    });
    """
}
