import AppKit
import SwiftUI
@testable import MacUtilities

/// A feature that records every settings window reported to it, nil when its pane stopped being visible.
final class WindowRecordingFeature: Feature {
    let identifier = "window-recording"
    let displayName = "Window Recording"
    let summary = "Records the settings window reported to it."
    let iconSymbolName = "square"
    let iconGradient = Gradient(colors: [.blue])

    private(set) var reportedWindows: [NSWindow?] = []

    func buildSettingsSections() -> AnyView {
        return AnyView(EmptyView())
    }

    func settingsWindowChanged(_ window: NSWindow?) {
        reportedWindows.append(window)
    }
}
