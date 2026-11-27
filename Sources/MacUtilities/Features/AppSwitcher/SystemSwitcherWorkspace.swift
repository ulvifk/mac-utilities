import AppKit

/// The switcher's apps and windows from NSWorkspace, the window server and the accessibility API. Every app it hands out is a RunningApp.
final class SystemSwitcherWorkspace: SwitcherWorkspace {
    private let batchQuitStore: BatchQuitStore
    private let tracker = RecentAppsTracker()
    private var observers: [NSObjectProtocol] = []

    init(batchQuitStore: BatchQuitStore) {
        self.batchQuitStore = batchQuitStore
    }

    func startObserving(onAppTerminated: @escaping (pid_t) -> Void, onAppHiddenOrShown: @escaping () -> Void) {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        tracker.start()
        observers.append(notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { notification in
            let app = notification.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
            onAppTerminated(app.processIdentifier)
        })
        for name in [NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in onAppHiddenOrShown() })
        }
    }

    func stopObserving() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers = []
        tracker.stop()
    }

    func getRunningApps() -> [SwitcherApp] {
        var apps: [SwitcherApp] = []
        for app in getRegularRunningApps() {
            if app.bundleIdentifier == nil { continue }
            apps.append(RunningApp(runningApplication: app))
        }

        return apps
    }

    func getRecentlyActiveProcessIdentifiers() -> [pid_t] {
        return tracker.processIdentifiers
    }

    func getAppsWithWindows(_ apps: [SwitcherApp]) -> [SwitcherApp] {
        return MacUtilities.getAppsWithWindows(apps)
    }

    func getFrontmostApp() -> SwitcherApp {
        return RunningApp(runningApplication: NSWorkspace.shared.frontmostApplication!)
    }

    func getWindows(of app: SwitcherApp) -> [SwitcherWindow] {
        return MacUtilities.getWindows(of: app as! RunningApp)
    }

    func runBatchQuit() -> Int {
        return MacUtilities.runBatchQuit(batchQuitStore)
    }
}
