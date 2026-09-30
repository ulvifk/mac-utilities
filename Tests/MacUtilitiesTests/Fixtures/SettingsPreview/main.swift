import AppKit

_ = AppKit.NSApplication.shared.setActivationPolicy(.prohibited)

let feature = SettingsTestFeature()
let controller = AppController(features: [feature])
let window = SettingsWindow(controller: controller)

precondition(window.delegate === window, "Settings lifecycle delegate was not wired")
window.showPane(feature.identifier)
precondition(feature.visibilityChanges == [false], "A hidden window marked its pane visible")
feature.visibilityChanges = []

window.open()
precondition(feature.visibilityChanges == [true], "Opening did not mark the selected pane visible")
precondition(feature.currentWindow === window, "Opening did not pass the exact settings window")
precondition(!window.isVisible, "Lifecycle tests presented a live settings window")
window.showPane(feature.identifier)
precondition(feature.visibilityChanges == [true], "Reselecting the pane reset its preview")
print("PASS settings/open-and-reselect")

window.delegate!.windowDidMove!(Notification(name: AppKit.NSWindow.didMoveNotification, object: window))
window.delegate!.windowDidResize!(Notification(name: AppKit.NSWindow.didResizeNotification, object: window))
precondition(feature.visibilityChanges == [true, true, true], "Moving or resizing hid the selected pane")
feature.visibilityChanges = [true]
print("PASS settings/geometry-keeps-pane-visible")

window.delegate!.windowDidMiniaturize!(Notification(name: AppKit.NSWindow.didMiniaturizeNotification, object: window))
precondition(feature.visibilityChanges == [true, false], "Miniaturizing did not hide the selected pane")
window.delegate!.windowDidDeminiaturize!(Notification(name: AppKit.NSWindow.didDeminiaturizeNotification, object: window))
precondition(feature.visibilityChanges == [true, false, true], "Restoring did not mark the selected pane visible")
print("PASS settings/miniaturize-and-restore")

feature.visibilityChanges = []
SettingsSidebarViewController.instance.onSelect(generalPaneIdentifier)
precondition(feature.visibilityChanges == [false], "Sidebar pane exit did not hide feature settings")
SettingsSidebarViewController.instance.onSelect(feature.identifier)
precondition(feature.visibilityChanges == [false, true], "Sidebar pane entry did not show feature settings")
precondition(window.title == feature.displayName, "Sidebar selection lost the pane title")
print("PASS settings/sidebar-pane-visibility")

feature.visibilityChanges = []
window.close()
precondition(feature.visibilityChanges == [false], "Closing did not hide the selected pane")
precondition(feature.currentWindow == nil, "Closing kept the settings window in the feature")
window.open()
precondition(feature.visibilityChanges == [false, true], "Reopening did not restore selected pane visibility")
// The fake order-front never reopens AppKit's closed window; deliver its next native close callback explicitly.
window.delegate!.windowWillClose!(Notification(name: AppKit.NSWindow.willCloseNotification, object: window))
print("PASS settings/close-and-reopen")

feature.visibilityChanges = []
window.delegate!.windowDidMove!(Notification(name: AppKit.NSWindow.didMoveNotification, object: window))
window.delegate!.windowDidResize!(Notification(name: AppKit.NSWindow.didResizeNotification, object: window))
precondition(feature.visibilityChanges.isEmpty, "Moving closed settings marked its pane visible")
print("PASS settings/closed-geometry-stays-hidden")
