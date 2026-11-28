import Darwin

/// What the switcher lists: apps, or the windows of one app.
enum SwitcherItems {
    /// With whitelistOnly, only whitelisted apps are listed; it is false while the filter is on but none of them has a window, so every app is.
    /// badges: [processIdentifier] -> the text of the app's Dock badge, read when the list was loaded; only listed apps with a badge.
    case apps([SwitcherApp], whitelistOnly: Bool, badges: [pid_t: String])
    /// The app is the one whose windows are listed, held once for the list rather than on each window.
    case windows([SwitcherWindow], of: SwitcherApp)

    var count: Int {
        switch self {
        case .apps(let apps, _, _): return apps.count
        case .windows(let windows, _): return windows.count
        }
    }

    var isListingWindows: Bool {
        if case .windows = self { return true }
        return false
    }

    var isWhitelistOnly: Bool {
        if case .apps(_, whitelistOnly: true, _) = self { return true }
        return false
    }
}
