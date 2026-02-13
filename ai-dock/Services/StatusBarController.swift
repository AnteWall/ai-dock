import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private weak var viewModel: DockViewModel?
    private weak var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    init(settings: AppSettings, viewModel: DockViewModel, panel: NSPanel) {
        self.settings = settings
        self.viewModel = viewModel
        self.panel = panel

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Claude Dock")
            button.image?.size = NSSize(width: 14, height: 14)
            button.image?.isTemplate = false
        }

        buildMenu()
        updateIcon(color: .gray)
    }

    func update(sessions: [ClaudeSession]) {
        let color = highestPriorityColor(for: sessions)
        updateIcon(color: color)
        buildMenu(sessions: sessions)
    }

    // MARK: - Icon

    private func updateIcon(color: NSColor) {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Claude Dock")?
            .withSymbolConfiguration(config)
        button.image = image
        button.contentTintColor = color
    }

    private func highestPriorityColor(for sessions: [ClaudeSession]) -> NSColor {
        let activeSessions = sessions.filter { $0.state != .unknown && ($0.state != .idle || $0.pid != nil) }
        if activeSessions.isEmpty { return .gray }

        if activeSessions.contains(where: { $0.state == .actionNeeded }) {
            return NSColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0) // amber
        }
        if activeSessions.contains(where: { $0.state == .running }) {
            return NSColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0) // cyan
        }
        if activeSessions.contains(where: { $0.state == .finished }) {
            return NSColor(red: 0.4, green: 0.75, blue: 0.45, alpha: 1.0) // green
        }
        return .gray
    }

    // MARK: - Menu

    private func buildMenu(sessions: [ClaudeSession] = []) {
        let menu = NSMenu()

        // Session summary header
        let summary = sessionSummary(sessions: sessions)
        let headerItem = NSMenuItem(title: summary, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // Show/Hide Panel (quick toggle stays in menu for convenience)
        let panelItem = NSMenuItem(
            title: "Show Panel",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        panelItem.target = self
        panelItem.state = settings.panelVisible ? .on : .off
        menu.addItem(panelItem)

        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // About
        let aboutItem = NSMenuItem(
            title: "About Claude Dock",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Claude Dock",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func sessionSummary(sessions: [ClaudeSession]) -> String {
        let active = sessions.filter { $0.state != .unknown && ($0.state != .idle || $0.pid != nil) }
        if active.isEmpty { return "No sessions" }

        var parts: [String] = []
        let actionNeeded = active.filter { $0.state == .actionNeeded }.count
        let finished = active.filter { $0.state == .finished }.count
        let running = active.filter { $0.state == .running }.count

        if actionNeeded > 0 { parts.append("\(actionNeeded) Action Needed") }
        if finished > 0 { parts.append("\(finished) Finished") }
        if running > 0 { parts.append("\(running) Running") }

        return parts.isEmpty ? "No sessions" : parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        settings.panelVisible.toggle()
        if settings.panelVisible {
            panel?.orderFront(nil)
        } else {
            panel?.orderOut(nil)
        }
        buildMenu(sessions: viewModel?.sessions ?? [])
    }

    @objc private func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Dock Settings"
        let debugLog = viewModel?.debugLog ?? DebugLog()
        window.contentView = NSHostingView(rootView: SettingsView(settings: settings, debugLog: debugLog))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func showAbout() {
        if let existing = aboutWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Claude Dock"
        window.contentView = NSHostingView(rootView: AboutView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
