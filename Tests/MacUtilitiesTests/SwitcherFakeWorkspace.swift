import AppKit
@testable import MacUtilities

/// Running apps and windows held in memory; records what the switcher asks of them and what it does to them.
final class SwitcherFakeWorkspace: SwitcherWorkspace {
    var runningApps: [SwitcherFakeApp] = []
    var recentBundleIdentifiers: [String] = []
    /// Listed for whichever app is asked.
    var windows: [SwitcherFakeWindow] = []
    var onBringToFront: (SwitcherFakeWindow) -> Void = { _ in }

    private(set) var runningAppQueryCount = 0
    private(set) var appsWithWindowsQueryCount = 0
    private(set) var windowQueryCount = 0

    var activatedBundleIdentifiers: [String] = []
    var quitBundleIdentifiers: [String] = []
    var hiddenBundleIdentifiers: [String] = []
    var raisedWindowIDs: [CGWindowID] = []
    private(set) var batchQuitCount = 0

    private(set) var onAppTerminated: ((pid_t) -> Void)?
    private(set) var onAppHiddenOrShown: (() -> Void)?

    /// test.app.0, test.app.1, ..., each with a window of the same number.
    init(itemCount: Int) {
        runningApps = (0..<itemCount).map { buildApp(index: $0) }
        recentBundleIdentifiers = runningApps.map { $0.bundleIdentifier }
        windows = (0..<itemCount).map { buildWindow(windowID: CGWindowID($0)) }
    }

    func buildApp(index: Int) -> SwitcherFakeApp {
        return SwitcherFakeApp(index: index, workspace: self)
    }

    func buildWindow(windowID: CGWindowID) -> SwitcherFakeWindow {
        return SwitcherFakeWindow(windowID: windowID, workspace: self)
    }

    func startObserving(onAppTerminated: @escaping (pid_t) -> Void, onAppHiddenOrShown: @escaping () -> Void) {
        self.onAppTerminated = onAppTerminated
        self.onAppHiddenOrShown = onAppHiddenOrShown
    }

    func stopObserving() {
        onAppTerminated = nil
        onAppHiddenOrShown = nil
    }

    func getRunningApps() -> [SwitcherApp] {
        runningAppQueryCount += 1
        return runningApps
    }

    func getRecentlyActivatedBundleIdentifiers() -> [String] {
        return recentBundleIdentifiers
    }

    func getAppsWithWindows(_ apps: [SwitcherApp]) -> [SwitcherApp] {
        appsWithWindowsQueryCount += 1
        return apps
    }

    func getFrontmostApp() -> SwitcherApp {
        return buildApp(index: 0)
    }

    func getWindows(of app: SwitcherApp) -> [SwitcherWindow] {
        windowQueryCount += 1
        return windows
    }

    /// Two apps asked to quit.
    func runBatchQuit() -> Int {
        batchQuitCount += 1
        return 2
    }
}

final class SwitcherFakeApp: SwitcherApp {
    var bundleIdentifier: String
    let processIdentifier: pid_t
    let name = "Test App"
    let icon: NSImage? = NSImage(size: NSSize(width: 68, height: 68))
    var isHidden = false

    private unowned let workspace: SwitcherFakeWorkspace

    init(index: Int, workspace: SwitcherFakeWorkspace) {
        bundleIdentifier = "test.app.\(index)"
        processIdentifier = pid_t(index)
        self.workspace = workspace
    }

    func activate() {
        workspace.activatedBundleIdentifiers.append(bundleIdentifier)
    }

    func hide() {
        workspace.hiddenBundleIdentifiers.append(bundleIdentifier)
    }

    func terminate() {
        workspace.quitBundleIdentifiers.append(bundleIdentifier)
    }
}

struct SwitcherFakeWindow: SwitcherWindow {
    let windowID: CGWindowID
    let title = "Test Window"
    unowned let workspace: SwitcherFakeWorkspace

    func bringToFront() {
        workspace.raisedWindowIDs.append(windowID)
        workspace.onBringToFront(self)
    }
}
