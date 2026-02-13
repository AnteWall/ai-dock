import Foundation

nonisolated struct HookEvent: Sendable {
    let sessionId: String
    let cwd: String
    let event: String
    let status: String
    let pid: Int32?
    let tty: String?
    let tool: String?
    let toolInput: [String: String]?
    let notificationType: String?
    let source: SessionSource?

    var sessionState: SessionState {
        switch status {
        case "processing", "running_tool", "compacting":
            return .running
        case "waiting_for_input", "ended":
            return .finished
        case "waiting_for_approval":
            return .actionNeeded
        default:
            return .unknown
        }
    }

    var isSessionEnd: Bool {
        status == "ended"
    }
}

extension HookEvent: Decodable {
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd, event, status, pid, tty, tool
        case toolInput = "tool_input"
        case notificationType = "notification_type"
        case source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        cwd = try c.decodeIfPresent(String.self, forKey: .cwd) ?? ""
        event = try c.decode(String.self, forKey: .event)
        status = try c.decode(String.self, forKey: .status)
        pid = try c.decodeIfPresent(Int32.self, forKey: .pid)
        tty = try c.decodeIfPresent(String.self, forKey: .tty)
        tool = try c.decodeIfPresent(String.self, forKey: .tool)
        notificationType = try c.decodeIfPresent(String.self, forKey: .notificationType)
        if let rawSource = try c.decodeIfPresent(String.self, forKey: .source) {
            source = SessionSource(rawValue: rawSource)
        } else {
            source = nil
        }

        // Decode tool_input as flat [String: String] — skip complex nested values
        if let raw = try? c.decodeIfPresent([String: AnyCodableString].self, forKey: .toolInput) {
            toolInput = raw.compactMapValues { $0.stringValue }
        } else {
            toolInput = nil
        }
    }
}

/// Helper to decode heterogeneous JSON values as optional strings.
private struct AnyCodableString: Decodable, Sendable {
    let stringValue: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            stringValue = s
        } else if let n = try? container.decode(Double.self) {
            stringValue = String(n)
        } else if let b = try? container.decode(Bool.self) {
            stringValue = String(b)
        } else {
            stringValue = nil
        }
    }
}
