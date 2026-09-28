import AppKit

struct SwitcherState {
    let apps: [NSRunningApplication]
    /// Listed in place of the apps while switching between the windows of one app.
    let windows: [AppWindow]
    /// [window id] -> the window's latest thumbnail
    let thumbnails: [CGWindowID: NSImage]
    let isListingWindows: Bool
    /// The glass of the card each window's thumbnail and title sit in; nil while cards are switched off.
    let windowCardGlass: GlassStore?
    let cellsPerRow: Int
    let selectedIndex: Int
    /// Only whitelisted apps are listed; false while the filter is on but none of them is running, so every app is.
    let isFiltered: Bool
    /// The filter switch, which Cmd+F flips, on even while none of the whitelisted apps is running.
    let isFilterEnabled: Bool
    let whitelisted: Set<String>
}
