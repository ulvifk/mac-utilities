/// The switcher from the first switching press until its list is loaded, which happens on the next turn of the main queue. Presses arriving
/// meanwhile only move the selection it opens with, and Cmd released meanwhile activates that selection without showing the panel.
final class SwitcherOpening {
    /// Set by the first press: Cmd+` lists the frontmost app's windows, Cmd+Tab the apps.
    let listsWindows: Bool
    /// How far the selection moves from the first item once the list is loaded; e.g. Tab, Tab, Shift+Tab -> 1.
    private(set) var pendingAdvance = 0
    private(set) var isCommandReleased = false

    init(listsWindows: Bool) {
        self.listsWindows = listsWindows
    }

    /// Either switching shortcut counts, whichever list the first press opens.
    func addPress(backward: Bool) {
        pendingAdvance += backward ? -1 : 1
    }

    func releaseCommand() {
        isCommandReleased = true
    }
}
