import AppKit

/// The panel's content, laid out from the top down, so it keeps its place against the top edge when the panel's height changes.
final class SwitcherContentView: NSView {
    override var isFlipped: Bool {
        return true
    }
}
