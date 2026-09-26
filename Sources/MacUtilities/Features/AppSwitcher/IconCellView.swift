import AppKit
import CoreImage

/// A clickable icon cell: the whitelist dot above the icon, room for the selected app name below it, the icon centered between them.
final class IconCellView: NSView {
    let icon = NSImageView()
    let dot = NSView()
    var index = 0
    var onClick: (Int) -> Void = { _ in }

    convenience init(app: NSRunningApplication) {
        self.init(frame: .zero)

        icon.image = app.icon ?? NSImage()
        icon.image?.size = NSSize(width: iconSize, height: iconSize)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.frame = alignToPixels(iconFrameInCell)

        dot.wantsLayer = true
        dot.layer?.cornerRadius = dotSize / 2
        dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dot.frame = alignToPixels(dotFrameInCell)

        addSubview(icon)
        addSubview(dot)
    }

    /// Hidden apps dim. With the filter off a dot marks the whitelisted apps; with it on every app listed is whitelisted, so the ones taken
    /// off the whitelist with Cmd+W turn gray instead.
    func showStatus(app: NSRunningApplication, whitelisted: Bool, isFiltered: Bool) {
        icon.alphaValue = app.isHidden ? hiddenIconAlpha : 1

        if isFiltered {
            dot.isHidden = true
            icon.contentFilters = whitelisted ? [] : [buildGrayscaleFilter()]
            return
        }

        dot.isHidden = !whitelisted
        icon.contentFilters = []
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

    private func buildGrayscaleFilter() -> CIFilter {
        return CIFilter(name: "CIColorControls", parameters: [kCIInputSaturationKey: 0])!
    }
}
