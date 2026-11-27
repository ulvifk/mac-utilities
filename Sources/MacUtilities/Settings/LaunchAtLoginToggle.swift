import ServiceManagement
import SwiftUI

/// Switches the app's login item on or off; macOS may hold it under Login Items for approval, which shows here with a button there.
struct LaunchAtLoginToggle: View {
    @ObservedObject var state: GeneralSettingsState

    var body: some View {
        Toggle("Launch at login", isOn: buildLaunchesAtLoginBinding())

        if state.loginItemStatus == .requiresApproval {
            LabeledContent {
                Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
            } label: {
                Text("Waiting for approval under Login Items")
            }
        }
    }

    private func buildLaunchesAtLoginBinding() -> Binding<Bool> {
        return Binding(
            get: { state.loginItemStatus.isRegistered },
            set: { state.setLaunchesAtLogin($0) }
        )
    }
}
