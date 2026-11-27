import AppKit
import ApplicationServices

/// One window of an app as the accessibility API hands it out.
struct AppWindow: SwitcherWindow {
    let runningApp: RunningApp
    let element: AXUIElement
    let windowID: CGWindowID
    let title: String

    var app: SwitcherApp {
        return runningApp
    }

    func bringToFront() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        runningApp.runningApplication.activate(options: [])
    }
}
