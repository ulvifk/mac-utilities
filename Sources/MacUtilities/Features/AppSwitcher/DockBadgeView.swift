import AppKit

/// A red capsule with an app's Dock badge text, sized to it: a circle for one character, wider for more, truncated past dockBadgeMaxWidth.
final class DockBadgeView: NSView {
    convenience init(text: String) {
        self.init(frame: .zero)

        let label = NSTextField(labelWithString: text)
        label.font = dockBadgeFont
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1

        let textWidth = (text as NSString).size(withAttributes: [.font: dockBadgeFont]).width
        let width = min(max(dockBadgeHeight, (textWidth + 2 * dockBadgeHorizontalPadding).rounded(.up)), dockBadgeMaxWidth)
        let labelHeight = label.fittingSize.height
        label.frame = NSRect(x: 0, y: (dockBadgeHeight - labelHeight) / 2, width: width, height: labelHeight)
        frame.size = NSSize(width: width, height: dockBadgeHeight)

        wantsLayer = true
        layer?.cornerRadius = dockBadgeHeight / 2
        layer?.backgroundColor = dockBadgeColor.cgColor

        addSubview(label)
    }
}
