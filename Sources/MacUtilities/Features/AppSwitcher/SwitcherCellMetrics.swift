import AppKit

/// What a kind of cell brings to the panel's rows: its size, where the highlight sits in it and how the rows around it are spaced.
struct SwitcherCellMetrics {
    let cellSize: NSSize
    let highlightFrameInCell: NSRect
    /// Between rows; negative when the rows overlap their bands.
    let rowSpacing: CGFloat
    /// Above the top row and below the bottom one.
    let verticalPadding: CGFloat
    /// The band the panel grows below the bottom row's padding for the hints.
    let hintBandHeight: CGFloat

    /// How many cells a row of this panel width holds, fractional.
    func getCellCount(forPanelWidth width: CGFloat) -> CGFloat {
        return (width - 2 * horizontalPadding + itemSpacing) / (cellSize.width + itemSpacing)
    }

    /// How many rows a panel of this height holds, fractional.
    func getRowCount(forPanelHeight height: CGFloat) -> CGFloat {
        return (height - 2 * verticalPadding + rowSpacing) / (cellSize.height + rowSpacing)
    }

    /// How many of the items a row holds: the count nearest the panel width, so a drag has to travel half a cell either way before a column
    /// comes or goes; raised when that many rows and the hint band would run past the screen's height, then held between one and what fits on
    /// its width, so a width dragged past the screen or remembered from a wider one still fits.
    func getCellsPerRow(itemCount: Int, panelWidth: CGFloat, screenSize: NSSize) -> Int {
        let nearest = Int(getCellCount(forPanelWidth: panelWidth).rounded())
        let fittingRows = max(1, Int(getRowCount(forPanelHeight: screenSize.height - hintBandHeight).rounded(.down)))
        let fewestForHeight = (itemCount + fittingRows - 1) / fittingRows
        let fitting = Int(getCellCount(forPanelWidth: screenSize.width).rounded(.down))

        let wanted = max(nearest, fewestForHeight)
        return max(1, min(wanted, fitting))
    }
}

func getCellMetrics(listingWindows: Bool) -> SwitcherCellMetrics {
    if listingWindows { return windowCellMetrics }
    return iconCellMetrics
}
