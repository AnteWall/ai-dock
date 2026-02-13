import SwiftUI

nonisolated enum SessionState: String, Sendable, CaseIterable {
    case running
    case finished
    case actionNeeded
    case idle
    case unknown

    var color: Color {
        switch self {
        case .running: TerminalColors.cyan
        case .finished: TerminalColors.green
        case .actionNeeded: TerminalColors.amber
        case .idle: TerminalColors.dim
        case .unknown: TerminalColors.dimmer
        }
    }

    var glowColor: Color {
        switch self {
        case .actionNeeded: TerminalColors.amber
        default: .clear
        }
    }

    var label: String {
        switch self {
        case .running: "Running"
        case .finished: "Finished"
        case .actionNeeded: "Action Needed"
        case .idle: "Idle"
        case .unknown: "Unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .running: "running"
        case .finished: "finished"
        case .actionNeeded: "action"
        case .idle: "idle"
        case .unknown: "unknown"
        }
    }

    var sortOrder: Int {
        switch self {
        case .actionNeeded: 0
        case .running: 1
        case .finished: 2
        case .idle: 3
        case .unknown: 4
        }
    }

    var systemImage: String {
        switch self {
        case .running: "play.circle.fill"
        case .finished: "checkmark.circle.fill"
        case .actionNeeded: "exclamationmark.circle.fill"
        case .idle: "moon.fill"
        case .unknown: "questionmark.circle"
        }
    }
}
