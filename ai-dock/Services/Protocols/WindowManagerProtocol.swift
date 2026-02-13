import Foundation

nonisolated protocol WindowManagerProtocol: Sendable {
    func focusTerminal(for session: ClaudeSession)
}
