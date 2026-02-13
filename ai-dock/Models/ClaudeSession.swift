import Foundation
import SwiftUI

nonisolated enum SessionSource: String, Sendable, CaseIterable {
    case claude
    case opencode

    init?(rawValue: String) {
        let normalized = rawValue.lowercased()
        switch normalized {
        case "claude":
            self = .claude
        case "opencode":
            self = .opencode
        default:
            return nil
        }
    }

    var label: String {
        switch self {
        case .claude:
            return "Claude"
        case .opencode:
            return "OpenCode"
        }
    }
}

nonisolated struct ClaudeSession: Identifiable, Sendable {
    let id: String
    var cwd: String
    var state: SessionState
    var source: SessionSource
    var hookStatus: String?
    var lastTool: String?
    var tty: String?
    var pid: Int32?
    var guiAppPID: Int32?
    var ideAppPID: Int32?
    var lastActivity: Date
    var terminatedAt: Date?
    var ideName: String?
    var gitBranch: String?

    var isIDESession: Bool {
        ideName != nil && ideAppPID != nil
    }

    var projectName: String {
        URL(fileURLWithPath: cwd).lastPathComponent
    }

    var isActive: Bool {
        state == .running || state == .finished || state == .actionNeeded
    }
}
