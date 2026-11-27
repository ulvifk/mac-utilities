import AppKit

/// A settings window that is never shown and has focus while the test says so.
final class SwitcherTestSettingsWindow: NSWindow {
    var hasFocus = true

    override var isKeyWindow: Bool {
        return hasFocus
    }
}
