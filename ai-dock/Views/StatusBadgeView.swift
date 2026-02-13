import SwiftUI

struct StatusBadgeView: View {
    let state: SessionState

    var body: some View {
        Text(state.label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(state.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(state.color.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(state.color.opacity(0.2), lineWidth: 0.5)
            }
    }
}
