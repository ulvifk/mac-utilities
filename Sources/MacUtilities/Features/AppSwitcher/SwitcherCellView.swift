import AppKit

/// A cell in the panel's rows; a click anywhere on it reports the cell's index.
class SwitcherCellView: NSView {
    var index = 0
    var onClick: (Int) -> Void = { _ in }

    /// Keeps the cell's image views and labels from swallowing the click.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        if !bounds.contains(localPoint) { return nil }

        return self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        onClick(index)
    }
}
