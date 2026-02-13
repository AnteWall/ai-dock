import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var debugLog: DebugLog

    @State private var hookStatus: HookInstallStatus = .notInstalled
    @State private var opencodeStatus: OpenCodePluginStatus = .notInstalled
    @State private var opencodeRuntimeStatus: String = "No runtime status yet"
    @State private var socketAvailable = false
    @State private var socketTestMessage: String?
    private let hookManager = HookManager()
    private let opencodeManager = OpenCodePluginManager()

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            debugTab
                .tabItem { Label("Debug", systemImage: "ladybug") }
        }
        .frame(width: 480, height: 400)
        .onAppear {
            hookStatus = hookManager.checkStatus()
            opencodeStatus = opencodeManager.checkStatus()
            refreshOpenCodeRuntimeStatus()
            socketAvailable = HookSocketDiagnostics.socketExists()
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("General") {
                Toggle("Show Floating Panel", isOn: $settings.panelVisible)
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)
            }

            Section("Claude Code Hooks") {
                HStack {
                    Text("Status")
                    Spacer()
                    hookStatusBadge
                }

                HStack {
                    Text("Socket")
                    Spacer()
                    Text(HookSocketServer.socketPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Socket State")
                    Spacer()
                    Label(socketAvailable ? "Listening" : "Not Found", systemImage: socketAvailable ? "dot.radiowaves.left.and.right" : "bolt.slash")
                        .foregroundStyle(socketAvailable ? .green : .orange)
                        .font(.system(size: 12))
                }

                if let socketTestMessage {
                    Text(socketTestMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if case .installed = hookStatus {
                        Button("Reinstall") {
                            reinstallHooks()
                        }
                        Button("Uninstall") {
                            uninstallHooks()
                        }
                    } else {
                        Button("Install Hooks") {
                            installHooks()
                        }
                    }

                    Button("Refresh Socket") {
                        refreshSocketStatus()
                    }

                    Button("Send Test Event") {
                        sendSocketTestEvent()
                    }
                    .disabled(!socketAvailable)
                }
            }

            Section("OpenCode Plugin") {
                HStack {
                    Text("Status")
                    Spacer()
                    opencodeStatusBadge
                }

                HStack {
                    Text("Plugin")
                    Spacer()
                    Text(opencodeManager.pluginPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Runtime Status File")
                    Spacer()
                    Text(opencodeManager.pluginStatusPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(opencodeRuntimeStatus)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)

                if case .notDetected = opencodeStatus {
                    Text("OpenCode config not found. Launch OpenCode once to create it, then retry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    switch opencodeStatus {
                    case .installed:
                        Button("Reinstall") {
                            reinstallOpenCodePlugin()
                        }
                        Button("Uninstall") {
                            uninstallOpenCodePlugin()
                        }
                    case .notInstalled, .outdated:
                        Button("Install Plugin") {
                            installOpenCodePlugin()
                        }
                    case .notDetected:
                        Button("Retry") {
                            refreshOpenCodeStatus()
                        }
                    case .error:
                        Button("Retry") {
                            refreshOpenCodeStatus()
                        }
                    }

                    Button("Refresh Runtime") {
                        refreshOpenCodeRuntimeStatus()
                    }
                }

                Stepper(
                    "Show finished terminated sessions for \(settings.opencodeFinishedVisibilitySeconds)s",
                    value: $settings.opencodeFinishedVisibilitySeconds,
                    in: 0 ... 180,
                    step: 5
                )

                Stepper(
                    "Remove terminated sessions after \(settings.opencodeTerminatedCleanupSeconds)s",
                    value: $settings.opencodeTerminatedCleanupSeconds,
                    in: 10 ... 1800,
                    step: 10
                )

                Text("Interactive OpenCode sessions remain visible while their process is running. One-shot runs are shown as finished briefly, then removed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var hookStatusBadge: some View {
        switch hookStatus {
        case .installed:
            Label("Installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 12))
        case .notInstalled:
            Label("Not Installed", systemImage: "xmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
        case .outdated:
            Label("Outdated", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 12))
        case .error(let msg):
            Label("Error: \(msg)", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 12))
        }
    }

    @ViewBuilder
    private var opencodeStatusBadge: some View {
        switch opencodeStatus {
        case .installed:
            Label("Installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 12))
        case .notInstalled:
            Label("Not Installed", systemImage: "xmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
        case .notDetected:
            Label("Not Detected", systemImage: "questionmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
        case .outdated:
            Label("Outdated", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 12))
        case .error(let msg):
            Label("Error: \(msg)", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 12))
        }
    }

    private func installHooks() {
        do {
            try hookManager.install()
            settings.hooksInstalled = true
            hookStatus = .installed
            refreshSocketStatus()
        } catch {
            hookStatus = .error(error.localizedDescription)
        }
    }

    private func reinstallHooks() {
        do {
            try hookManager.install()
            settings.hooksInstalled = true
            hookStatus = .installed
            refreshSocketStatus()
        } catch {
            hookStatus = .error(error.localizedDescription)
        }
    }

    private func uninstallHooks() {
        do {
            try hookManager.uninstall()
            settings.hooksInstalled = false
            hookStatus = .notInstalled
            refreshSocketStatus()
        } catch {
            hookStatus = .error(error.localizedDescription)
        }
    }

    private func refreshSocketStatus() {
        socketAvailable = HookSocketDiagnostics.socketExists()
        if !socketAvailable {
            socketTestMessage = "Socket is unavailable. Make sure ai-dock is running and restarted after updates."
        }
    }

    private func sendSocketTestEvent() {
        do {
            try HookSocketDiagnostics.sendTestEvent(source: .opencode)
            socketTestMessage = "Test event sent. You should see an OpenCode test session in the dock."
        } catch {
            socketTestMessage = "Test event failed: \(error.localizedDescription)"
        }
        refreshSocketStatus()
    }

    private func refreshOpenCodeStatus() {
        opencodeStatus = opencodeManager.checkStatus()
        refreshOpenCodeRuntimeStatus()
    }

    private func refreshOpenCodeRuntimeStatus() {
        opencodeRuntimeStatus = opencodeManager.readPluginRuntimeStatus() ?? "No status file yet. Start OpenCode and run one prompt."
    }

    private func installOpenCodePlugin() {
        do {
            try opencodeManager.install()
            settings.opencodePluginInstalled = true
            opencodeStatus = .installed
            refreshOpenCodeRuntimeStatus()
        } catch {
            settings.opencodePluginInstalled = false
            opencodeStatus = .error(error.localizedDescription)
        }
    }

    private func reinstallOpenCodePlugin() {
        do {
            try opencodeManager.install()
            settings.opencodePluginInstalled = true
            opencodeStatus = .installed
            refreshOpenCodeRuntimeStatus()
        } catch {
            settings.opencodePluginInstalled = false
            opencodeStatus = .error(error.localizedDescription)
        }
    }

    private func uninstallOpenCodePlugin() {
        do {
            try opencodeManager.uninstall()
            settings.opencodePluginInstalled = false
            opencodeStatus = .notInstalled
            refreshOpenCodeRuntimeStatus()
        } catch {
            opencodeStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Debug

    private var debugTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    Toggle("Enable Debug Logging", isOn: $settings.debugLogging)
                } footer: {
                    Text("Captures a snapshot each time a session changes state, including the hook event that triggered the transition.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(height: 100)

            // Log viewer
            GroupBox {
                if debugLog.snapshots.isEmpty {
                    ContentUnavailableView {
                        Label("No Snapshots", systemImage: "doc.text")
                    } description: {
                        Text(settings.debugLogging ? "State changes will appear here." : "Enable debug logging to capture state changes.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(debugLog.snapshots) { snapshot in
                                    Text(snapshot.formatted)
                                        .font(.system(size: 10, design: .monospaced))
                                        .textSelection(.enabled)
                                        .id(snapshot.id)
                                }
                            }
                            .padding(6)
                        }
                        .onChange(of: debugLog.snapshots.count) {
                            if let last = debugLog.snapshots.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            // Buttons
            HStack {
                Text("\(debugLog.snapshots.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    debugLog.clear()
                }
                .disabled(debugLog.snapshots.isEmpty)

                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(debugLog.fullText, forType: .string)
                }
                .disabled(debugLog.snapshots.isEmpty)
            }
            .padding(12)
        }
    }
}
