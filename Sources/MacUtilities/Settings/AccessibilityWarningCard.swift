import SwiftUI

private let accessibilityPaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
private let warningSymbolSize: CGFloat = 30

/// Shown while the event tap is not running: it needs Accessibility and is only created at launch, so no shortcut works until the app is
/// allowed and reopened. Once allowed, the card offers the reopening.
struct AccessibilityWarningCard: View {
    let isAccessibilityAllowed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: warningSymbolSize))
            if isAccessibilityAllowed {
                buildContent(
                    title: "Reopen MacUtilities",
                    explanation: "Accessibility access is allowed, but the shortcuts only start when MacUtilities launches.",
                    button: Button("Reopen MacUtilities") { relaunch() }
                )
            } else {
                buildContent(
                    title: "Allow Accessibility access",
                    explanation: "MacUtilities sees your keyboard shortcuts through Accessibility. Until it is allowed, none of them work. Allow MacUtilities in Privacy & Security, then come back here to reopen it.",
                    button: Button("Open Accessibility Settings") { NSWorkspace.shared.open(accessibilityPaneURL) }
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func buildContent(title: String, explanation: String, button: some View) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(explanation)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            button
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
        }
    }
}

/// A shell waits for this process to end, then opens the app again: opened while it still runs, it would only come to the front. The pid and
/// the path go in as arguments, so the shell never reads the path as code.
private func relaunch() {
    let reopening = Process()
    reopening.executableURL = URL(fileURLWithPath: "/bin/sh")
    reopening.arguments = [
        "-c", "while kill -0 \"$1\"; do sleep 0.2; done; open \"$2\"",
        "sh", String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath,
    ]

    try! reopening.run()
    terminateApplication()
}
