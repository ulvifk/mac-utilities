import AppKit
import ApplicationServices
import os

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
        let unminimizeResult = AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        let makeMainResult = AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        let raiseResult = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        let didActivate = runningApp.runningApplication.activate(options: [])

        if raiseResult != .success {
            Logger.appSwitcher.error("Window of \(runningApp.name, privacy: .public) not raised: unminimize \(unminimizeResult.rawValue, privacy: .public), make main \(makeMainResult.rawValue, privacy: .public), raise \(raiseResult.rawValue, privacy: .public)")
        }
        if !didActivate {
            Logger.appSwitcher.error("\(runningApp.name, privacy: .public) (\(runningApp.bundleIdentifier, privacy: .public)) refused to activate for its window")
        }
    }
}
