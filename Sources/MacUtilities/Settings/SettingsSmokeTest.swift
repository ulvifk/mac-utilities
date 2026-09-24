import AppKit

/// SETTINGS_SMOKE_TEST=1: opens the settings window, captures every tab to /tmp/settings-<tab>-smoke.png one second apart and exits. Nothing activates the app here, so the window is ordered front by force.
func runSettingsSmokeTestIfRequested(controller: AppController) {
    guard ProcessInfo.processInfo.environment["SETTINGS_SMOKE_TEST"] != nil else { return }

    let tabIdentifiers = [generalTabIdentifier] + controller.features.map { $0.identifier }

    controller.openSettings()
    controller.settingsWindow.orderFrontRegardless()
    for (index, tabIdentifier) in tabIdentifiers.enumerated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index)) {
            controller.selectedSettingsTabIdentifier = tabIdentifier
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(index)) {
            let window = controller.settingsWindow
            print("smoke: tab=\(tabIdentifier) frame=\(window.frame) visible=\(window.isVisible) key=\(window.isKeyWindow)")
            writeCapture(around: window, path: "/tmp/settings-\(tabIdentifier)-smoke.png")
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(tabIdentifiers.count)) {
        exit(0)
    }
}
