import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var viewModel: DockViewModel!
    private var settings: AppSettings!
    private var statusBarController: StatusBarController!
    private var hookManager = HookManager()
    private var opencodePluginManager = OpenCodePluginManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = AppSettings()

        // Install hooks if not already installed
        installHooksIfNeeded()
        installOpenCodePluginIfNeeded()

        viewModel = DockViewModel(settings: settings)

        let rootView = PanelRootView(viewModel: viewModel) { [weak self] width, height in
            self?.panel.updateSize(width: width, height: height)
        }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 40)

        panel = FloatingPanel(contentView: hostingView)

        if settings.panelVisible {
            panel.orderFrontRegardless()
        }

        statusBarController = StatusBarController(
            settings: settings,
            viewModel: viewModel,
            panel: panel
        )

        viewModel.onRefresh = { [weak self] in
            guard let self else { return }
            self.statusBarController.update(sessions: self.viewModel.sessions)
            self.syncPanelVisibility()
        }

        viewModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
    }

    private func installHooksIfNeeded() {
        let status = hookManager.checkStatus()
        switch status {
        case .installed:
            settings.hooksInstalled = true
        case .notInstalled, .outdated:
            do {
                try hookManager.install()
                settings.hooksInstalled = true
            } catch {
                settings.hooksInstalled = false
            }
        case .error:
            settings.hooksInstalled = false
        }
    }

    private func installOpenCodePluginIfNeeded() {
        let status = opencodePluginManager.checkStatus()
        switch status {
        case .installed:
            settings.opencodePluginInstalled = true
        case .notInstalled, .outdated:
            do {
                try opencodePluginManager.install()
                settings.opencodePluginInstalled = true
            } catch {
                settings.opencodePluginInstalled = false
            }
        case .notDetected, .error:
            settings.opencodePluginInstalled = false
        }
    }

    private func syncPanelVisibility() {
        if settings.panelVisible {
            if !panel.isVisible {
                panel.orderFront(nil)
            }
        } else {
            if panel.isVisible {
                panel.orderOut(nil)
            }
        }
    }
}
