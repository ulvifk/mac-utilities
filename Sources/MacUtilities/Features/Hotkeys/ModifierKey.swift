import AppKit

/// The four modifiers a hotkey can hold, in the order macOS prints them: ⌃⌥⇧⌘. The raw value is the name used in hotkeys.json.
enum ModifierKey: String, Codable, CaseIterable {
    case control
    case option
    case shift
    case command

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    var tapFlag: CGEventFlags {
        switch self {
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .shift: return .maskShift
        case .command: return .maskCommand
        }
    }

    var windowFlag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option: return .option
        case .shift: return .shift
        case .command: return .command
        }
    }
}
