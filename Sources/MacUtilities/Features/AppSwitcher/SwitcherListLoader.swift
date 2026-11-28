import AppKit

/// Loads what the switcher lists from the workspace, wrapped to the panel width; the switcher and its preview list the same way.
final class SwitcherListLoader {
    private let workspace: SwitcherWorkspace
    private let screen: SwitcherScreen
    private let whitelistStore: WhitelistStore
    private let panelWidthStore: PanelWidthStore
    private let dockBadgeStore: DockBadgeStore

    init(workspace: SwitcherWorkspace, screen: SwitcherScreen, whitelistStore: WhitelistStore, panelWidthStore: PanelWidthStore,
         dockBadgeStore: DockBadgeStore) {
        self.workspace = workspace
        self.screen = screen
        self.whitelistStore = whitelistStore
        self.panelWidthStore = panelWidthStore
        self.dockBadgeStore = dockBadgeStore
    }

    /// The running apps by recency, with their Dock badges; while the filter is on only the whitelisted ones, unless none of them has a window.
    func loadAppList() -> SwitcherList {
        let apps = getRunningAppsByRecency()
        let whitelistedApps = getWhitelistedApps(apps)
        let listedApps = whitelistedApps.isEmpty ? apps : whitelistedApps
        let items = SwitcherItems.apps(listedApps, whitelistOnly: !whitelistedApps.isEmpty)

        return SwitcherList(items: items, cellsPerRow: getCellsPerRow(for: items), appBadges: getAppBadges(listedApps))
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

    /// [processIdentifier] -> the badge the Dock shows for the app's bundle, for the apps that have one; each instance of an app gets the one
    /// badge of its bundle. Empty while the badges are switched off, without asking the Dock.
    private func getAppBadges(_ apps: [SwitcherApp]) -> [pid_t: String] {
        if !dockBadgeStore.showsBadges { return [:] }

        let dockBadges = workspace.getDockBadges()
        var appBadges: [pid_t: String] = [:]
        for app in apps {
            guard let bundleURL = app.bundleURL else { continue }
            guard let badge = dockBadges[bundleURL] else { continue }
            appBadges[app.processIdentifier] = badge
        }

        return appBadges
    }

    /// Empty while the filter is off.
    private func getWhitelistedApps(_ apps: [SwitcherApp]) -> [SwitcherApp] {
        if !whitelistStore.isFilterEnabled { return [] }

        let whitelist = whitelistStore.getWhitelist()
        return apps.filter { whitelist.contains($0.bundleIdentifier) }
    }
}
