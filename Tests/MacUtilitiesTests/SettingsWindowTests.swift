import AppKit
import Testing
@testable import MacUtilities

/// The wiring of the real settings window, which SettingsPaneSelectionTests leaves out: a feature's pane carries the feature's name and
/// reports the window to that feature, and the window's delegate is the pane selection. The window is never ordered front; a delegate
/// callback is played instead.
@MainActor
struct SettingsWindowTests {
    @Test
    func featurePaneReportsTheWindowToItsFeature() {
        _ = NSApplication.shared.setActivationPolicy(.prohibited)
        let feature = WindowRecordingFeature()
        let controller = AppController(features: [feature], preferences: buildPreferences(disabledFeatures: []), eventTap: FakeEventTap(), interface: FakeAppInterface())
        let window = SettingsWindow(controller: controller)

        window.showPane(feature.identifier)
        #expect(window.title == feature.displayName, "The window's title did not follow the selected pane")
        #expect(feature.reportedWindows == [nil], "A window that was never opened was reported to the feature")

        window.delegate!.windowDidDeminiaturize!(Notification(name: NSWindow.didDeminiaturizeNotification, object: window))
        #expect(feature.reportedWindows == [nil, window], "The window on screen was not reported to the feature of the selected pane")
        #expect(!window.isVisible)
    }
}
