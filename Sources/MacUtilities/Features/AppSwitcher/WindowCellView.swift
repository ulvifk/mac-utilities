import AppKit

/// A clickable window cell: the window's thumbnail, or its app's icon until one is captured, and the window's title under it.
final class WindowCellView: SwitcherCellView {
    private let thumbnail = NSImageView()
    private let title = NSTextField(labelWithString: "")

    convenience init(window: AppWindow) {
        self.init(frame: .zero)

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

        addSubview(thumbnail)
        addSubview(title)
    }

    func showThumbnail(_ image: NSImage) {
        thumbnail.image = image
    }
}
