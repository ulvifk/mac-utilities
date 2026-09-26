import AppKit

/// A green capsule with a filter symbol and "Whitelist", sized to fit them.
final class WhitelistBadgeView: NSView {
    convenience init() {
        self.init(frame: .zero)

        let symbol = NSImageView(image: NSImage(systemSymbolName: "line.3.horizontal.decrease", accessibilityDescription: nil)!)
        let label = NSTextField(labelWithString: "Whitelist")

        symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        symbol.contentTintColor = .white
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white

        let symbolSize = symbol.fittingSize
        let labelSize = label.fittingSize
        symbol.frame = NSRect(x: badgeHorizontalPadding, y: (badgeHeight - symbolSize.height) / 2, width: symbolSize.width, height: symbolSize.height)
        label.frame = NSRect(x: symbol.frame.maxX + badgeSymbolSpacing, y: (badgeHeight - labelSize.height) / 2, width: labelSize.width, height: labelSize.height)
        frame.size = NSSize(width: label.frame.maxX + badgeHorizontalPadding, height: badgeHeight)

        wantsLayer = true
        layer?.cornerRadius = badgeHeight / 2
        layer?.backgroundColor = badgeColor.cgColor

        addSubview(symbol)
        addSubview(label)
    }
}
