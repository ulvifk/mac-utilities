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

    /// The running apps by recency; while the filter is on only the whitelisted ones, unless none of them has a window.
    func loadAppList() -> SwitcherList {
        let apps = getRunningAppsByRecency()
        let whitelistedApps = getWhitelistedApps(apps)
        let items = whitelistedApps.isEmpty ? SwitcherItems.apps(apps, whitelistOnly: false) : .apps(whitelistedApps, whitelistOnly: true)

        return SwitcherList(items: items, cellsPerRow: getCellsPerRow(for: items))
    }

    /// Whatever the whitelist and the filter say.
    func loadWindowList(of app: SwitcherApp) -> SwitcherList {
        let items = SwitcherItems.windows(workspace.getWindows(of: app), of: app)

        return SwitcherList(items: items, cellsPerRow: getCellsPerRow(for: items))
    }

    /// Regular running apps with a window, most recently active first, for the switcher to list. Each running process has its own place:
    /// - first the processes the workspace tracks (the one frontmost when observing started, then each one activated since), most recent first
    /// - then the untracked ones, such as apps launched in the background, in the order the workspace lists them
    /// E.g. running [A, B, C, D], tracked [C, a menu bar app, A] -> [C, A, B, D].
    func getRunningAppsByRecency() -> [SwitcherApp] {
        let trackedProcessIdentifiers = workspace.getRecentlyActiveProcessIdentifiers()
        var positionsInTracker: [pid_t: Int] = [:] // [processIdentifier] -> 0 for the most recent
        for (position, processIdentifier) in trackedProcessIdentifiers.enumerated() {
            positionsInTracker[processIdentifier] = position
        }
        let untrackedPosition = trackedProcessIdentifiers.count

        let appsByRecency = workspace.getRunningApps().enumerated().sorted { first, second in
            let firstKey = (positionsInTracker[first.element.processIdentifier] ?? untrackedPosition, first.offset)
            let secondKey = (positionsInTracker[second.element.processIdentifier] ?? untrackedPosition, second.offset)
            return firstKey < secondKey
        }

        return workspace.getAppsWithWindows(appsByRecency.map { $0.element })
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
