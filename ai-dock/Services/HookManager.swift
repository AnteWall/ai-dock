import Foundation

enum HookInstallStatus: Sendable {
    case installed
    case notInstalled
    case outdated
    case error(String)
}

nonisolated struct HookManager: Sendable {
    private static let hookScriptPath = "~/.claude/hooks/claude-island-state.py"
    private static let settingsPath = "~/.claude/settings.json"

    private static let hookCommand = "python3 ~/.claude/hooks/claude-island-state.py"

    /// All hook events we register for, with their matcher configurations.
    private static let hookEvents: [(event: String, matchers: [String?])] = [
        ("UserPromptSubmit", [nil]),
        ("PreToolUse", ["*"]),
        ("PostToolUse", ["*"]),
        ("PermissionRequest", ["*"]),
        ("Stop", [nil]),
        ("SubagentStop", [nil]),
        ("Notification", ["*"]),
        ("SessionStart", [nil]),
        ("SessionEnd", [nil]),
        ("PreCompact", ["auto", "manual"]),
    ]

    func checkStatus() -> HookInstallStatus {
        let settingsURL = resolvedURL(Self.settingsPath)
        let scriptURL = resolvedURL(Self.hookScriptPath)

        // Check hook script exists
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            return .notInstalled
        }

        // Check settings.json has our hooks
        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return .notInstalled
        }

        // Verify all expected events are present
        for (event, _) in Self.hookEvents {
            guard let eventHooks = hooks[event] as? [[String: Any]] else {
                return .notInstalled
            }
            let hasOurHook = eventHooks.contains { entry in
                guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { hook in
                    (hook["command"] as? String) == Self.hookCommand
                }
            }
            if !hasOurHook {
                return .notInstalled
            }
        }

        return .installed
    }

    func install() throws {
        // Ensure hooks directory exists
        let hooksDir = resolvedURL("~/.claude/hooks")
        try FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

        // Write hook script
        let scriptURL = resolvedURL(Self.hookScriptPath)
        try hookScriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        // Update settings.json
        try updateSettings { json in
            var hooks = json["hooks"] as? [String: Any] ?? [:]

            for (event, matchers) in Self.hookEvents {
                var eventEntries = hooks[event] as? [[String: Any]] ?? []

                // Remove any existing entries with our command
                eventEntries.removeAll { entry in
                    guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                    return hookList.contains { ($0["command"] as? String) == Self.hookCommand }
                }

                // Add our entries
                for matcher in matchers {
                    var hookDef: [String: Any] = [
                        "command": Self.hookCommand,
                        "type": "command",
                    ]
                    // PermissionRequest needs a long timeout for user decisions
                    if event == "PermissionRequest" {
                        hookDef["timeout"] = 86400
                    }

                    var entry: [String: Any] = ["hooks": [hookDef]]
                    if let m = matcher {
                        entry["matcher"] = m
                    }
                    eventEntries.append(entry)
                }

                hooks[event] = eventEntries
            }

            json["hooks"] = hooks
        }
    }

    func uninstall() throws {
        try updateSettings { json in
            guard var hooks = json["hooks"] as? [String: Any] else { return }

            for event in hooks.keys {
                guard var entries = hooks[event] as? [[String: Any]] else { continue }
                entries.removeAll { entry in
                    guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                    return hookList.contains { ($0["command"] as? String) == Self.hookCommand }
                }
                if entries.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = entries
                }
            }

            if hooks.isEmpty {
                json.removeValue(forKey: "hooks")
            } else {
                json["hooks"] = hooks
            }
        }
    }

    // MARK: - Private

    private func updateSettings(_ transform: (inout [String: Any]) throws -> Void) throws {
        let url = resolvedURL(Self.settingsPath)
        var json: [String: Any] = [:]

        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        try transform(&json)

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func resolvedURL(_ tilded: String) -> URL {
        let expanded = NSString(string: tilded).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    // MARK: - Embedded Hook Script

    private var hookScriptContent: String {
        """
        #!/usr/bin/env python3
        \"\"\"
        Claude Dock Hook
        - Sends session state to Claude Dock app via Unix socket
        - For PermissionRequest: waits for user decision from the app
        \"\"\"
        import json
        import os
        import socket
        import sys

        SOCKET_PATH = "/tmp/claude-island.sock"
        TIMEOUT_SECONDS = 300  # 5 minutes for permission decisions


        def get_tty():
            \"\"\"Get the TTY of the Claude process (parent)\"\"\"
            import subprocess

            # Get parent PID (Claude process)
            ppid = os.getppid()

            # Try to get TTY from ps command for the parent process
            try:
                result = subprocess.run(
                    ["ps", "-p", str(ppid), "-o", "tty="],
                    capture_output=True,
                    text=True,
                    timeout=2
                )
                tty = result.stdout.strip()
                if tty and tty != "??" and tty != "-":
                    # ps returns just "ttys001", we need "/dev/ttys001"
                    if not tty.startswith("/dev/"):
                        tty = "/dev/" + tty
                    return tty
            except Exception:
                pass

            # Fallback: try current process stdin/stdout
            try:
                return os.ttyname(sys.stdin.fileno())
            except (OSError, AttributeError):
                pass
            try:
                return os.ttyname(sys.stdout.fileno())
            except (OSError, AttributeError):
                pass
            return None


        def send_event(state):
            \"\"\"Send event to app, return response if any\"\"\"
            try:
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                sock.settimeout(TIMEOUT_SECONDS)
                sock.connect(SOCKET_PATH)
                sock.sendall(json.dumps(state).encode())

                # For permission requests, wait for response
                if state.get("status") == "waiting_for_approval":
                    response = sock.recv(4096)
                    sock.close()
                    if response:
                        return json.loads(response.decode())
                else:
                    sock.close()

                return None
            except (socket.error, OSError, json.JSONDecodeError):
                return None


        def main():
            try:
                data = json.load(sys.stdin)
            except json.JSONDecodeError:
                sys.exit(1)

            session_id = data.get("session_id", "unknown")
            event = data.get("hook_event_name", "")
            cwd = data.get("cwd", "")
            tool_input = data.get("tool_input", {})

            # Get process info
            claude_pid = os.getppid()
            tty = get_tty()

            # Build state object
            state = {
                "session_id": session_id,
                "cwd": cwd,
                "event": event,
                "pid": claude_pid,
                "tty": tty,
            }

            # Map events to status
            if event == "UserPromptSubmit":
                state["status"] = "processing"

            elif event == "PreToolUse":
                state["status"] = "running_tool"
                state["tool"] = data.get("tool_name")
                state["tool_input"] = tool_input
                tool_use_id_from_event = data.get("tool_use_id")
                if tool_use_id_from_event:
                    state["tool_use_id"] = tool_use_id_from_event

            elif event == "PostToolUse":
                state["status"] = "processing"
                state["tool"] = data.get("tool_name")
                state["tool_input"] = tool_input
                tool_use_id_from_event = data.get("tool_use_id")
                if tool_use_id_from_event:
                    state["tool_use_id"] = tool_use_id_from_event

            elif event == "PermissionRequest":
                state["status"] = "waiting_for_approval"
                state["tool"] = data.get("tool_name")
                state["tool_input"] = tool_input

                # Send to app and wait for decision
                response = send_event(state)

                if response:
                    decision = response.get("decision", "ask")
                    reason = response.get("reason", "")

                    if decision == "allow":
                        output = {
                            "hookSpecificOutput": {
                                "hookEventName": "PermissionRequest",
                                "decision": {"behavior": "allow"},
                            }
                        }
                        print(json.dumps(output))
                        sys.exit(0)

                    elif decision == "deny":
                        output = {
                            "hookSpecificOutput": {
                                "hookEventName": "PermissionRequest",
                                "decision": {
                                    "behavior": "deny",
                                    "message": reason or "Denied by user via Claude Dock",
                                },
                            }
                        }
                        print(json.dumps(output))
                        sys.exit(0)

                # No response or "ask" - let Claude Code show its normal UI
                sys.exit(0)

            elif event == "Notification":
                notification_type = data.get("notification_type")
                if notification_type == "permission_prompt":
                    sys.exit(0)
                elif notification_type == "idle_prompt":
                    state["status"] = "waiting_for_input"
                else:
                    state["status"] = "notification"
                state["notification_type"] = notification_type
                state["message"] = data.get("message")

            elif event == "Stop":
                state["status"] = "waiting_for_input"

            elif event == "SubagentStop":
                state["status"] = "waiting_for_input"

            elif event == "SessionStart":
                state["status"] = "waiting_for_input"

            elif event == "SessionEnd":
                state["status"] = "ended"

            elif event == "PreCompact":
                state["status"] = "compacting"

            else:
                state["status"] = "unknown"

            # Send to socket (fire and forget for non-permission events)
            send_event(state)


        if __name__ == "__main__":
            main()
        """
    }
}
