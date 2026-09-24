import Carbon.HIToolbox

/// [key code] -> what the recorder shows for keys that print nothing.
private let specialKeyNames: [Int64: String] = [
    36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤", 117: "⌦",
    115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    123: "←", 124: "→", 125: "↓", 126: "↑",
    122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
    103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
]

/// The key's label on the current keyboard layout: "T" for key code 17 on a US layout.
func getKeyName(keyCode: Int64) -> String {
    if let name = specialKeyNames[keyCode] { return name }

    return translateKey(keyCode).uppercased()
}

private func translateKey(_ keyCode: Int64) -> String {
    let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
    let layoutData = Unmanaged<CFData>.fromOpaque(TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)).takeUnretainedValue() as Data

    return layoutData.withUnsafeBytes { bytes in
        let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress!
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, characters.count, &length, &characters)
        return String(utf16CodeUnits: characters, count: length)
    }
}
