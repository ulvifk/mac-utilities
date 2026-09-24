import AppKit

/// Top and bottom edges only, along the straight run between the corner arcs; lets clicks through to the cells beneath.
final class RimView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let straight = NSRect(x: panelCornerRadius, y: 0, width: bounds.width - 2 * panelCornerRadius, height: 1)

        for (row, alpha) in topRimAlphas.enumerated() {
            NSColor.white.withAlphaComponent(alpha).setFill()
            straight.offsetBy(dx: 0, dy: bounds.height - 1 - CGFloat(row)).fill()
        }

        for (row, alpha) in bottomRimAlphas.enumerated() {
            NSColor.white.withAlphaComponent(alpha).setFill()
            straight.offsetBy(dx: 0, dy: CGFloat(row)).fill()
        }
    }
}
