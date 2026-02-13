import SwiftUI

struct PanelRootView: View {
    @Bindable var viewModel: DockViewModel
    var onSizeChange: ((CGFloat, CGFloat) -> Void)?

    @State private var glowPulsing = false

    private var topRadius: CGFloat {
        viewModel.isExpanded
            ? DynamicIslandTheme.openedTopRadius
            : DynamicIslandTheme.closedTopRadius
    }

    private var bottomRadius: CGFloat {
        viewModel.isExpanded
            ? DynamicIslandTheme.openedBottomRadius
            : DynamicIslandTheme.closedBottomRadius
    }

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView(
                distribution: viewModel.stateDistribution,
                hasActionNeeded: viewModel.hasActionNeeded,
                isExpanded: viewModel.isExpanded,
                sessionCount: viewModel.activeSessions.count,
                onTap: {
                    viewModel.toggleExpanded()
                }
            )

            if viewModel.isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .fixedSize()
        .background {
            NotchShape(
                topCornerRadius: topRadius,
                bottomCornerRadius: bottomRadius
            )
            .fill(DynamicIslandTheme.background)
        }
        .overlay {
            if viewModel.hasActionNeeded {
                NotchShape(
                    topCornerRadius: topRadius,
                    bottomCornerRadius: bottomRadius
                )
                .stroke(
                    TerminalColors.amber.opacity(glowPulsing ? 0.4 : 0.1),
                    lineWidth: 1.5
                )
                .blur(radius: glowPulsing ? 2 : 0.5)
                .animation(
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: glowPulsing
                )
                .onAppear { glowPulsing = true }
                .onDisappear { glowPulsing = false }
            }
        }
        .clipShape(
            NotchShape(
                topCornerRadius: topRadius,
                bottomCornerRadius: bottomRadius
            )
        )
        .animation(
            viewModel.isExpanded ? DynamicIslandTheme.openAnimation : DynamicIslandTheme.closeAnimation,
            value: viewModel.isExpanded
        )
        .background {
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.size) { _, newSize in
                        onSizeChange?(newSize.width, newSize.height)
                    }
                    .onAppear {
                        onSizeChange?(geo.size.width, geo.size.height)
                    }
            }
        }
        .onChange(of: viewModel.activeSessions.count) {
            // Size recalc on session count change
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            DynamicIslandTheme.separator
                .frame(height: 0.5)
                .padding(.horizontal, bottomRadius + 6)

            ScrollView {
                SessionListView(
                    sessions: viewModel.activeSessions,
                    onGoTo: { session in
                        viewModel.focusSession(session)
                    }
                )
                .padding(.vertical, 4)
                .padding(.horizontal, topRadius)
            }
            .frame(maxHeight: maxExpandedHeight)

            DynamicIslandTheme.separator
                .frame(height: 0.5)
                .padding(.horizontal, bottomRadius + 6)

            HStack {
                Text("\(viewModel.activeSessions.count) sessions")
                    .font(.system(size: 10))
                    .foregroundStyle(DynamicIslandTheme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, bottomRadius + 6)
            .padding(.vertical, 6)
            // Extra bottom padding so the footer doesn't get clipped by the bottom curve
            .padding(.bottom, bottomRadius - 6)
        }
        .frame(width: DynamicIslandTheme.expandedWidth)
    }

    private var maxExpandedHeight: CGFloat {
        let sessionCount = max(viewModel.activeSessions.count, 1)
        let visibleCount = min(sessionCount, DynamicIslandTheme.maxVisibleSessions)
        if viewModel.activeSessions.isEmpty {
            return DynamicIslandTheme.emptyStateHeight
        }
        return CGFloat(visibleCount) * DynamicIslandTheme.rowHeight
    }
}
