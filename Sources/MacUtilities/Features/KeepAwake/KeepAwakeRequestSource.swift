/// Where a request to turn Keep Awake on or off came from.
enum KeepAwakeRequestSource: String {
    case popoverToggle = "the popover toggle"
    case durationChip = "a duration chip"
    case hotkey = "a hotkey"
}
