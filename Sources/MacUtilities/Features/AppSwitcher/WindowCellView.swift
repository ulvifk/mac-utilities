import AppKit

/// A window's thumbnail and title in a card.
final class WindowCellView: SwitcherCellView {
    private let thumbnail = NSImageView()
    private let title = NSTextField(labelWithString: "")

    /// Shows the app's icon until a thumbnail comes in. Without a card glass, cards are off.
    convenience init(window: SwitcherWindow, appIcon: NSImage?, cardGlass: GlassStore?) {
        self.init(frame: .zero)

        card.frame = alignToPixels(windowCardFrameInCell)

        thumbnail.image = appIcon ?? NSImage()
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

        addSubview(card)
        addSubview(thumbnail)
        addSubview(title)

        card.updateGlass(cardGlass)
    }

    func showThumbnail(_ image: NSImage) {
        thumbnail.image = image
    }
}
