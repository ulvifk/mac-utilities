import AppKit

/// What the panel draws: the list and how its items look.
struct SwitcherState {
    let list: SwitcherList
    /// [window id] -> the window's latest thumbnail
    let thumbnails: [CGWindowID: NSImage]
    /// The listed cells' card glass; nil while their cards are switched off.
    let cardGlass: GlassStore?
    /// The filter switch, which Cmd+F flips, on even while none of the whitelisted apps is running.
    let isFilterEnabled: Bool
    let dimHiddenApps: Bool
    let whitelisted: Set<String>
}
