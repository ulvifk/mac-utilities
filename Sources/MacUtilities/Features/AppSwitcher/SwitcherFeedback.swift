import AppKit

/// What a shortcut pressed in the switcher just did, said for a moment in the hint band.
enum SwitcherFeedback {
    case addedToWhitelist
    case removedFromWhitelist
    case showingWhitelist
    case showingAllApps
    /// The filter is on, but no whitelisted app has a window to list, so every app is.
    case noWhitelistedApps
    case hidden
    case quittingApp(name: String)
    case quittingApps(count: Int)

    var text: String {
        switch self {
        case .addedToWhitelist: return "Added to Whitelist"
        case .removedFromWhitelist: return "Removed from Whitelist"
        case .showingWhitelist: return "Showing Whitelist"
        case .showingAllApps: return "Showing All Apps"
        case .noWhitelistedApps: return "No Whitelisted Apps Open"
        case .hidden: return "Hidden"
        case .quittingApp(let name): return "Quitting \(name)"
        case .quittingApps(let count): return getQuittingAppsText(count: count)
        }
    }

    var symbolName: String {
        switch self {
        case .addedToWhitelist: return "checkmark"
        case .removedFromWhitelist: return "minus"
        case .showingWhitelist: return whitelistSymbolName
        case .showingAllApps: return "square.grid.2x2"
        case .noWhitelistedApps: return whitelistSymbolName
        case .hidden: return "eye.slash"
        case .quittingApp: return "xmark"
        case .quittingApps: return "xmark"
        }
    }

    /// Green like the Whitelist capsule when the whitelist gained an app or is what is listed now, else the hints' dark.
    var color: NSColor {
        switch self {
        case .addedToWhitelist: return badgeColor
        case .showingWhitelist: return badgeColor
        default: return hintTrayColor
        }
    }

    private func getQuittingAppsText(count: Int) -> String {
        if count == 0 { return "No Apps to Quit" }
        if count == 1 { return "Quitting 1 App" }

        return "Quitting \(count) Apps"
    }
}
