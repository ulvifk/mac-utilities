import AppKit
import SwiftUI
@testable import MacUtilities

/// A feature's settings pane that records every window reported to it, nil when it stopped being visible.
final class WindowRecordingPane {
    var reportedWindows: [NSWindow?] = []

    var pane: SettingsPane {
        return SettingsPane(
            identifier: "test-feature", title: "Test Feature", symbolName: "square", gradient: Gradient(colors: [.blue]),
            warning: nil, view: AnyView(EmptyView()), onWindowChanged: { [unowned self] window in self.reportedWindows.append(window) }
        )
    }
}
