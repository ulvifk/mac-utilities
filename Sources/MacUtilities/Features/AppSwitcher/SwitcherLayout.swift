import AppKit

/// Where the cells sit for a cell count: full rows from the top down, centered on each other, the last one possibly shorter.
struct SwitcherLayout {
    let contentSize: NSSize
    /// [index] -> the cell's frame in the content
    let cellFrames: [NSRect]

    private let highlightFrameInCell: NSRect

    init(cellCount: Int, cellsPerRow: Int, metrics: SwitcherCellMetrics) {
        let cellSize = metrics.cellSize
        let rowCount = (cellCount + cellsPerRow - 1) / cellsPerRow
        let widestRowCellCount = min(cellCount, cellsPerRow)
        let width = CGFloat(widestRowCellCount) * cellSize.width + CGFloat(widestRowCellCount - 1) * itemSpacing + 2 * horizontalPadding
        let height = CGFloat(rowCount) * cellSize.height + CGFloat(rowCount - 1) * metrics.rowSpacing + 2 * metrics.verticalPadding

        var frames: [NSRect] = []
        for index in 0..<cellCount {
            let row = index / cellsPerRow
            let x = horizontalPadding + getVisualColumn(index: index, cellCount: cellCount, cellsPerRow: cellsPerRow) * (cellSize.width + itemSpacing)
            let y = height - metrics.verticalPadding - cellSize.height - CGFloat(row) * (cellSize.height + metrics.rowSpacing)

            frames.append(alignToPixels(NSRect(x: x, y: y, width: cellSize.width, height: cellSize.height)))
        }

        contentSize = NSSize(width: width, height: height)
        cellFrames = frames
        highlightFrameInCell = metrics.highlightFrameInCell
    }

    /// Of an icon cell.
    func getIconFrame(index: Int) -> NSRect {
        return iconFrameInCell.offsetBy(dx: cellFrames[index].minX, dy: cellFrames[index].minY)
    }

    /// Hugs the selected icon's squircle rather than boxing the whole cell; the name sits below it, outside.
    func getHighlightFrame(index: Int) -> NSRect {
        return alignToPixels(highlightFrameInCell.offsetBy(dx: cellFrames[index].minX, dy: cellFrames[index].minY))
    }
}

/// The column the cell is drawn in, fractional: rows are centered on the widest, so a shorter one is shifted right by half a column per missing cell.
func getVisualColumn(index: Int, cellCount: Int, cellsPerRow: Int) -> CGFloat {
    let row = index / cellsPerRow
    let widestRowCellCount = min(cellCount, cellsPerRow)
    let rowCellCount = min(cellCount - row * cellsPerRow, cellsPerRow)

    return CGFloat(index % cellsPerRow) + CGFloat(widestRowCellCount - rowCellCount) / 2
}

/// Whole pixels of the main screen, as Auto Layout gave the old constraints: on a 1x screen the half-point constants would otherwise blur.
func alignToPixels(_ rect: NSRect) -> NSRect {
    return NSScreen.main!.backingAlignedRect(rect, options: .alignAllEdgesNearest)
}
