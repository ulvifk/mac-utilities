import AppKit
import SwiftUI

/// The settings window, kept around across closes. The app is an accessory, so opening it activates the app; the system may turn that down and
/// leave the window behind the frontmost app's, so it is also ordered front regardless.
final class SettingsWindow: NSWindow {
    init(rootView: SettingsView) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)

        title = "MacUtilities Settings"
        isReleasedWhenClosed = false
        contentViewController = NSHostingController(rootView: rootView)
        center()
    }

    func open() {
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
}
