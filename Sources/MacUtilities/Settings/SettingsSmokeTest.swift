import AppKit

/// SETTINGS_SMOKE_TEST=1: opens the settings window, captures every pane to /tmp/settings-<pane>-smoke.png one second apart and exits. Nothing
/// activates the app here, so the window is ordered front by force, and it floats, so a click in another app meanwhile does not cover it.
func runSettingsSmokeTestIfRequested(controller: AppController) {
    guard ProcessInfo.processInfo.environment["SETTINGS_SMOKE_TEST"] != nil else { return }

    let paneIdentifiers = [generalPaneIdentifier] + controller.features.map { $0.identifier }

    controller.openSettings()
    controller.settingsWindow.level = .floating
    controller.settingsWindow.orderFrontRegardless()
    for (index, paneIdentifier) in paneIdentifiers.enumerated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index)) {
            controller.settingsWindow.showPane(paneIdentifier)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(index)) {
            let window = controller.settingsWindow!
            print("smoke: pane=\(paneIdentifier) title=\(window.title) frame=\(window.frame) visible=\(window.isVisible) key=\(window.isKeyWindow)")
            writeCapture(around: window, path: "/tmp/settings-\(paneIdentifier)-smoke.png")
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(paneIdentifiers.count)) {
        exit(0)
    }
}
