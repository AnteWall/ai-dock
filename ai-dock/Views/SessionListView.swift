import SwiftUI

struct SessionListView: View {
    let sessions: [ClaudeSession]
    let onGoTo: (ClaudeSession) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if sessions.isEmpty {
                emptyState
            } else {
                ForEach(sessions) { session in
                    SessionRowView(session: session) {
                        onGoTo(session)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No active sessions")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DynamicIslandTheme.textSecondary)
            Text("Start Claude Code or OpenCode in a terminal")
                .font(.system(size: 11))
                .foregroundStyle(DynamicIslandTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
