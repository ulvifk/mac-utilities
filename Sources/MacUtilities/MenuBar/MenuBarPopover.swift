import AppKit
import SwiftUI

/// The popover under the menu bar item, drawn as Liquid Glass. The app is an accessory, so showing it activates the app: only then does the
/// popover take clicks and close on Esc or a click elsewhere. The cooperative activate() is turned down even right after a click on the item,
/// hence the forceful one.
final class MenuBarPopover: NSPopover, NSPopoverDelegate {
    private let statusItemButton: NSStatusBarButton
    /// Gets the keyboard back when Esc closes the popover.
    private var previousFrontmostApp: NSRunningApplication!

    init(rootView: MenuBarPopoverView, statusItemButton: NSStatusBarButton) {
        self.statusItemButton = statusItemButton
        super.init()

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = .preferredContentSize

        contentViewController = hostingController
        behavior = .transient
        delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("never decoded from a nib")
    }

    /// Below the menu bar item, or closed when it is shown already.
    func toggle() {
        if isShown {
            close()
            return
        }

        previousFrontmostApp = NSWorkspace.shared.frontmostApplication!
        NSApp.activate(ignoringOtherApps: true)
        show(relativeTo: statusItemButton.bounds, of: statusItemButton, preferredEdge: .minY)
    }

    /// A click elsewhere has moved the keyboard on already, and Settings... opens a window to type into; Esc would leave the app active with
    /// nothing to type into.
    func popoverDidClose(_ notification: Notification) {
        if !isActiveWithoutKeyWindow() { return }

        previousFrontmostApp.activate()
    }

    private func isActiveWithoutKeyWindow() -> Bool {
        if !NSApp.isActive { return false }
        return NSApp.keyWindow == nil
    }
}
