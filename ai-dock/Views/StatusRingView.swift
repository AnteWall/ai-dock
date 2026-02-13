import SwiftUI

struct StatusRingView: View {
    let distribution: [SessionState: Int]
    var size: CGFloat = 20
    var lineWidth: CGFloat = 2.5

    private var activeDistribution: [SessionState: Int] {
        distribution.filter { $0.key != .idle && $0.key != .unknown }
    }

    private var total: Int {
        activeDistribution.values.reduce(0, +)
    }

    private var segments: [(state: SessionState, fraction: CGFloat)] {
        guard total > 0 else { return [] }

        let order: [SessionState] = [.actionNeeded, .running, .finished]
        return order.compactMap { state in
            guard let count = activeDistribution[state], count > 0 else { return nil }
            return (state, CGFloat(count) / CGFloat(total))
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DynamicIslandTheme.ringBackground, lineWidth: lineWidth)

            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                Circle()
                    .trim(from: startAngle(for: index), to: endAngle(for: index))
                    .stroke(segment.state.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
    }

    private func startAngle(for index: Int) -> CGFloat {
        segments.prefix(index).map(\.fraction).reduce(0, +)
    }

    private func endAngle(for index: Int) -> CGFloat {
        segments.prefix(index + 1).map(\.fraction).reduce(0, +)
    }
}
