import AppKit

/// The sidebar: General, a gap, then one row per feature, reporting the selected row's pane.
final class SettingsSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onSelect: (String) -> Void = { _ in }

    /// [row] -> its cell, nil for the gap setting General apart from the features
    private let cells: [SettingsSidebarCellView?]
    private let tableView = SettingsSidebarTableView()

    init(panes: [SettingsPane]) {
        let featureCells: [SettingsSidebarCellView?] = panes.dropFirst().map { SettingsSidebarCellView(pane: $0) }

        cells = [SettingsSidebarCellView(pane: panes[0]), nil] + featureCells
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("never decoded from a nib")
    }

    override func loadView() {
        let scrollView = NSScrollView()

        tableView.addTableColumn(NSTableColumn())
        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.allowsEmptySelection = false
        tableView.dataSource = self
        tableView.delegate = self
        scrollView.documentView = tableView
        scrollView.drawsBackground = false

        view = scrollView
    }

    func select(_ paneIdentifier: String) {
        let row = cells.firstIndex { $0?.paneIdentifier == paneIdentifier }!

        loadViewIfNeeded()
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return cells.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return cells[row]
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if cells[row] == nil { return sidebarGapHeight }
        return sidebarRowHeight
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return cells[row] != nil
    }

    /// Posted the moment a row is pressed, and for the arrow keys.
    func tableViewSelectionDidChange(_ notification: Notification) {
        onSelect(cells[tableView.selectedRow]!.paneIdentifier)
    }
}
