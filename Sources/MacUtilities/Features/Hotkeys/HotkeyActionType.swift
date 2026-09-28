/// What a hotkey does. The raw value is the "type" in hotkeys.json.
enum HotkeyActionType: String, Codable, CaseIterable {
    case activateApp
    case toggleApp
    case runCommand
    case toggleKeepAwake

    var title: String {
        switch self {
        case .activateApp: return "Open App"
        case .toggleApp: return "Toggle App"
        case .runCommand: return "Run Command"
        case .toggleKeepAwake: return "Toggle Keep Awake"
        }
    }

    /// Beside the title in the action picker.
    var symbolName: String {
        switch self {
        case .activateApp: return "arrow.up.forward.app"
        case .toggleApp: return "rectangle.2.swap"
        case .runCommand: return "terminal"
        case .toggleKeepAwake: return "cup.and.saucer"
        }
    }

    var takesApp: Bool {
        if self == .activateApp { return true }
        if self == .toggleApp { return true }
        return false
    }
}
