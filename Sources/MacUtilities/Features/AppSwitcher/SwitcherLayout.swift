import AppKit

/// Where the cells sit for an app count: full rows from the top down, centered on each other, the last one possibly shorter.
struct SwitcherLayout {
    let contentSize: NSSize
    /// [index] -> the cell's frame in the content
    let cellFrames: [NSRect]

    init(appCount: Int, iconsPerRow: Int) {
        let rowCount = (appCount + iconsPerRow - 1) / iconsPerRow
        let width = getRowWidth(iconCount: min(appCount, iconsPerRow)) + 2 * horizontalPadding
        let height = CGFloat(rowCount) * cellHeight + CGFloat(rowCount - 1) * rowSpacing + 2 * verticalPadding

        var frames: [NSRect] = []
        for index in 0..<appCount {
            let row = index / iconsPerRow
            let column = index % iconsPerRow
            let rowWidth = getRowWidth(iconCount: min(iconsPerRow, appCount - row * iconsPerRow))
            let x = (width - rowWidth) / 2 + CGFloat(column) * (iconSize + itemSpacing)
            let y = height - verticalPadding - cellHeight - CGFloat(row) * (cellHeight + rowSpacing)

            frames.append(alignToPixels(NSRect(x: x, y: y, width: iconSize, height: cellHeight)))
        }

        contentSize = NSSize(width: width, height: height)
        cellFrames = frames
    }

    func getIconFrame(index: Int) -> NSRect {
        return iconFrameInCell.offsetBy(dx: cellFrames[index].minX, dy: cellFrames[index].minY)
    }

    /// Hugs the selected icon's squircle rather than boxing the whole cell; the name sits below it, outside.
    func getHighlightFrame(index: Int) -> NSRect {
        return alignToPixels(getIconFrame(index: index).insetBy(dx: highlightIconInset, dy: highlightIconInset))
    }
}

func getRowWidth(iconCount: Int) -> CGFloat {
    return CGFloat(iconCount) * iconSize + CGFloat(iconCount - 1) * itemSpacing
}

/// Whole pixels of the main screen, as Auto Layout gave the old constraints: on a 1x screen the half-point constants would otherwise blur.
func alignToPixels(_ rect: NSRect) -> NSRect {
    return NSScreen.main!.backingAlignedRect(rect, options: .alignAllEdgesNearest)
}
