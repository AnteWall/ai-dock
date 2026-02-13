import Foundation
import Observation

struct StateSnapshot: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let sessionId: String
    let projectName: String
    let previousState: SessionState?
    let newState: SessionState
    let reason: String
    let hasPID: Bool
    let lastActivity: Date?
    let hookEvent: String
    let hookStatus: String

    var formatted: String {
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm:ss.SSS"
        let ts = tf.string(from: timestamp)
        let prev = previousState?.rawValue ?? "none"
        let pid = hasPID ? "pid=yes" : "pid=no"
        var activityAge = "n/a"
        if let la = lastActivity {
            let age = timestamp.timeIntervalSince(la)
            activityAge = String(format: "%.1fs ago", age)
        }
        return "[\(ts)] \(projectName): \(prev) → \(newState.rawValue) | \(reason) | \(pid) | activity: \(activityAge) | hook: \(hookEvent)→\(hookStatus)"
    }
}

@Observable
@MainActor
final class DebugLog {
    private(set) var snapshots: [StateSnapshot] = []
    private let maxEntries = 500

    func append(_ snapshot: StateSnapshot) {
        snapshots.append(snapshot)
        if snapshots.count > maxEntries {
            snapshots.removeFirst(snapshots.count - maxEntries)
        }
    }

    func clear() {
        snapshots.removeAll()
    }

    var fullText: String {
        snapshots.map(\.formatted).joined(separator: "\n")
    }
}
