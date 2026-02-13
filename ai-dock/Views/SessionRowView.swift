import SwiftUI

struct SessionRowView: View {
    let session: ClaudeSession
    let onGoTo: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // State indicator column
            StateIndicatorView(state: session.state)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DynamicIslandTheme.textPrimary)
                        .lineLimit(1)

                    if let branch = session.gitBranch {
                        Text(branch)
                            .font(.system(size: 10))
                            .foregroundStyle(DynamicIslandTheme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                HStack(spacing: 4) {
                    Text(session.state.label)
                        .font(.system(size: 11))
                        .foregroundStyle(session.state.color.opacity(0.8))

                    if session.source == .opencode {
                        Text("\u{00B7}")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DynamicIslandTheme.textTertiary)
                        Text(session.source.label)
                            .font(.system(size: 11))
                            .foregroundStyle(TerminalColors.blue)
                    }

                    if let ide = session.ideName {
                        Text("\u{00B7}")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DynamicIslandTheme.textTertiary)
                        Text(ide)
                            .font(.system(size: 11))
                            .foregroundStyle(DynamicIslandTheme.textTertiary)
                    }

                    if let tool = session.lastTool, session.state == .running {
                        Text("\u{00B7}")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DynamicIslandTheme.textTertiary)
                        Text(tool)
                            .font(.system(size: 11))
                            .foregroundStyle(TerminalColors.dim)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            // Action button on hover
            if isHovered {
                ActionButton(title: "Open", icon: "arrow.up.right", color: .white) {
                    onGoTo()
                }
                .transition(.opacity.animation(.easeOut(duration: 0.15)))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? DynamicIslandTheme.hoverHighlight : .clear)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - State Indicator

struct StateIndicatorView: View {
    let state: SessionState

    var body: some View {
        switch state {
        case .running:
            OrbitLoader()
        case .actionNeeded:
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TerminalColors.amber)
        case .finished:
            Circle()
                .fill(TerminalColors.green)
                .frame(width: 6, height: 6)
        case .idle:
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(TerminalColors.dim)
                        .frame(width: 2.5, height: 2.5)
                }
            }
        case .unknown:
            Circle()
                .fill(TerminalColors.dimmer)
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isHovered ? Color.black : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? color : color.opacity(0.15))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
