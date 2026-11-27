import AppKit

/// Which pane the settings window shows, and what follows from it: the window's title is the pane's, and the pane is told the window while
/// the window is on screen and shows it, nil otherwise, so a feature can place a live preview beside it. As the window's delegate it follows
/// the window closing, being miniaturized and restored, and moving.
final class SettingsPaneSelection: NSObject, NSWindowDelegate {
    private let panes: [SettingsPane]
    private unowned let window: NSWindow

    private var selectedPaneIdentifier: String
    private var isWindowVisible = false

    /// Starts on the first pane, with the window not shown yet.
    init(panes: [SettingsPane], window: NSWindow) {
        self.panes = panes
        self.window = window
        selectedPaneIdentifier = panes[0].identifier
    }

    func selectPane(_ paneIdentifier: String) {
        if selectedPaneIdentifier != paneIdentifier {
            getPane(selectedPaneIdentifier).onWindowChanged(nil)
            selectedPaneIdentifier = paneIdentifier
            getPane(paneIdentifier).onWindowChanged(isWindowVisible ? window : nil)
        }

        window.title = getPane(paneIdentifier).title
    }

    func setWindowVisible(_ isVisible: Bool) {
        if isWindowVisible == isVisible { return }

        isWindowVisible = isVisible
        getPane(selectedPaneIdentifier).onWindowChanged(isVisible ? window : nil)
    }

    func windowWillClose(_ notification: Notification) {
        setWindowVisible(false)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        setWindowVisible(false)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        setWindowVisible(true)
    }

    /// Tells the visible pane again, so a preview beside the window follows it.
    func windowDidMove(_ notification: Notification) {
        reportWindowToVisiblePane()
    }

    func windowDidResize(_ notification: Notification) {
        reportWindowToVisiblePane()
    }

    private func reportWindowToVisiblePane() {
        if !isWindowVisible { return }

        getPane(selectedPaneIdentifier).onWindowChanged(window)
    }

    private func getPane(_ identifier: String) -> SettingsPane {
        return panes.first { $0.identifier == identifier }!
    }
}
