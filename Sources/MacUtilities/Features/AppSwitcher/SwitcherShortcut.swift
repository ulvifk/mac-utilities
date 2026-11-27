import CoreGraphics

/// A key press the switcher acts on, named by what it does there. Whether it is acted on depends on what the switcher is doing: the two
/// switching shortcuts open it, the rest only work while it is open, and Esc also cancels an opening.
enum SwitcherShortcut: Equatable {
    /// ⌘⇥, backward with ⇧.
    case switchApps(backward: Bool)
    /// ⌘`, backward with ⇧.
    case switchWindows(backward: Bool)
    /// ⌘→
    case selectNext
    /// ⌘←
    case selectPrevious
    /// ⌘↑
    case selectRowAbove
    /// ⌘↓
    case selectRowBelow
    /// ⌘W
    case toggleWhitelisted
    /// ⌘F
    case toggleFilter
    /// ⇧⌘Q
    case batchQuit
    /// ⌘Q
    case quit
    /// ⌘H
    case hide
    /// Esc, whatever modifiers are held.
    case cancel
}

/// [key code] -> the shortcut it makes with Cmd held; extra modifiers still match, so Cmd+Shift+→ is a Cmd+→.
private let commandShortcuts: [Int64: SwitcherShortcut] = [
    rightArrowKeyCode: .selectNext,
    leftArrowKeyCode: .selectPrevious,
    upArrowKeyCode: .selectRowAbove,
    downArrowKeyCode: .selectRowBelow,
    wKeyCode: .toggleWhitelisted,
    fKeyCode: .toggleFilter,
    hKeyCode: .hide,
]

/// The switcher shortcut the key and modifiers make, or nil for any other key. Cmd+Shift+Q is a Batch Quit rather than a Cmd+Q, and Shift on
/// the switching shortcuts goes backward: Cmd+Shift+Tab -> .switchApps(backward: true).
func getSwitcherShortcut(keyCode: Int64, flags: CGEventFlags) -> SwitcherShortcut? {
    if keyCode == escapeKeyCode { return .cancel }
    if !flags.contains(.maskCommand) { return nil }

    let backward = flags.contains(.maskShift)
    if keyCode == tabKeyCode { return .switchApps(backward: backward) }
    if keyCode == graveKeyCode { return .switchWindows(backward: backward) }
    if keyCode == qKeyCode { return backward ? .batchQuit : .quit }

    return commandShortcuts[keyCode]
}
