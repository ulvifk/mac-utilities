/// One entry of hotkeys.json. The key is nil until it is recorded; such a binding never fires.
struct HotkeyBinding: Equatable, Codable {
    var key: KeyCombo?
    var action: HotkeyAction
}
