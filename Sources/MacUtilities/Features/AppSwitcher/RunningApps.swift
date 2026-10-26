import AppKit
import ApplicationServices

private let finderBundleIdentifier = "com.apple.finder"

func getRegularRunningApps() -> [NSRunningApplication] {
    return NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
}

func getAppName(_ app: NSRunningApplication) -> String {
    return app.localizedName ?? app.bundleIdentifier!
}

/// Finder is a regular app too, but quitting it closes every Finder window and the desktop icons, so Batch Quit neither lists nor quits it.
func isBatchQuittable(_ app: NSRunningApplication) -> Bool {
    return app.bundleIdentifier != finderBundleIdentifier
}

/// A normal quit, so an app with unsaved changes shows its dialog and stays running. The switcher itself is an accessory app, never a regular one.
/// The quit apps' background jobs are removed once they have exited, so none stays in the Dock as running in the background.
/// Returns how many apps were asked to quit.
@discardableResult
func runBatchQuit(_ batchQuitStore: BatchQuitStore) -> Int {
    var quitApps: [NSRunningApplication] = []

    for app in getRegularRunningApps() {
        guard let bundleIdentifier = app.bundleIdentifier else { continue }
        if !isBatchQuittable(app) { continue }
        if !batchQuitStore.isBatchQuitTarget(bundleIdentifier) { continue }
        app.terminate()
        quitApps.append(app)
    }

    removeBackgroundJobs(of: quitApps)

    return quitApps.count
}

/// The apps with a window on any Space, so the list is the same on every Space, as with the native switcher. One AX round trip costs
/// 10-20ms, so ask every app at once. Each iteration writes its own index, so no lock is needed.
func getAppsWithWindows(_ apps: [NSRunningApplication]) -> [NSRunningApplication] {
    let processesWithOpenWindows = getProcessesWithOpenWindowsOnAnySpace()
    var windowed = [Bool](repeating: false, count: apps.count)

    windowed.withUnsafeMutableBufferPointer { answers in
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            answers[index] = hasWindows(apps[index], processesWithOpenWindows: processesWithOpenWindows)
        }
    }

    return zip(apps, windowed).filter { $0.1 }.map { $0.0 }
}

/// Minimized windows and hidden apps' windows count too. The window server misses those; the accessibility API lists them on every Space,
/// so it is asked only for an app without an open window.
private func hasWindows(_ app: NSRunningApplication, processesWithOpenWindows: Set<pid_t>) -> Bool {
    if processesWithOpenWindows.contains(app.processIdentifier) { return true }

    return hasAccessibilityWindows(app)
}

/// The windows on the current Space, and minimized windows and hidden apps' windows on any Space. The short messaging timeout keeps a hung
/// app from stalling the event tap.
private func hasAccessibilityWindows(_ app: NSRunningApplication) -> Bool {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.1)

    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) != .success { return false }

    guard let windows = value as? [AXUIElement] else { return false }

    return !windows.isEmpty
}
