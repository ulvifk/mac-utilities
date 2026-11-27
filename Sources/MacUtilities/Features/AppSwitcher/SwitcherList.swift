import CoreGraphics

/// The listed items as the panel wraps them into rows, and the selected one. Each change returns a new list, so a state handed to the panel
/// keeps the list it was drawn from.
struct SwitcherList {
    let items: SwitcherItems
    /// Fixed when the list is loaded or the panel resized, so the panel's rows and the row navigation agree even if the screen changes later.
    let cellsPerRow: Int
    let selectedIndex: Int

    init(items: SwitcherItems, cellsPerRow: Int, selectedIndex: Int = 0) {
        self.items = items
        self.cellsPerRow = cellsPerRow
        self.selectedIndex = selectedIndex
    }

    var count: Int {
        return items.count
    }

    var isEmpty: Bool {
        return items.count == 0
    }

    var isListingWindows: Bool {
        return items.isListingWindows
    }

    /// Only asked while apps are listed.
    var selectedApp: SwitcherApp {
        guard case .apps(let apps, _) = items else { preconditionFailure("Windows are listed") }

        return apps[selectedIndex]
    }

    func selecting(_ index: Int) -> SwitcherList {
        return SwitcherList(items: items, cellsPerRow: cellsPerRow, selectedIndex: index)
    }

    /// Steps any number of items at once, wrapping around both ends; e.g. 5 items with 0 selected: by -1 -> 4, by 7 -> 2.
    func advancing(by step: Int) -> SwitcherList {
        return selecting(((selectedIndex + step) % count + count) % count)
    }

    /// To the cell drawn nearest above or below, wrapping between the top and bottom rows; of two equally near, the left one, as min keeps the
    /// first. E.g. 5 items, 3 per row, the bottom row of 2 centered under the top one: 1 down -> 3, 2 down -> 4, 3 up -> 0.
    func movingBetweenRows(up: Bool) -> SwitcherList {
        let rowCount = (count + cellsPerRow - 1) / cellsPerRow
        let step = up ? -1 : 1
        let targetRow = (selectedIndex / cellsPerRow + step + rowCount) % rowCount
        let targetRowIndices = targetRow * cellsPerRow..<min((targetRow + 1) * cellsPerRow, count)

        return selecting(targetRowIndices.min { getColumnDistance(from: $0) < getColumnDistance(from: $1) }!)
    }

    func rewrapping(cellsPerRow: Int) -> SwitcherList {
        return SwitcherList(items: items, cellsPerRow: cellsPerRow, selectedIndex: selectedIndex)
    }

    /// The selection stays on its app; when that is the one removed, it moves to the next, or to the new last app when it was the last.
    /// Removing the only app leaves an empty list.
    func removingApp(at index: Int) -> SwitcherList {
        guard case .apps(let apps, let whitelistOnly) = items else { preconditionFailure("Windows are listed") }

        var remainingApps = apps
        remainingApps.remove(at: index)
        let shiftedIndex = index < selectedIndex ? selectedIndex - 1 : selectedIndex

        return SwitcherList(
            items: .apps(remainingApps, whitelistOnly: whitelistOnly),
            cellsPerRow: cellsPerRow,
            selectedIndex: max(0, min(shiftedIndex, remainingApps.count - 1))
        )
    }

    /// The app with this bundle identifier, or the first app when it is not listed.
    func selectingApp(bundleIdentifier: String) -> SwitcherList {
        guard case .apps(let apps, _) = items else { preconditionFailure("Windows are listed") }

        return selecting(apps.firstIndex { $0.bundleIdentifier == bundleIdentifier } ?? 0)
    }

    /// How far the cell is drawn from the selected one, in columns.
    private func getColumnDistance(from index: Int) -> CGFloat {
        let column = getVisualColumn(index: index, cellCount: count, cellsPerRow: cellsPerRow)
        let selectedColumn = getVisualColumn(index: selectedIndex, cellCount: count, cellsPerRow: cellsPerRow)

        return abs(column - selectedColumn)
    }
}
