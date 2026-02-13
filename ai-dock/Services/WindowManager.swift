import AppKit

nonisolated struct WindowManager: WindowManagerProtocol {
    func focusTerminal(for session: ClaudeSession) {
        // IDE sessions: use URL scheme to focus the correct window
        if session.isIDESession {
            focusIDEWindow(for: session)
            return
        }

        // Terminal sessions: use the GUI ancestor PID from process tree
        if let guiPID = session.guiAppPID,
           let app = NSRunningApplication(processIdentifier: guiPID),
           !app.isTerminated {
            app.activate()
            return
        }

        // Heuristic fallback: try common terminal apps
        let terminalBundles = [
            "com.googlecode.iterm2",
            "com.apple.Terminal",
            "dev.warp.Warp-Stable",
            "co.zeit.hyper",
            "com.github.wez.wezterm",
            "net.kovidgoyal.kitty"
        ]

        for bundleId in terminalBundles {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if let app = apps.first, !app.isTerminated {
                app.activate()
                return
            }
        }
    }

    private func focusIDEWindow(for session: ClaudeSession) {
        let cwd = session.cwd
        let ideName = session.ideName?.lowercased() ?? ""

        // Try URL scheme first — this focuses the specific window by folder
        if let url = ideURL(for: ideName, path: cwd) {
            NSWorkspace.shared.open(url)
            return
        }

        // Fallback: activate the IDE process directly
        if let idePID = session.ideAppPID,
           let app = NSRunningApplication(processIdentifier: idePID),
           !app.isTerminated {
            app.activate()
        }
    }

    private func ideURL(for ideName: String, path: String) -> URL? {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path

        if ideName.contains("visual studio code") || ideName.contains("vscode") {
            return URL(string: "vscode://file\(encodedPath)")
        }
        if ideName.contains("cursor") {
            return URL(string: "cursor://file\(encodedPath)")
        }
        if ideName.contains("windsurf") {
            return URL(string: "windsurf://file\(encodedPath)")
        }

        // JetBrains IDEs don't have a reliable single-window URL scheme;
        // fall through to PID-based activation
        return nil
    }
}
