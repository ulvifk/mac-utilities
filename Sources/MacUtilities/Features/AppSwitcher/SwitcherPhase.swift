/// What the switcher is doing, as the key presses find it.
enum SwitcherPhase {
    case closed
    case opening(SwitcherOpening)
    /// The panel is up, drawing this list.
    case open(SwitcherList)
}
