import AppKit

/// A clickable window cell: the window's thumbnail, or its app's icon until one is captured, and the window's title under it, framed in a card
/// unless cards are switched off.
final class WindowCellView: SwitcherCellView {
    private let card = NSView()
    private let blur = NSVisualEffectView()
    private let tint = NSView()
    /// Around the card, drawn over it: faint, or the selection's ring.
    private let border = NSView()
    private let thumbnail = NSImageView()
    private let title = NSTextField(labelWithString: "")

    /// Without a card glass, cards are off.
    convenience init(window: AppWindow, cardGlass: GlassStore?) {
        self.init(frame: .zero)

        card.frame = alignToPixels(windowCardFrameInCell)
        card.wantsLayer = true
        card.layer?.cornerRadius = highlightCornerRadius
        card.layer?.masksToBounds = true

        blur.frame = card.bounds
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active

        tint.frame = card.bounds
        tint.wantsLayer = true

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

        card.addSubview(blur)
        card.addSubview(tint)
        addSubview(card)
        addSubview(border)
        addSubview(thumbnail)
        addSubview(title)

        updateCardGlass(cardGlass)
    }

    func updateCardGlass(_ glass: GlassStore?) {
        card.isHidden = glass == nil
        border.isHidden = glass == nil
        guard let glass else { return }

        blur.isHidden = !glass.isFrosted
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(glass.darkness).cgColor
    }

    func showThumbnail(_ image: NSImage) {
        thumbnail.image = image
    }

    func showSelected(_ isSelected: Bool) {
        border.layer?.borderWidth = isSelected ? selectedWindowCardBorderWidth : windowCardBorderWidth
        border.layer?.borderColor = (isSelected ? NSColor.controlAccentColor : windowCardBorderColor).cgColor
    }
}
