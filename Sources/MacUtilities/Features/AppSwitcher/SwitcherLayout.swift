import AppKit

/// Where the cells sit for an app count: full rows from the top down, centered on each other, the last one possibly shorter.
struct SwitcherLayout {
    let contentSize: NSSize
    /// [index] -> the cell's frame in the content
    let cellFrames: [NSRect]

    init(appCount: Int, iconsPerRow: Int) {
        let rowCount = (appCount + iconsPerRow - 1) / iconsPerRow
        let widestRowIconCount = min(appCount, iconsPerRow)
        let width = CGFloat(widestRowIconCount) * iconSize + CGFloat(widestRowIconCount - 1) * itemSpacing + 2 * horizontalPadding
        let height = CGFloat(rowCount) * cellHeight + CGFloat(rowCount - 1) * rowSpacing + 2 * verticalPadding

        var frames: [NSRect] = []
        for index in 0..<appCount {
            let row = index / iconsPerRow
            let x = horizontalPadding + getVisualColumn(index: index, appCount: appCount, iconsPerRow: iconsPerRow) * (iconSize + itemSpacing)
            let y = height - verticalPadding - cellHeight - CGFloat(row) * (cellHeight + rowSpacing)

            frames.append(alignToPixels(NSRect(x: x, y: y, width: iconSize, height: cellHeight)))
        }

        contentSize = NSSize(width: width, height: height)
        cellFrames = frames
    }

    func getIconFrame(index: Int) -> NSRect {
        return iconFrameInCell.offsetBy(dx: cellFrames[index].minX, dy: cellFrames[index].minY)
    }

    /// Hugs the selected, grown icon's squircle rather than boxing the whole cell; the name sits below it, outside.
    func getHighlightFrame(index: Int) -> NSRect {
        let iconFrame = selectedIconFrameInCell.offsetBy(dx: cellFrames[index].minX, dy: cellFrames[index].minY)
        return alignToPixels(iconFrame.insetBy(dx: highlightIconInset, dy: highlightIconInset))
    }
}

/// The column the icon is drawn in, fractional: rows are centered on the widest, so a shorter one is shifted right by half a column per missing icon.
func getVisualColumn(index: Int, appCount: Int, iconsPerRow: Int) -> CGFloat {
    let row = index / iconsPerRow
    let widestRowIconCount = min(appCount, iconsPerRow)
    let rowIconCount = min(appCount - row * iconsPerRow, iconsPerRow)

    return CGFloat(index % iconsPerRow) + CGFloat(widestRowIconCount - rowIconCount) / 2
}

/// Whole pixels of the main screen, as Auto Layout gave the old constraints: on a 1x screen the half-point constants would otherwise blur.
func alignToPixels(_ rect: NSRect) -> NSRect {
    return NSScreen.main!.backingAlignedRect(rect, options: .alignAllEdgesNearest)
}
