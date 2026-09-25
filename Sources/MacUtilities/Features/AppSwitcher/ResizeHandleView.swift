import AppKit

/// Invisible strip along the panel's left or right edge: shows the horizontal resize cursor and, while dragged, reports the mouse's x on the screen.
final class ResizeHandleView: NSView {
    var onDragged: (CGFloat) -> Void = { _ in }

    convenience init() {
        self.init(frame: .zero)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    /// The drag keeps arriving after Cmd+F rebuilt the content mid-drag; the detached strip lets it go.
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }

        onDragged(window.convertPoint(toScreen: event.locationInWindow).x)
    }
}
