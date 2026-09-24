/// The action and its target: the bundle identifier for the app actions, the command line for runCommand, empty for toggleKeepAwake.
struct HotkeyAction: Equatable, Codable {
    var type: HotkeyActionType
    var target: String
}
