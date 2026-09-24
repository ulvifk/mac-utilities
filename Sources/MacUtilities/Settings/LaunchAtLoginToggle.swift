import ServiceManagement
import SwiftUI

/// Registers the app as a login item through SMAppService; macOS lists it under General > Login Items and may hold it there for approval.
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
            get: { isLaunchingAtLogin() },
            set: { state.setLaunchesAtLogin($0) }
        )
    }

    private func isLaunchingAtLogin() -> Bool {
        if state.loginItemStatus == .enabled { return true }
        if state.loginItemStatus == .requiresApproval { return true }
        return false
    }
}
