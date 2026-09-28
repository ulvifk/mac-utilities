import AppKit

/// Whole points throughout, so the edges land on pixels at 1x too.
private let glyphSize = NSSize(width: 16, height: 16)
private let glyphTileSize: CGFloat = 10
/// Each tile sits this far up and right of the one in front of it.
private let glyphTileStep: CGFloat = 3
private let glyphTileCornerRadius: CGFloat = 2.5
/// The clear outline around a tile that parts it from the one behind.
private let glyphTileGap: CGFloat = 1

/// The app's menu bar glyph: three tiles cascading like those of the app icon, as a template the menu bar tints.
func buildMenuBarGlyph() -> NSImage {
    let image = NSImage(size: glyphSize, flipped: false) { _ in
        for depth in [2, 1, 0] {
            let tile = NSRect(x: CGFloat(depth) * glyphTileStep, y: CGFloat(depth) * glyphTileStep, width: glyphTileSize, height: glyphTileSize)
            eraseGap(around: tile)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: tile, xRadius: glyphTileCornerRadius, yRadius: glyphTileCornerRadius).fill()
        }
        return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Mac Utilities"
    return image
}

private func eraseGap(around tile: NSRect) {
    let gapRadius = glyphTileCornerRadius + glyphTileGap
    let gap = NSBezierPath(roundedRect: tile.insetBy(dx: -glyphTileGap, dy: -glyphTileGap), xRadius: gapRadius, yRadius: gapRadius)

    NSGraphicsContext.current!.compositingOperation = .clear
    gap.fill()
    NSGraphicsContext.current!.compositingOperation = .sourceOver
}
