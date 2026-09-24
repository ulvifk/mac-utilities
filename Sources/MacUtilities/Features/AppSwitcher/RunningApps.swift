import AppKit
import ApplicationServices

/// Finder is a regular app too, but quitting it closes every Finder window and the desktop icons.
private let finderBundleIdentifier = "com.apple.finder"

func getRegularRunningApps() -> [NSRunningApplication] {
    return NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
}

func getAppName(_ app: NSRunningApplication) -> String {
    return app.localizedName ?? app.bundleIdentifier!
}

/// A normal quit, so an app with unsaved changes shows its dialog and stays running. The switcher itself is an accessory app, never a regular one.
func quitRegularAppsNotIn(whitelist: Set<String>) {
    for app in getRegularRunningApps() {
        guard let bundleIdentifier = app.bundleIdentifier else { continue }
        if bundleIdentifier == finderBundleIdentifier { continue }
        if whitelist.contains(bundleIdentifier) { continue }
        app.terminate()
    }
}

/// One AX round trip costs 10-20ms, so ask every app at once. Each iteration writes its own index, so no lock is needed.
func getAppsWithWindows(_ apps: [NSRunningApplication]) -> [NSRunningApplication] {
    var windowed = [Bool](repeating: false, count: apps.count)

    windowed.withUnsafeMutableBufferPointer { answers in
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            answers[index] = hasWindows(apps[index])
        }
    }

    return zip(apps, windowed).filter { $0.1 }.map { $0.0 }
}

/// Minimized windows count. The short messaging timeout keeps a hung app from stalling the event tap.
func hasWindows(_ app: NSRunningApplication) -> Bool {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.1)

    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) != .success { return false }

    guard let windows = value as? [AXUIElement] else { return false }

    return !windows.isEmpty
}
