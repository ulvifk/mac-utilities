import AppKit
import ApplicationServices

func getRegularRunningApps() -> [NSRunningApplication] {
    return NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
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
