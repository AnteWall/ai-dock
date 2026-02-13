import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class DockViewModel {
    var sessions: [ClaudeSession] = []
    var isExpanded = false
    var hasPermissionForNotifications = false
    var onRefresh: (() -> Void)?

    private let settings: AppSettings?
    private let hookSocketServer: HookSocketServerProtocol
    private let processMonitor: ProcessMonitorProtocol
    private let ideLockFileReader: IDELockFileReader
    private let notificationService: NotificationServiceProtocol
    private let windowManager: WindowManagerProtocol

    let debugLog = DebugLog()

    private var sessionMap: [String: ClaudeSession] = [:]
    private var maintenanceTimer: Timer?
    private var notifiedActionNeeded: Set<String> = []
    private var notifiedFinished: Set<String> = []
    private var previousStates: [String: SessionState] = [:]
    private var autoExpandedForAction = false

    private var terminatedFinishedVisibilitySeconds: TimeInterval {
        TimeInterval(max(settings?.opencodeFinishedVisibilitySeconds ?? 20, 0))
    }

    private var terminatedSessionCleanupSeconds: TimeInterval {
        TimeInterval(max(settings?.opencodeTerminatedCleanupSeconds ?? 120, 10))
    }

    init(
        settings: AppSettings? = nil,
        hookSocketServer: HookSocketServerProtocol = HookSocketServer(),
        processMonitor: ProcessMonitorProtocol = ProcessMonitor(),
        ideLockFileReader: IDELockFileReader = IDELockFileReader(),
        notificationService: NotificationServiceProtocol = NotificationService(),
        windowManager: WindowManagerProtocol = WindowManager()
    ) {
        self.settings = settings
        self.hookSocketServer = hookSocketServer
        self.processMonitor = processMonitor
        self.ideLockFileReader = ideLockFileReader
        self.notificationService = notificationService
        self.windowManager = windowManager
    }

    func start() {
        notificationService.requestPermission()

        hookSocketServer.start { [weak self] event in
            Task { @MainActor [weak self] in
                self?.processEvent(event)
            }
        }

        // Light maintenance timer for IDE lock files and stale session cleanup
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.runMaintenance()
            }
        }
    }

    func stop() {
        hookSocketServer.stop()
        maintenanceTimer?.invalidate()
        maintenanceTimer = nil
    }

    // MARK: - Hook Event Processing

    private func processEvent(_ event: HookEvent) {
        let sessionId = event.sessionId

        // SessionEnd → remove session
        if event.isSessionEnd {
            sessionMap.removeValue(forKey: sessionId)
            previousStates.removeValue(forKey: sessionId)
            notifiedActionNeeded.remove(sessionId)
            notifiedFinished.remove(sessionId)
            rebuildSessionList()
            return
        }

        let newState = event.sessionState

        if var existing = sessionMap[sessionId] {
            // Update existing session
            let previousState = existing.state
            existing.state = newState
            if let source = event.source {
                existing.source = source
            }
            existing.hookStatus = event.status
            existing.lastActivity = Date()
            existing.terminatedAt = nil
            if let tool = event.tool {
                existing.lastTool = tool
            }
            if let tty = event.tty {
                existing.tty = tty
            }
            if let pid = event.pid {
                existing.pid = pid
                existing.terminatedAt = nil
                if existing.guiAppPID == nil {
                    existing.guiAppPID = processMonitor.guiAncestor(of: pid)
                }
            }
            if !event.cwd.isEmpty && existing.cwd != event.cwd {
                existing.cwd = event.cwd
            }

            sessionMap[sessionId] = existing
            handleStateTransition(
                session: existing,
                previousState: previousState,
                reason: "\(event.event) → \(event.status)",
                hookEvent: event.event,
                hookStatus: event.status
            )
        } else {
            // New session
            var session = ClaudeSession(
                id: sessionId,
                cwd: event.cwd,
                state: newState,
                source: event.source ?? .claude,
                hookStatus: event.status,
                lastTool: event.tool,
                tty: event.tty,
                pid: event.pid,
                lastActivity: Date(),
                terminatedAt: nil
            )

            // Enrich with PID info
            if let pid = event.pid {
                session.guiAppPID = processMonitor.guiAncestor(of: pid)
            }

            // Enrich with IDE lock file info
            let ideLockFiles = ideLockFileReader.parseIDELockFiles()
            if let lockFile = ideLockFiles.first(where: { lock in
                lock.workspaceFolders?.contains(session.cwd) == true
            }) {
                session.ideName = lockFile.ideName
                session.ideAppPID = lockFile.pid
            }

            sessionMap[sessionId] = session
            handleStateTransition(
                session: session,
                previousState: nil,
                reason: "\(event.event) → \(event.status)",
                hookEvent: event.event,
                hookStatus: event.status
            )
        }

        rebuildSessionList()
    }

    private func handleStateTransition(
        session: ClaudeSession,
        previousState: SessionState?,
        reason: String,
        hookEvent: String,
        hookStatus: String
    ) {
        var needsAttention = false

        // Action needed notification
        if session.state == .actionNeeded,
           previousState != .actionNeeded,
           !notifiedActionNeeded.contains(session.id) {
            notifiedActionNeeded.insert(session.id)
            needsAttention = true
            if settings?.notificationsEnabled != false {
                notificationService.sendNotification(
                    title: "Session needs your input",
                    body: "\(session.projectName) is waiting for action",
                    identifier: "action-\(session.id)"
                )
            }
        } else if session.state != .actionNeeded {
            notifiedActionNeeded.remove(session.id)
        }

        // Finished notification
        if session.state == .finished,
           previousState != .finished,
           previousState != nil,
           !notifiedFinished.contains(session.id) {
            notifiedFinished.insert(session.id)
            needsAttention = true
            if settings?.notificationsEnabled != false {
                notificationService.sendNotification(
                    title: "Session finished",
                    body: "\(session.projectName) is ready for new input",
                    identifier: "finished-\(session.id)"
                )
            }
        } else if session.state != .finished {
            notifiedFinished.remove(session.id)
        }

        // Debug logging
        if settings?.debugLogging == true, previousState != session.state {
            debugLog.append(StateSnapshot(
                timestamp: Date(),
                sessionId: session.id,
                projectName: session.projectName,
                previousState: previousState,
                newState: session.state,
                reason: reason,
                hasPID: session.pid != nil,
                lastActivity: session.lastActivity,
                hookEvent: hookEvent,
                hookStatus: hookStatus
            ))
        }

        previousStates[session.id] = session.state

        // Auto-expand when attention needed
        if needsAttention {
            reconcileExpansionForAttention()
        }
    }

    private func rebuildSessionList() {
        var list = Array(sessionMap.values)
        list.sort { $0.state.sortOrder < $1.state.sortOrder }
        sessions = list
        reconcileExpansionForAttention()
        onRefresh?()
    }

    private func reconcileExpansionForAttention() {
        let attentionActive = hasAttentionNeeded
        if attentionActive && !isExpanded {
            isExpanded = true
            autoExpandedForAction = true
        } else if !attentionActive, autoExpandedForAction, isExpanded {
            isExpanded = false
            autoExpandedForAction = false
        }
    }

    // MARK: - Maintenance

    private func runMaintenance() {
        let ideLockFiles = ideLockFileReader.parseIDELockFiles()

        // Update IDE info for sessions that may not have had it at creation
        for (id, var session) in sessionMap {
            if session.ideName == nil {
                if let lockFile = ideLockFiles.first(where: { lock in
                    lock.workspaceFolders?.contains(session.cwd) == true
                }) {
                    session.ideName = lockFile.ideName
                    session.ideAppPID = lockFile.pid
                    sessionMap[id] = session
                }
            }

            // Check if PID is still alive; update state if process died
            if let pid = session.pid, !processMonitor.isProcessRunning(pid: pid) {
                let previousState = session.state
                session.pid = nil
                session.guiAppPID = nil
                if session.terminatedAt == nil {
                    session.terminatedAt = Date()
                }
                // For OpenCode CLI sessions, process exit after a response is usually "finished".
                if session.source == .opencode {
                    if session.state == .running {
                        session.state = .finished
                    } else if session.state == .actionNeeded {
                        session.state = .idle
                    }
                } else {
                    // Claude sessions retain prior behavior.
                    if session.state == .running || session.state == .actionNeeded {
                        session.state = .idle
                    }
                }
                sessionMap[id] = session

                if previousState != session.state {
                    handleStateTransition(
                        session: session,
                        previousState: previousState,
                        reason: "maintenance → process_exit",
                        hookEvent: "maintenance",
                        hookStatus: "process_exit"
                    )
                }
            }

            if session.source == .opencode,
               let terminatedAt = session.terminatedAt,
               Date().timeIntervalSince(terminatedAt) > terminatedSessionCleanupSeconds,
               session.pid == nil {
                sessionMap.removeValue(forKey: id)
                previousStates.removeValue(forKey: id)
                notifiedActionNeeded.remove(id)
                notifiedFinished.remove(id)
                continue
            }

            // Remove sessions idle for more than 3 hours
            let age = Date().timeIntervalSince(session.lastActivity)
            if age > 3 * 60 * 60 && session.pid == nil {
                sessionMap.removeValue(forKey: id)
                previousStates.removeValue(forKey: id)
            }
        }

        rebuildSessionList()
    }

    // MARK: - User Actions

    func toggleExpanded() {
        isExpanded.toggle()
        if !isExpanded {
            autoExpandedForAction = false
        }
    }

    func focusSession(_ session: ClaudeSession) {
        windowManager.focusTerminal(for: session)
    }

    // MARK: - Computed properties for UI

    var activeSessions: [ClaudeSession] {
        let now = Date()
        return sessions.filter {
            guard $0.state != .unknown else { return false }
            if $0.state == .idle, $0.pid == nil { return false }

            if $0.source == .opencode,
               let terminatedAt = $0.terminatedAt,
               $0.pid == nil,
               $0.state == .finished {
                return now.timeIntervalSince(terminatedAt) <= terminatedFinishedVisibilitySeconds
            }

            return true
        }
    }

    var stateDistribution: [SessionState: Int] {
        var dist: [SessionState: Int] = [:]
        for session in activeSessions {
            dist[session.state, default: 0] += 1
        }
        return dist
    }

    var statusSegments: [(state: SessionState, count: Int)] {
        let order: [SessionState] = [.actionNeeded, .running, .finished]
        return order.compactMap { state in
            guard let count = stateDistribution[state], count > 0 else { return nil }
            return (state, count)
        }
    }

    var hasActionNeeded: Bool {
        activeSessions.contains { $0.state == .actionNeeded }
    }

    var hasAttentionNeeded: Bool {
        activeSessions.contains { $0.state == .actionNeeded || $0.state == .finished }
    }
}
