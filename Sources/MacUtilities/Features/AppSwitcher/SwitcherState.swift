import AppKit

struct SwitcherState {
    let apps: [NSRunningApplication]
    let cellsPerRow: Int
    let selectedIndex: Int
    /// Only whitelisted apps are listed; false while the filter is on but none of them is running, so every app is.
    let isFiltered: Bool
    let whitelisted: Set<String>
}
