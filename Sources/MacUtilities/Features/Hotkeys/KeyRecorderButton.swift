import AppKit
import SwiftUI

private let disabledLabelAlpha: CGFloat = 0.4

/// Borderless button drawing a `KeyRecorderLabel`; a click makes it first responder and the next key press with a modifier becomes the combo.
/// Esc or a click elsewhere stops recording. Disabled with the rest of a switched-off pane, it records nothing.
final class KeyRecorderButton: NSButton {
    var combo: KeyCombo? {
        didSet { showLabel() }
    }
    var onRecord: (KeyCombo) -> Void = { _ in }

    private let label = NSHostingView(rootView: KeyRecorderLabel(combo: nil, isRecording: false))
    private var isRecording = false

    convenience init() {
        self.init(frame: .zero)

        isBordered = false
        title = ""
        label.autoresizingMask = [.width, .height]
        addSubview(label)
    }

    /// SwiftUI sets it with the pane's disabled state, but its fading stops at the label's own hosting view, so the label is faded here.
    override var isEnabled: Bool {
        didSet { label.alphaValue = isEnabled ? 1 : disabledLabelAlpha }
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    /// Keeps the label from swallowing the click.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        if !bounds.contains(localPoint) { return nil }

        return self
    }

    override func mouseDown(with event: NSEvent) {
        if !isEnabled { return }

        window!.makeFirstResponder(self)
        isRecording = true
        showLabel()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        showLabel()
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

    /// VoiceOver reads what the label shows, the title being empty.
    private func showLabel() {
        label.rootView = KeyRecorderLabel(combo: combo, isRecording: isRecording)
        setAccessibilityLabel(label.rootView.getAccessibilityText())
    }
}
