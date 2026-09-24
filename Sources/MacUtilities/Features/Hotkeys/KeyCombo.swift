import AppKit

/// A key with exactly these modifiers held; Cmd+Shift+T is not a Cmd+T. Written to hotkeys.json as the key code and the modifier names.
struct KeyCombo: Equatable, Codable {
    let keyCode: Int64
    let modifiers: Set<ModifierKey>

    init(keyCode: Int64, modifiers: Set<ModifierKey>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// The combo a tapped key press is.
    init(tappedEvent event: CGEvent) {
        keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        modifiers = Set(ModifierKey.allCases.filter { event.flags.contains($0.tapFlag) })
    }

    /// The combo a key press delivered to one of our windows is.
    init(windowEvent event: NSEvent) {
        keyCode = Int64(event.keyCode)
        modifiers = Set(ModifierKey.allCases.filter { event.modifierFlags.contains($0.windowFlag) })
    }

    /// ⌘⌥T
    var symbols: String {
        return getOrderedModifiers().map { $0.symbol }.joined() + getKeyName(keyCode: keyCode)
    }

    /// Modifiers in their display order, so the file reads the same way and never churns.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(getOrderedModifiers(), forKey: .modifiers)
    }

    private func getOrderedModifiers() -> [ModifierKey] {
        return ModifierKey.allCases.filter { modifiers.contains($0) }
    }
}
