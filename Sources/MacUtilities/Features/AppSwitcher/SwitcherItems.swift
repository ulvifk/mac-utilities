/// What the switcher lists: apps, or the windows of one app.
enum SwitcherItems {
    /// With whitelistOnly, only whitelisted apps are listed; it is false while the filter is on but none of them has a window, so every app is.
    case apps([SwitcherApp], whitelistOnly: Bool)
    /// The app is the one whose windows are listed, kept with them so the list knows it even with no window left to ask.
    case windows([SwitcherWindow], of: SwitcherApp)

    var count: Int {
        switch self {
        case .apps(let apps, _): return apps.count
        case .windows(let windows, _): return windows.count
        }
    }

    var isListingWindows: Bool {
        if case .windows = self { return true }
        return false
    }

    var isWhitelistOnly: Bool {
        if case .apps(_, whitelistOnly: true) = self { return true }
        return false
    }
}
