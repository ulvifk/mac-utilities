import AppKit

/// A clickable window cell: the window's thumbnail, or its app's icon until one is captured, and the window's title under it, framed in a card
/// unless cards are switched off.
final class WindowCellView: SwitcherCellView {
    /// Around the card, drawn over it: faint, or the selection's ring.
    private let border = NSView()
    private let thumbnail = NSImageView()
    private let title = NSTextField(labelWithString: "")

    /// Without a card glass, cards are off.
    convenience init(window: AppWindow, cardGlass: GlassStore?) {
        self.init(frame: .zero)

        border.wantsLayer = true
        border.layer?.cornerRadius = highlightCornerRadius
        border.frame = alignToPixels(windowCardFrameInCell)

        thumbnail.image = window.app.icon ?? NSImage()
        thumbnail.image?.size = NSSize(width: iconSize, height: iconSize)
        thumbnail.imageScaling = .scaleProportionallyDown
        thumbnail.frame = alignToPixels(windowThumbnailFrameInCell)

        title.stringValue = window.title
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.textColor = .white
        title.alignment = .center
        title.lineBreakMode = .byTruncatingTail
        title.maximumNumberOfLines = 1
        title.frame = alignToPixels(windowTitleFrameInCell)

        if let cardGlass {
            addSubview(buildCard(glass: cardGlass))
            addSubview(border)
        }
        addSubview(thumbnail)
        addSubview(title)
    }

    func showThumbnail(_ image: NSImage) {
        thumbnail.image = image
    }

    func showSelected(_ isSelected: Bool) {
        border.layer?.borderWidth = isSelected ? selectedWindowCardBorderWidth : windowCardBorderWidth
        border.layer?.borderColor = (isSelected ? NSColor.controlAccentColor : windowCardBorderColor).cgColor
    }

    /// A dark fill as dark as the glass setting says; Frosted blurs what is behind the panel under it. The panel is never key, so the blur is kept
    /// active or it would draw as a flat inactive gray.
    private func buildCard(glass: GlassStore) -> NSView {
        let card = NSView(frame: alignToPixels(windowCardFrameInCell))
        let tint = NSView(frame: card.bounds)

        card.wantsLayer = true
        card.layer?.cornerRadius = highlightCornerRadius
        card.layer?.masksToBounds = true
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(glass.darkness).cgColor

        if glass.isFrosted {
            card.addSubview(buildBlur(size: card.bounds.size))
        }
        card.addSubview(tint)

        return card
    }

    private func buildBlur(size: NSSize) -> NSVisualEffectView {
        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))

        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active

        return blur
    }
}
