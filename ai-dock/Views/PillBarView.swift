import Combine
import AppKit
import SwiftUI

/// The collapsed notch header.
/// Shows an AI glyph, status summary, and animated processing indicator.
struct NotchHeaderView: View {
    let distribution: [SessionState: Int]
    let hasActionNeeded: Bool
    let isExpanded: Bool
    let sessionCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if notchMetrics.hasCameraCutout {
                    cameraAwareContent
                } else {
                    defaultContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .fixedSize()
        }
        .buttonStyle(.plain)
    }

    private var notchMetrics: NotchLayoutMetrics {
        NotchLayoutMetrics.current()
    }

    @ViewBuilder
    private var defaultContent: some View {
        AIDockGlyph(size: 18)

        if sessionCount == 0 {
            Text("ai-dock")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DynamicIslandTheme.textTertiary)
        } else {
            statusIndicator
            labels
        }

        chevron
    }

    @ViewBuilder
    private var cameraAwareContent: some View {
        HStack(spacing: 10) {
            leftLoader
                .frame(minWidth: 18, alignment: .leading)

            Color.clear
                .frame(width: notchMetrics.cameraGapWidth)

            labels

            chevron
        }
    }

    @ViewBuilder
    private var leftLoader: some View {
        if sessionCount == 0 {
            AIDockGlyph(size: 16)
        } else {
            statusIndicator
        }
    }

    @ViewBuilder
    private var labels: some View {
        if sessionCount == 0 {
            Text("ai-dock")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DynamicIslandTheme.textTertiary)
        } else {
            Text(priorityLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(priorityColor)
                .fixedSize()

            if let secondary = secondaryLabel {
                Text("\u{00B7}")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DynamicIslandTheme.textTertiary)
                Text(secondary)
                    .font(.system(size: 11))
                    .foregroundStyle(DynamicIslandTheme.textSecondary)
                    .fixedSize()
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(DynamicIslandTheme.textTertiary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .animation(DynamicIslandTheme.morphAnimation, value: isExpanded)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if hasRunning {
            OrbitLoader()
        } else if hasActionNeeded {
            Circle()
                .fill(TerminalColors.amber)
                .frame(width: 6, height: 6)
        } else if hasFinished {
            Circle()
                .fill(TerminalColors.green)
                .frame(width: 6, height: 6)
        }
    }

    private var hasRunning: Bool {
        distribution[.running, default: 0] > 0
    }

    private var hasFinished: Bool {
        distribution[.finished, default: 0] > 0
    }

    private var priorityLabel: String {
        let order: [SessionState] = [.actionNeeded, .running, .finished, .idle]
        for state in order {
            if let count = distribution[state], count > 0 {
                return count == 1
                    ? state.label
                    : "\(count) \(state.shortLabel)"
            }
        }
        return "\(sessionCount) sessions"
    }

    private var priorityColor: Color {
        let order: [SessionState] = [.actionNeeded, .running, .finished, .idle]
        for state in order {
            if let count = distribution[state], count > 0 {
                return state.color
            }
        }
        return DynamicIslandTheme.textPrimary
    }

    private var secondaryLabel: String? {
        let order: [SessionState] = [.actionNeeded, .running, .finished, .idle]
        var skippedFirst = false
        for state in order {
            if let count = distribution[state], count > 0 {
                if !skippedFirst {
                    skippedFirst = true
                    continue
                }
                return "\(count) \(state.shortLabel)"
            }
        }
        return nil
    }
}

// MARK: - AI Dock Glyph

struct AIDockGlyph: View {
    var size: CGFloat = 18
    var color: Color = TerminalColors.cyan

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let center = CGPoint(x: w * 0.5, y: h * 0.5)
            let r = min(w, h) * 0.42

            var hex = Path()
            for i in 0..<6 {
                let angle = (Double(i) * .pi / 3) - (.pi / 2)
                let p = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * r,
                    y: center.y + CGFloat(sin(angle)) * r
                )
                if i == 0 {
                    hex.move(to: p)
                } else {
                    hex.addLine(to: p)
                }
            }
            hex.closeSubpath()
            context.stroke(hex, with: .color(color.opacity(0.9)), lineWidth: 1.6)

            var links = Path()
            links.move(to: CGPoint(x: center.x - r * 0.5, y: center.y + r * 0.1))
            links.addLine(to: CGPoint(x: center.x, y: center.y - r * 0.45))
            links.addLine(to: CGPoint(x: center.x + r * 0.5, y: center.y + r * 0.1))
            context.stroke(links, with: .color(color.opacity(0.7)), lineWidth: 1.4)

            let points = [
                CGPoint(x: center.x - r * 0.5, y: center.y + r * 0.1),
                CGPoint(x: center.x, y: center.y - r * 0.45),
                CGPoint(x: center.x + r * 0.5, y: center.y + r * 0.1),
                center,
            ]

            for p in points {
                let dot = CGRect(x: p.x - 1.8, y: p.y - 1.8, width: 3.6, height: 3.6)
                context.fill(Path(ellipseIn: dot), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Processing Loader

struct OrbitLoader: View {
    @State private var phase: Double = 0
    private let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Circle()
                .stroke(TerminalColors.cyan.opacity(0.25), lineWidth: 1)
            ForEach(0..<3, id: \.self) { idx in
                Circle()
                    .fill(TerminalColors.cyan)
                    .frame(width: idx == 0 ? 4.5 : 3.2, height: idx == 0 ? 4.5 : 3.2)
                    .offset(y: -5)
                    .rotationEffect(.radians(phase + Double(idx) * ((2 * .pi) / 3)))
            }
        }
        .frame(width: 14, height: 14)
        .onReceive(timer) { _ in
            phase += 0.13
        }
    }
}
