import AppKit
import SwiftUI
import Testing
@testable import MacUtilities

/// When the settings window reports itself to the selected feature pane. The window is never ordered front; the tests play its delegate
/// callbacks and the opening instead.
@MainActor
struct SettingsPaneSelectionTests {
    private let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: true)
    private let feature = WindowRecordingPane()
    private let selection: SettingsPaneSelection

    init() {
        let general = SettingsPane(
            identifier: generalPaneIdentifier, title: "General", symbolName: "gearshape", gradient: Gradient(colors: [.gray]),
            warning: nil, view: AnyView(EmptyView()), onWindowChanged: { _ in }
        )
        selection = SettingsPaneSelection(panes: [general, feature.pane], window: window)
    }

    @Test
    func openingShowsTheSelectedPaneAndReselectingKeepsIt() {
        selection.selectPane(feature.pane.identifier)
        #expect(feature.reportedWindows == [nil], "A hidden window marked its pane visible")

        selection.setWindowVisible(true)
        #expect(feature.reportedWindows == [nil, window], "Opening did not pass the settings window")
        #expect(!window.isVisible)

        selection.selectPane(feature.pane.identifier)
        #expect(feature.reportedWindows == [nil, window], "Reselecting the pane reset its preview")
    }

    @Test
    func movingOrResizingKeepsThePaneVisible() {
        openOnFeaturePane()

        selection.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: window))
        selection.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: window))

        #expect(feature.reportedWindows == [window, window, window], "Moving or resizing hid the selected pane")
    }

    @Test
    func miniaturizingHidesThePaneAndRestoringShowsIt() {
        openOnFeaturePane()

        selection.windowDidMiniaturize(Notification(name: NSWindow.didMiniaturizeNotification, object: window))
        #expect(feature.reportedWindows == [window, nil], "Miniaturizing did not hide the selected pane")

        selection.windowDidDeminiaturize(Notification(name: NSWindow.didDeminiaturizeNotification, object: window))
        #expect(feature.reportedWindows == [window, nil, window], "Restoring did not mark the selected pane visible")
    }

    @Test
    func switchingPanesHidesTheOldOneAndShowsTheNewOne() {
        openOnFeaturePane()

        selection.selectPane(generalPaneIdentifier)
        #expect(feature.reportedWindows == [window, nil], "Leaving the pane did not hide feature settings")
        #expect(window.title == "General")

        selection.selectPane(feature.pane.identifier)
        #expect(feature.reportedWindows == [window, nil, window], "Entering the pane did not show feature settings")
        #expect(window.title == feature.pane.title, "Selecting the pane lost its title")
    }

    @Test
    func closingHidesThePaneAndReopeningShowsIt() {
        openOnFeaturePane()

        selection.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
        #expect(feature.reportedWindows == [window, nil], "Closing did not hide the selected pane")

        selection.setWindowVisible(true)
        #expect(feature.reportedWindows == [window, nil, window], "Reopening did not restore selected pane visibility")
    }

    @Test
    func movingAClosedWindowKeepsThePaneHidden() {
        openOnFeaturePane()
        selection.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))

        selection.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: window))
        selection.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: window))

        #expect(feature.reportedWindows == [window, nil], "Moving closed settings marked its pane visible")
    }

    /// Selects the feature's pane, opens the window and forgets the reports so far, leaving one: the window.
    private func openOnFeaturePane() {
        selection.selectPane(feature.pane.identifier)
        selection.setWindowVisible(true)
        feature.reportedWindows = [window]
    }
}
