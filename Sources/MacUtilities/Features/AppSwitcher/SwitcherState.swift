import AppKit

struct SwitcherState {
    let apps: [NSRunningApplication]
    let iconsPerRow: Int
    let selectedIndex: Int
    let filterEnabled: Bool
    let whitelisted: Set<String>
}
