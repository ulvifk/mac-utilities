import SwiftUI

/// Launch at login and the Accessibility grant, both re-read whenever the window comes back to the front.
struct GeneralSettingsView: View {
    @StateObject private var state = GeneralSettingsState()

    var body: some View {
        Form {
            Section {
                LaunchAtLoginToggle(state: state)
                AccessibilityStatusRow(state: state)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            state.refresh()
        }
    }
}
