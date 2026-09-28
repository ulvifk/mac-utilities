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
}

func getCellMetrics(listingWindows: Bool) -> SwitcherCellMetrics {
    if listingWindows { return windowCellMetrics }
    return iconCellMetrics
}
