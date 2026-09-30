import AppKit
import CoreImage

/// An app icon with its card and whitelist marker.
final class IconCellView: SwitcherCellView {
    let icon = NSImageView()
    let dot = NSView()

    convenience init(app: NSRunningApplication, cardGlass: GlassStore?) {
        self.init(frame: .zero)

        card.frame = alignToPixels(iconCardFrameInCell)
        card.setCorners(radius: iconCardCornerRadius, curve: .continuous)

        icon.image = app.icon ?? NSImage()
        icon.image?.size = NSSize(width: iconSize, height: iconSize)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.frame = alignToPixels(iconFrameInCell)

        dot.wantsLayer = true
        dot.layer?.cornerRadius = dotSize / 2
        dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dot.frame = alignToPixels(dotFrameInCell)

        addSubview(card)
        addSubview(icon)
        addSubview(dot)

        card.updateGlass(cardGlass)
    }

    func showStatus(app: NSRunningApplication, whitelisted: Bool, isFiltered: Bool, dimHiddenApps: Bool) {
        icon.alphaValue = 1
        if dimHiddenApps {
            icon.alphaValue = app.isHidden ? hiddenIconAlpha : 1
        }

        if isFiltered {
            dot.isHidden = true
            icon.contentFilters = whitelisted ? [] : [buildGrayscaleFilter()]
            return
        }

        dot.isHidden = !whitelisted
        icon.contentFilters = []
    }

    private func buildGrayscaleFilter() -> CIFilter {
        return CIFilter(name: "CIColorControls", parameters: [kCIInputSaturationKey: 0])!
    }
}
