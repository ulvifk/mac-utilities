import CoreGraphics

let tabKeyCode: Int64 = 48
let wKeyCode: Int64 = 13
let fKeyCode: Int64 = 3
let qKeyCode: Int64 = 12
let hKeyCode: Int64 = 4
let xKeyCode: Int64 = 7
let escapeKeyCode: Int64 = 53
let leftArrowKeyCode: Int64 = 123
let rightArrowKeyCode: Int64 = 124
let downArrowKeyCode: Int64 = 125
let upArrowKeyCode: Int64 = 126

func isKey(_ event: CGEvent, keyCode: Int64) -> Bool {
    return event.getIntegerValueField(.keyboardEventKeycode) == keyCode
}

/// The key with at least these modifiers held; extra modifiers still match, so Cmd+Shift+Tab is a Cmd+Tab.
func isShortcut(_ event: CGEvent, keyCode: Int64, modifiers: CGEventFlags) -> Bool {
    if !isKey(event, keyCode: keyCode) { return false }
    if !event.flags.contains(modifiers) { return false }
    return true
}
