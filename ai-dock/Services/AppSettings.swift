import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class AppSettings {
    var panelVisible: Bool {
        didSet { UserDefaults.standard.set(panelVisible, forKey: "panelVisible") }
    }

    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    var debugLogging: Bool {
        didSet { UserDefaults.standard.set(debugLogging, forKey: "debugLogging") }
    }

    var hooksInstalled: Bool {
        didSet { UserDefaults.standard.set(hooksInstalled, forKey: "hooksInstalled") }
    }

    var opencodePluginInstalled: Bool {
        didSet { UserDefaults.standard.set(opencodePluginInstalled, forKey: "opencodePluginInstalled") }
    }

    var opencodeFinishedVisibilitySeconds: Int {
        didSet { UserDefaults.standard.set(opencodeFinishedVisibilitySeconds, forKey: "opencodeFinishedVisibilitySeconds") }
    }

    var opencodeTerminatedCleanupSeconds: Int {
        didSet { UserDefaults.standard.set(opencodeTerminatedCleanupSeconds, forKey: "opencodeTerminatedCleanupSeconds") }
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "panelVisible": true,
            "notificationsEnabled": true,
            "launchAtLogin": false,
            "debugLogging": false,
            "hooksInstalled": false,
            "opencodePluginInstalled": false,
            "opencodeFinishedVisibilitySeconds": 20,
            "opencodeTerminatedCleanupSeconds": 120,
        ])
        self.panelVisible = defaults.bool(forKey: "panelVisible")
        self.notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.debugLogging = defaults.bool(forKey: "debugLogging")
        self.hooksInstalled = defaults.bool(forKey: "hooksInstalled")
        self.opencodePluginInstalled = defaults.bool(forKey: "opencodePluginInstalled")
        self.opencodeFinishedVisibilitySeconds = defaults.integer(forKey: "opencodeFinishedVisibilitySeconds")
        self.opencodeTerminatedCleanupSeconds = defaults.integer(forKey: "opencodeTerminatedCleanupSeconds")
    }

    private func updateLoginItem() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // Silently ignore — sandboxing or entitlement issues
        }
    }
}
