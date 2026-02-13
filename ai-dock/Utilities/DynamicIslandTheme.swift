import SwiftUI

// MARK: - Terminal Colors

nonisolated enum TerminalColors {
    static let green = Color(red: 0.4, green: 0.75, blue: 0.45)
    static let amber = Color(red: 1.0, green: 0.7, blue: 0.0)
    static let red = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let cyan = Color(red: 0.0, green: 0.8, blue: 0.8)
    static let blue = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let magenta = Color(red: 0.8, green: 0.4, blue: 0.8)
    static let dim = Color.white.opacity(0.4)
    static let dimmer = Color.white.opacity(0.2)
    static let prompt = Color(red: 0.32, green: 0.72, blue: 0.94)
    static let background = Color.white.opacity(0.05)
    static let backgroundHover = Color.white.opacity(0.1)
}

// MARK: - Notch Shape

struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let tr = topCornerRadius
        let br = bottomCornerRadius

        var path = Path()

        // Start at top-left, curve inward (notch edge)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: tr, y: tr),
            control: CGPoint(x: tr, y: 0)
        )

        // Left edge down
        path.addLine(to: CGPoint(x: tr, y: h - br))

        // Bottom-left curve outward
        path.addQuadCurve(
            to: CGPoint(x: tr + br, y: h),
            control: CGPoint(x: tr, y: h)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: w - tr - br, y: h))

        // Bottom-right curve outward
        path.addQuadCurve(
            to: CGPoint(x: w - tr, y: h - br),
            control: CGPoint(x: w - tr, y: h)
        )

        // Right edge up
        path.addLine(to: CGPoint(x: w - tr, y: tr))

        // Top-right curve inward
        path.addQuadCurve(
            to: CGPoint(x: w, y: 0),
            control: CGPoint(x: w - tr, y: 0)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Theme Constants (backward compat aliases + sizing)

enum DynamicIslandTheme {
    // Colors
    static let background = Color.black
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.4)
    static let separator = Color.white.opacity(0.08)
    static let hoverHighlight = Color.white.opacity(0.06)
    static let ringBackground = Color.white.opacity(0.1)

    // Sizing
    static let expandedWidth: CGFloat = 420
    static let maxVisibleSessions: Int = 8
    static let rowHeight: CGFloat = 52
    static let emptyStateHeight: CGFloat = 80
    static let footerHeight: CGFloat = 28

    // Notch corner radii
    static let closedTopRadius: CGFloat = 6
    static let closedBottomRadius: CGFloat = 14
    static let openedTopRadius: CGFloat = 19
    static let openedBottomRadius: CGFloat = 24

    // Animation
    static let openAnimation: Animation = .spring(response: 0.42, dampingFraction: 0.8)
    static let closeAnimation: Animation = .spring(response: 0.45, dampingFraction: 1.0)
    static let morphAnimation: Animation = .spring(response: 0.42, dampingFraction: 0.8)
}
