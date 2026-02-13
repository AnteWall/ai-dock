import SwiftUI

struct AboutView: View {
    private let appVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }()

    private let buildNumber: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.6, blue: 1.0),
                            Color(red: 0.2, green: 0.84, blue: 0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 4) {
                Text("Claude Dock")
                    .font(.title2.bold())

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Monitor your Claude Code sessions from a floating panel and menu bar icon.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Divider()
                .padding(.horizontal, 20)

            Text("\u{00A9} 2025 Straw Hat Labs")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 320)
    }
}
