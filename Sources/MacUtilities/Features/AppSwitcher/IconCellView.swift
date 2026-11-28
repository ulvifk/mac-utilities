import AppKit
import CoreImage

/// An app icon with its card, whitelist marker and Dock badge.
final class IconCellView: SwitcherCellView {
    let icon = NSImageView()
    let dot = NSView()
    /// Nil for an app without a badge.
    private(set) var dockBadge: DockBadgeView?

    convenience init(app: SwitcherApp, badgeText: String?, cardGlass: GlassStore?) {
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
        if let badgeText {
            dockBadge = buildDockBadge(text: badgeText)
            addSubview(dockBadge!)
        }

        card.updateGlass(cardGlass)
    }

    func showStatus(app: SwitcherApp, whitelisted: Bool, isFiltered: Bool, dimHiddenApps: Bool) {
        icon.alphaValue = 1
        if dimHiddenApps {
            icon.alphaValue = app.isHidden ? hiddenIconAlpha : 1
        }
        dockBadge?.alphaValue = icon.alphaValue

        if isFiltered {
            dot.isHidden = true
            icon.contentFilters = whitelisted ? [] : [buildGrayscaleFilter()]
            return
        }

        dot.isHidden = !whitelisted
        icon.contentFilters = []
    }

    /// Its top-right corner on the highlight's.
    private func buildDockBadge(text: String) -> DockBadgeView {
        let badge = DockBadgeView(text: text)
        let size = badge.frame.size

        badge.frame = alignToPixels(NSRect(
            x: iconCardFrameInCell.maxX - size.width, y: iconCardFrameInCell.maxY - size.height, width: size.width, height: size.height
        ))

        return badge
    }

    private func buildGrayscaleFilter() -> CIFilter {
        return CIFilter(name: "CIColorControls", parameters: [kCIInputSaturationKey: 0])!
    }
}
