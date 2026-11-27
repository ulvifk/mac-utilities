import CoreGraphics
import Testing
@testable import MacUtilities

struct SwitcherShortcutTests {
    struct Press: CustomTestStringConvertible, Sendable {
        let name: String
        let keyCode: Int64
        let flags: CGEventFlags
        let expected: SwitcherShortcut?

        var testDescription: String { name }
    }

    static let presses = [
        Press(name: "cmd-tab", keyCode: tabKeyCode, flags: .maskCommand, expected: .switchApps(backward: false)),
        Press(name: "cmd-shift-tab", keyCode: tabKeyCode, flags: [.maskCommand, .maskShift], expected: .switchApps(backward: true)),
        Press(name: "cmd-grave", keyCode: graveKeyCode, flags: .maskCommand, expected: .switchWindows(backward: false)),
        Press(name: "cmd-shift-grave", keyCode: graveKeyCode, flags: [.maskCommand, .maskShift], expected: .switchWindows(backward: true)),
        Press(name: "cmd-right", keyCode: rightArrowKeyCode, flags: .maskCommand, expected: .selectNext),
        Press(name: "cmd-shift-right", keyCode: rightArrowKeyCode, flags: [.maskCommand, .maskShift], expected: .selectNext),
        Press(name: "cmd-left", keyCode: leftArrowKeyCode, flags: .maskCommand, expected: .selectPrevious),
        Press(name: "cmd-up", keyCode: upArrowKeyCode, flags: .maskCommand, expected: .selectRowAbove),
        Press(name: "cmd-down", keyCode: downArrowKeyCode, flags: .maskCommand, expected: .selectRowBelow),
        Press(name: "cmd-w", keyCode: wKeyCode, flags: .maskCommand, expected: .toggleWhitelisted),
        Press(name: "cmd-f", keyCode: fKeyCode, flags: .maskCommand, expected: .toggleFilter),
        Press(name: "cmd-q", keyCode: qKeyCode, flags: .maskCommand, expected: .quit),
        Press(name: "cmd-shift-q", keyCode: qKeyCode, flags: [.maskCommand, .maskShift], expected: .batchQuit),
        Press(name: "cmd-h", keyCode: hKeyCode, flags: .maskCommand, expected: .hide),
        Press(name: "esc", keyCode: escapeKeyCode, flags: [], expected: .cancel),
        Press(name: "cmd-esc", keyCode: escapeKeyCode, flags: .maskCommand, expected: .cancel),
        Press(name: "tab", keyCode: tabKeyCode, flags: [], expected: nil),
        Press(name: "shift-q", keyCode: qKeyCode, flags: .maskShift, expected: nil),
        Press(name: "option-tab", keyCode: tabKeyCode, flags: .maskAlternate, expected: nil),
        Press(name: "cmd-space", keyCode: 49, flags: .maskCommand, expected: nil),
    ]

    @Test(arguments: presses)
    func decodesPress(_ press: Press) {
        #expect(getSwitcherShortcut(keyCode: press.keyCode, flags: press.flags) == press.expected)
    }
}
