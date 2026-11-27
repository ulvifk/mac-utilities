import AppKit

/// Loads what the switcher lists from the workspace, wrapped to the panel width; the switcher and its preview list the same way.
final class SwitcherListLoader {
    private let workspace: SwitcherWorkspace
    private let screen: SwitcherScreen
    private let whitelistStore: WhitelistStore
    private let panelWidthStore: PanelWidthStore

    init(workspace: SwitcherWorkspace, screen: SwitcherScreen, whitelistStore: WhitelistStore, panelWidthStore: PanelWidthStore) {
        self.workspace = workspace
        self.screen = screen
        self.whitelistStore = whitelistStore
        self.panelWidthStore = panelWidthStore
    }

    /// The recent running apps; while the filter is on only the whitelisted ones, unless none of them has a window.
    func loadAppList() -> SwitcherList {
        let recentApps = getRecentRunningApps()
        let whitelistedApps = getWhitelistedApps(recentApps)
        let items = whitelistedApps.isEmpty ? SwitcherItems.apps(recentApps, whitelistOnly: false) : .apps(whitelistedApps, whitelistOnly: true)

        return SwitcherList(items: items, cellsPerRow: getCellsPerRow(for: items))
    }

    /// Whatever the whitelist and the filter say.
    func loadWindowList(of app: SwitcherApp) -> SwitcherList {
        let items = SwitcherItems.windows(workspace.getWindows(of: app), of: app)

        return SwitcherList(items: items, cellsPerRow: getCellsPerRow(for: items))
    }

    /// Regular running apps with a window: the ones activated since the switcher started, most recent first, then the rest in the order the
    /// workspace lists them, so an app launched in the background is listed too. E.g. running [A, B, C], activated [C, A] -> [C, A, B].
    func getRecentRunningApps() -> [SwitcherApp] {
        let runningApps = workspace.getRunningApps()
        let recentIdentifiers = workspace.getRecentlyActivatedBundleIdentifiers()
        var appsByIdentifier: [String: SwitcherApp] = [:]
        for app in runningApps {
            appsByIdentifier[app.bundleIdentifier] = app
        }

        var recentApps: [SwitcherApp] = []
        for bundleIdentifier in recentIdentifiers {
            guard let app = appsByIdentifier[bundleIdentifier] else { continue }
            recentApps.append(app)
        }

        let recentIdentifierSet = Set(recentIdentifiers)
        let neverActivatedApps = runningApps.filter { !recentIdentifierSet.contains($0.bundleIdentifier) }

        return workspace.getAppsWithWindows(recentApps + neverActivatedApps)
    }

    /// For the list's items at the panel width as it is now: the remembered one, or the default share of the screen until the edge has been
    /// dragged once.
    func getCellsPerRow(for items: SwitcherItems) -> Int {
        let screenSize = screen.visibleSize
        let panelWidth = panelWidthStore.width ?? screenSize.width * defaultPanelWidthFraction

        return getCellMetrics(listingWindows: items.isListingWindows).getCellsPerRow(itemCount: items.count, panelWidth: panelWidth, screenSize: screenSize)
    }

    /// Empty while the filter is off.
    private func getWhitelistedApps(_ apps: [SwitcherApp]) -> [SwitcherApp] {
        if !whitelistStore.isFilterEnabled { return [] }

        let whitelist = whitelistStore.getWhitelist()
        return apps.filter { whitelist.contains($0.bundleIdentifier) }
    }
}
