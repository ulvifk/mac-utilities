import Darwin

/// The running apps and their windows as the system has them, and the changes to them the switcher follows.
protocol SwitcherWorkspace {
    /// From here on the recently activated apps are tracked, and quit apps and apps hidden or shown are reported, on the main thread.
    func startObserving(onAppTerminated: @escaping (pid_t) -> Void, onAppHiddenOrShown: @escaping () -> Void)
    func stopObserving()
    /// Regular apps with a bundle identifier, in the order the workspace lists them.
    func getRunningApps() -> [SwitcherApp]
    /// Process identifiers of the processes active since observing last started: the frontmost one at that moment, then each one activated
    /// since; most recent first. Processes that quit are left out.
    func getRecentlyActiveProcessIdentifiers() -> [pid_t]
    /// The given apps with a window on any Space, in the given order.
    func getAppsWithWindows(_ apps: [SwitcherApp]) -> [SwitcherApp]
    func getFrontmostApp() -> SwitcherApp
    /// The app's switchable windows on the current Space, minimized ones included, frontmost first.
    func getWindows(of app: SwitcherApp) -> [SwitcherWindow]
    /// Asks the apps Batch Quit targets to quit; returns how many were asked.
    func runBatchQuit() -> Int
}
