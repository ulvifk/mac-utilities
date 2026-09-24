import ServiceManagement
import SwiftUI

/// Registers the app as a login item through SMAppService; macOS lists it under General > Login Items.
struct LaunchAtLoginToggle: View {
    var body: some View {
        Toggle("Launch at login", isOn: buildLaunchesAtLoginBinding())
    }

    private func buildLaunchesAtLoginBinding() -> Binding<Bool> {
        return Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { setLaunchesAtLogin($0) }
        )
    }

    private func setLaunchesAtLogin(_ enabled: Bool) {
        if enabled {
            try! SMAppService.mainApp.register()
        } else {
            try! SMAppService.mainApp.unregister()
        }
    }
}
