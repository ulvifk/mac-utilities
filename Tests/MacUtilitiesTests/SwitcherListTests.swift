import AppKit
import Testing
@testable import MacUtilities

/// The list, its selection and the row arithmetic as pure values, and the loading of the apps from a fake workspace.
@MainActor
final class SwitcherListTests {
    private let workspace = SwitcherFakeWorkspace(itemCount: 5)
    private let testDefaults = TestDefaults()

    deinit {
        testDefaults.remove()
    }

    @Test(arguments: [(0, -1, 4), (0, 7, 2), (4, 1, 0), (2, -12, 0)])
    func advancingWrapsAroundBothEnds(selectedIndex: Int, step: Int, expected: Int) {
        #expect(buildAppList(cellsPerRow: 5).selecting(selectedIndex).advancing(by: step).selectedIndex == expected)
    }

    /// 5 items, 3 per row: the bottom row of 2 sits half a column in, under the gaps of the top row.
    @Test(arguments: [(1, false, 3), (2, false, 4), (0, false, 3), (3, true, 0), (4, true, 1), (0, true, 3), (4, false, 1)])
    func movingBetweenRowsPicksTheNearestDrawnCell(selectedIndex: Int, up: Bool, expected: Int) {
        #expect(buildAppList(cellsPerRow: 3).selecting(selectedIndex).movingBetweenRows(up: up).selectedIndex == expected)
    }

    @Test(arguments: [(1, 3, 1), (3, 1, 2), (2, 2, 2), (4, 4, 3)])
    func removingAppKeepsTheSelectionOnItsApp(selectedIndex: Int, removedIndex: Int, expectedIndex: Int) {
        let list = buildAppList(cellsPerRow: 5).selecting(selectedIndex)
        let selectedApp = list.selectedApp

        let remaining = list.removingApp(at: removedIndex)

        #expect(remaining.count == 4)
        #expect(remaining.selectedIndex == expectedIndex)
        if removedIndex != selectedIndex {
            #expect(remaining.selectedApp === selectedApp)
        }
    }

    @Test
    func removingTheOnlyAppLeavesAnEmptyList() {
        let list = SwitcherList(items: .apps([workspace.buildApp(index: 0)], whitelistOnly: true), cellsPerRow: 1)

        let remaining = list.removingApp(at: 0)

        #expect(remaining.isEmpty)
        #expect(remaining.items.isWhitelistOnly)
    }

    @Test
    func selectingAppFallsBackToTheFirst() {
        let list = buildAppList(cellsPerRow: 5)

        #expect(list.selectingApp(bundleIdentifier: "test.app.3").selectedIndex == 3)
        #expect(list.selecting(2).selectingApp(bundleIdentifier: "gone").selectedIndex == 0)
    }

    @Test
    func rewrappingKeepsItemsAndSelection() {
        let list = buildAppList(cellsPerRow: 5).selecting(3).rewrapping(cellsPerRow: 2)

        #expect(list.cellsPerRow == 2)
        #expect(list.selectedIndex == 3)
        #expect(list.count == 5)
    }

    // MARK: row width

    /// Icon cells are 68 wide with 5 between and 22 padding each side: a 1008 wide panel holds 13.3 of them.
    @Test
    func cellsPerRowIsNearestThePanelWidth() {
        #expect(iconCellMetrics.getCellsPerRow(itemCount: 3, panelWidth: 1008, screenSize: NSSize(width: 1440, height: 900)) == 13)
        #expect(iconCellMetrics.getCellsPerRow(itemCount: 3, panelWidth: 1008 + 36, screenSize: NSSize(width: 1440, height: 900)) == 14)
    }

    @Test
    func cellsPerRowIsHeldBetweenOneAndTheScreenWidth() {
        #expect(iconCellMetrics.getCellsPerRow(itemCount: 3, panelWidth: -400, screenSize: NSSize(width: 1440, height: 900)) == 1)
        #expect(iconCellMetrics.getCellsPerRow(itemCount: 3, panelWidth: 5000, screenSize: NSSize(width: 1440, height: 900)) == 19)
    }

    /// Window cells are 245 x 182: on a 600 high screen 2 rows fit under the hint band, so 7 windows need 4 per row, more than the width asks.
    @Test
    func cellsPerRowGrowsWhenTheRowsWouldRunPastTheScreen() {
        #expect(windowCellMetrics.getCellsPerRow(itemCount: 7, panelWidth: 300, screenSize: NSSize(width: 1440, height: 600)) == 4)
    }

    // MARK: loading

    @Test
    func loadsRecentAppsThenNeverActivatedOnes() {
        let loader = buildLoader(defaults: testDefaults.buildUserDefaults())
        workspace.recentBundleIdentifiers = ["test.app.3", "gone", "test.app.1"]

        let list = loader.loadAppList()

        #expect(getBundleIdentifiers(list) == ["test.app.3", "test.app.1", "test.app.0", "test.app.2", "test.app.4"])
        #expect(!list.items.isWhitelistOnly)
        #expect(list.selectedIndex == 0)
    }

    @Test
    func filterListsOnlyWhitelistedApps() {
        let defaults = testDefaults.buildUserDefaults()
        let whitelistStore = WhitelistStore(defaults: defaults)
        whitelistStore.setListed("test.app.2", true)
        whitelistStore.setFilterEnabled(true)

        let list = buildLoader(defaults: defaults).loadAppList()

        #expect(getBundleIdentifiers(list) == ["test.app.2"])
        #expect(list.items.isWhitelistOnly)
    }

    @Test
    func filterListsEveryAppWhileNoWhitelistedOneIsRunning() {
        let defaults = testDefaults.buildUserDefaults()
        let whitelistStore = WhitelistStore(defaults: defaults)
        whitelistStore.setListed("not.running", true)
        whitelistStore.setFilterEnabled(true)

        let list = buildLoader(defaults: defaults).loadAppList()

        #expect(list.count == 5)
        #expect(!list.items.isWhitelistOnly)
    }

    @Test
    func rowWidthFollowsTheRememberedPanelWidth() {
        let defaults = testDefaults.buildUserDefaults()
        PanelWidthStore(defaults: defaults).setWidth(44 + 2 * 68 + 5)

        let list = buildLoader(defaults: defaults).loadAppList()

        #expect(list.cellsPerRow == 2)
    }

    // MARK: helpers

    private func buildAppList(cellsPerRow: Int) -> SwitcherList {
        return SwitcherList(items: .apps(workspace.runningApps, whitelistOnly: false), cellsPerRow: cellsPerRow)
    }

    private func buildLoader(defaults: UserDefaults) -> SwitcherListLoader {
        return SwitcherListLoader(workspace: workspace, screen: SwitcherFakeScreen(), whitelistStore: WhitelistStore(defaults: defaults),
                                  panelWidthStore: PanelWidthStore(defaults: defaults))
    }

    private func getBundleIdentifiers(_ list: SwitcherList) -> [String] {
        guard case .apps(let apps, _) = list.items else { return [] }
        return apps.map { $0.bundleIdentifier }
    }
}
