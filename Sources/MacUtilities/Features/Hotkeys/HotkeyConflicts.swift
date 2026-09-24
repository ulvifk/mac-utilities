private let spaceKeyCode: Int64 = 49
private let threeKeyCode: Int64 = 20
private let fourKeyCode: Int64 = 21
private let fiveKeyCode: Int64 = 23

/// [combo] -> what macOS uses it for. Cmd+Tab is listed whether or not the app-switcher feature is on, since both claim it.
private let reservedCombos: [(combo: KeyCombo, use: String)] = [
    (KeyCombo(keyCode: spaceKeyCode, modifiers: [.command]), "Spotlight"),
    (KeyCombo(keyCode: tabKeyCode, modifiers: [.command]), "app switching"),
    (KeyCombo(keyCode: tabKeyCode, modifiers: [.command, .shift]), "app switching"),
    (KeyCombo(keyCode: escapeKeyCode, modifiers: [.command, .option]), "Force Quit"),
    (KeyCombo(keyCode: qKeyCode, modifiers: [.command, .control]), "locking the screen"),
    (KeyCombo(keyCode: threeKeyCode, modifiers: [.command, .shift]), "screenshots"),
    (KeyCombo(keyCode: fourKeyCode, modifiers: [.command, .shift]), "screenshots"),
    (KeyCombo(keyCode: fiveKeyCode, modifiers: [.command, .shift]), "screenshots"),
    (KeyCombo(keyCode: upArrowKeyCode, modifiers: [.control]), "Mission Control"),
    (KeyCombo(keyCode: downArrowKeyCode, modifiers: [.control]), "Mission Control"),
    (KeyCombo(keyCode: leftArrowKeyCode, modifiers: [.control]), "Mission Control"),
    (KeyCombo(keyCode: rightArrowKeyCode, modifiers: [.control]), "Mission Control"),
]

/// Why the binding at this index should get another key, or nil when its key is free.
func getConflictWarning(index: Int, bindings: [HotkeyBinding]) -> String? {
    guard let key = bindings[index].key else { return nil }

    if let reserved = reservedCombos.first(where: { $0.combo == key }) {
        return "macOS uses \(key.symbols) for \(reserved.use)"
    }

    for (otherIndex, other) in bindings.enumerated() {
        if otherIndex == index { continue }
        if other.key != key { continue }
        return "Same key as binding \(otherIndex + 1)"
    }

    return nil
}
