import AppKit

/// The main screen the switcher opens on: the room it leaves the panel, and what its windows show.
protocol SwitcherScreen {
    /// Without the menu bar and the Dock.
    var visibleSize: NSSize { get }

    /// Captures what each window shows, covered ones included, and hands every thumbnail to onCaptured on the main thread as it arrives.
    /// Windows that draw nothing, minimized ones and those on another Space, are left out.
    func captureThumbnails(of windowIDs: [CGWindowID], onCaptured: @escaping (CGWindowID, NSImage) -> Void)
}
