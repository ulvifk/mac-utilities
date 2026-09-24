import AppKit

/// A clickable icon cell: the whitelist dot above the icon, room for the selected app name below it, the icon centered between them.
final class IconCellView: NSView {
    let icon = NSImageView()
    let dot = NSView()
    var index = 0
    var onClick: (Int) -> Void = { _ in }

    convenience init(app: NSRunningApplication, whitelisted: Bool) {
        self.init(frame: .zero)

        icon.image = app.icon ?? NSImage()
        icon.image?.size = NSSize(width: iconSize, height: iconSize)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.alphaValue = getIconAlpha(app: app)
        icon.frame = alignToPixels(iconFrameInCell)

        dot.wantsLayer = true
        dot.layer?.cornerRadius = dotSize / 2
        dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dot.frame = alignToPixels(dotFrameInCell)
        dot.isHidden = !whitelisted

        addSubview(icon)
        addSubview(dot)
    }

    /// Keeps the icon image view from swallowing the click.
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

func getIconAlpha(app: NSRunningApplication) -> CGFloat {
    if app.isHidden { return hiddenIconAlpha }
    return 1
}
