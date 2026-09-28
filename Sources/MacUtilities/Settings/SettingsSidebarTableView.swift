import AppKit

/// Selects a row the moment it is pressed: NSTableView itself commits a click's selection only once the mouse is released, which makes the
/// pane lag behind the highlight.
final class SettingsSidebarTableView: NSTableView {
    override func mouseDown(with event: NSEvent) {
        selectPressedRow(event)
        super.mouseDown(with: event)
    }

    private func selectPressedRow(_ event: NSEvent) {
        let row = row(at: convert(event.locationInWindow, from: nil))
        if !isSelectable(row) { return }

        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    /// Not below the last row, nor the gap.
    private func isSelectable(_ row: Int) -> Bool {
        if row < 0 { return false }
        return delegate!.tableView!(self, shouldSelectRow: row)
    }
}
