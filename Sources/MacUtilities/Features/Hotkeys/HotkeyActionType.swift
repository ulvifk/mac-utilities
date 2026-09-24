/// What a hotkey does. The raw value is the "type" in hotkeys.json.
enum HotkeyActionType: String, Codable, CaseIterable {
    case activateApp
    case toggleApp
    case runCommand
    case toggleKeepAwake

    var title: String {
        switch self {
        case .activateApp: return "Open app"
        case .toggleApp: return "Toggle app"
        case .runCommand: return "Run command"
        case .toggleKeepAwake: return "Toggle keep awake"
        }
    }

    var takesApp: Bool {
        if self == .activateApp { return true }
        if self == .toggleApp { return true }
        return false
    }
}
