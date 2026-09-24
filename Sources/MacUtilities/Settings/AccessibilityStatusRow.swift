import SwiftUI

private let accessibilityPaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

/// Green or red dot for the Accessibility grant, re-checked whenever the window comes back to the front, and a button to the pane that grants it.
struct AccessibilityStatusRow: View {
    @ObservedObject var state: GeneralSettingsState

    var body: some View {
        LabeledContent {
            Button("Open Accessibility Settings") { NSWorkspace.shared.open(accessibilityPaneURL) }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(state.isAccessibilityTrusted ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(state.isAccessibilityTrusted ? "Accessibility granted" : "Accessibility not granted")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            state.refreshAccessibilityTrust()
        }
    }
}
