import AppKit
import SwiftUI

/// The settings window, kept around across closes. The app is an accessory, so opening it activates the app to bring the window to the front.
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
    }
}
