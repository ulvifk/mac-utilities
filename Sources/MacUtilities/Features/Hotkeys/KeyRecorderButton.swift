import AppKit

private let idleTitle = "Record shortcut"
private let recordingTitle = "Press keys..."

/// Button that shows the combo as symbols; a click makes it first responder and the next key press with a modifier becomes the combo. Esc or a click elsewhere stops recording.
final class KeyRecorderButton: NSButton {
    var combo: KeyCombo? {
        didSet { showCombo() }
    }
    var onRecord: (KeyCombo) -> Void = { _ in }

    private var isRecording = false

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window!.makeFirstResponder(self)
        isRecording = true
        title = recordingTitle
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        showCombo()
        return true
    }

    /// Cmd combos come this way first, before the window closes on Cmd+W.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if !isRecording { return false }

        record(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        if !isRecording {
            super.keyDown(with: event)
            return
        }

        record(event)
    }

    private func record(_ event: NSEvent) {
        if Int64(event.keyCode) == escapeKeyCode {
            window!.makeFirstResponder(nil)
            return
        }

        let recorded = KeyCombo(windowEvent: event)
        if recorded.modifiers.isEmpty { return }

        window!.makeFirstResponder(nil)
        onRecord(recorded)
    }

    private func showCombo() {
        title = combo?.symbols ?? idleTitle
    }
}
