import AppKit
import ApplicationServices

private typealias GetWindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

/// Dialogs count, so a settings window can be switched to; palettes, the desktop and other special windows do not.
private let switchableSubroles: Set<String> = [kAXStandardWindowSubrole, kAXDialogSubrole]

/// The app's windows on the current Space, minimized ones included, frontmost first as the accessibility API lists them. The short messaging
/// timeout keeps a hung app from stalling the switcher.
func getWindows(of app: NSRunningApplication) -> [AppWindow] {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.1)

    guard let windowElements = getAttribute(element, kAXWindowsAttribute) as? [AXUIElement] else { return [] }

    var windows: [AppWindow] = []
    for windowElement in windowElements {
        if !isSwitchable(windowElement) { continue }

        windows.append(AppWindow(app: app, element: windowElement, windowID: getWindowID(windowElement), title: getTitle(windowElement, app: app)))
    }

    return windows
}

private func isSwitchable(_ window: AXUIElement) -> Bool {
    guard let subrole = getAttribute(window, kAXSubroleAttribute) as? String else { return false }

    return switchableSubroles.contains(subrole)
}

private func getTitle(_ window: AXUIElement, app: NSRunningApplication) -> String {
    let title = getAttribute(window, kAXTitleAttribute) as? String ?? ""
    if title.isEmpty { return getAppName(app) }

    return title
}

/// The accessibility API has no public way from a window to its window server id, which the thumbnail capture needs. _AXUIElementGetWindow is
/// not in the SDK but still in the dylib; when it fails the id stays 0 and the window keeps its app's icon.
private func getWindowID(_ window: AXUIElement) -> CGWindowID {
    let symbol = dlsym(dlopen(nil, RTLD_NOW), "_AXUIElementGetWindow")!
    let getWindow = unsafeBitCast(symbol, to: GetWindowID.self)

    var windowID: CGWindowID = 0
    _ = getWindow(window, &windowID)

    return windowID
}

private func getAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

    return value
}
