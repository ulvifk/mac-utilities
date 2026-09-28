import AppKit
import ApplicationServices

/// One window of an app as the accessibility API hands it out, with the id the window server knows it by.
struct AppWindow {
    let app: NSRunningApplication
    let element: AXUIElement
    let windowID: CGWindowID
    /// The window's own title, or its app's name for an untitled window.
    let title: String

    /// Unminimizes the window, raises it above the app's other windows and activates the app without bringing those along.
    func bringToFront() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        app.activate(options: [])
    }
}
