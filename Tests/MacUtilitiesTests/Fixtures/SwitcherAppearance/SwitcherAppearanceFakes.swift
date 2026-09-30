import AppKit

// The production panel builds real AppKit views, but never orders a window onto the user's screen.
class NSPanel: AppKit.NSPanel {
    private var isShown = false

    override var isVisible: Bool { return isShown }
    override func orderFrontRegardless() { isShown = true }
    override func orderOut(_ sender: Any?) { isShown = false }
    override func center() {}
}

final class NSRunningApplication {
    let bundleIdentifier: String? = "test.app"
    let localizedName: String? = "Test App"
    var isHidden = false
    let icon: NSImage? = NSImage(size: NSSize(width: 68, height: 68))
}

struct AppWindow {
    let windowID: CGWindowID
    let app = NSRunningApplication()
    let title = "Test Window"
}

final class GlassStore {
    var isFrosted = false
    var darkness: CGFloat = 0.14
}
