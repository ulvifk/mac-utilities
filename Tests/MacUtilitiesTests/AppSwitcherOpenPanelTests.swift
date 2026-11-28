import AppKit
import Testing
@testable import MacUtilities

/// The open switcher end to end, on fakes: apps quitting while it is up, the app shortcuts, moving the selection, clicking a cell and
/// dragging the edge.
@MainActor @Suite(.serialized)
struct AppSwitcherOpenPanelTests {
    /// The panel width whose rows hold three app cells.
    static let threeAppCellWidth = 2 * horizontalPadding + 3 * iconCellMetrics.cellSize.width + 2 * itemSpacing

    // MARK: apps quitting

    @Test
    func selectedAppQuits() async throws {
        let harness = await openAppSwitcher()

        harness.workspace.onAppTerminated!(1)

        #expect(harness.log.appRemovals.map { $0.index } == [1], "Quit app's cell was not removed")
        #expect(try #require(harness.log.appRemovals.last).state.bundleIdentifiers == ["test.app.0", "test.app.2"], "Quit app is still listed")
        #expect(try #require(harness.log.appRemovals.last).state.list.selectedIndex == 1, "Selection did not move on to the next app")
        harness.releaseCommand()
        harness.expectActivation(listingWindows: false, selection: 2)
        await harness.finish()
    }

    @Test
    func earlierAppQuits() async throws {
        let harness = await openAppSwitcher()

        harness.workspace.onAppTerminated!(0)

        #expect(harness.log.appRemovals.map { $0.index } == [0], "Quit app's cell was not removed")
        #expect(try #require(harness.log.appRemovals.last).state.bundleIdentifiers == ["test.app.1", "test.app.2"], "Quit app is still listed")
        #expect(try #require(harness.log.appRemovals.last).state.list.selectedIndex == 0, "Selection left the selected app")
        harness.releaseCommand()
        harness.expectActivation(listingWindows: false, selection: 1)
        await harness.finish()
    }

    @Test
    func selectedLastListedAppQuits() async throws {
        let harness = await openAppSwitcher(backward: true)

        harness.workspace.onAppTerminated!(2)

        #expect(harness.log.appRemovals.map { $0.index } == [2], "Quit app's cell was not removed")
        #expect(try #require(harness.log.appRemovals.last).state.list.selectedIndex == 1, "Selection did not move to the new last app")
        harness.releaseCommand()
        harness.expectActivation(listingWindows: false, selection: 1)
        await harness.finish()
    }

    @Test
    func onlyAppQuits() async {
        let harness = await openAppSwitcher(itemCount: 1)

        harness.workspace.onAppTerminated!(0)

        #expect(harness.log.appRemovals.isEmpty, "Last app's removal was drawn instead of closing")
        #expect(!harness.panel.isVisible, "Switcher stayed open without apps")
        harness.releaseCommand()
        harness.expectNoActivation()
        await harness.finish()
    }

    @Test
    func unlistedAppQuits() async {
        let harness = await openAppSwitcher()

        harness.workspace.onAppTerminated!(99)

        #expect(harness.log.appRemovals.isEmpty, "Unlisted app's quit removed a cell")
        #expect(harness.panel.isVisible, "Unlisted app's quit closed the switcher")
        await harness.finish()
    }

    // MARK: apps quitting while windows are listed

    @Test
    func listedWindowsAppQuits() async {
        let harness = await openWindowSwitcher()

        harness.workspace.onAppTerminated!(0)

        #expect(!harness.panel.isVisible, "Switcher stayed open on the quit app's windows")
        harness.releaseCommand()
        await letMainQueueRun()
        harness.expectNoActivation()
        await harness.finish()
    }

    @Test
    func otherAppQuitsWhileWindowsAreListed() async {
        let harness = await openWindowSwitcher()

        harness.workspace.onAppTerminated!(1)

        #expect(harness.panel.isVisible, "Another app's quit closed the window list")
        harness.releaseCommand()
        await letMainQueueRun()
        harness.expectActivation(listingWindows: true, selection: 1)
        await harness.finish()
    }

    // MARK: app shortcuts

    @Test
    func whitelistToggle() async throws {
        let harness = await openAppSwitcher()

        harness.press(wKeyCode)
        await letMainQueueRun()
        #expect(harness.settings.whitelistStore.isListed("test.app.1"), "Cmd+W did not whitelist the selected app")
        #expect(try #require(harness.log.updatedStates.last).whitelisted == ["test.app.1"], "Cmd+W did not mark the app")

        harness.press(wKeyCode)
        await letMainQueueRun()
        #expect(!harness.settings.whitelistStore.isListed("test.app.1"), "Second Cmd+W did not take the app off the whitelist")
        #expect(try #require(harness.log.updatedStates.last).whitelisted.isEmpty, "Second Cmd+W did not unmark the app")
        #expect(getFeedbackTexts(harness) == [SwitcherFeedback.addedToWhitelist.text, SwitcherFeedback.removedFromWhitelist.text], "Wrong whitelist feedback")
        await harness.finish()
    }

    /// The system hides the app a moment later and says so; the second press then finds it hidden.
    @Test
    func hideAndSecondPress() async {
        let harness = await openAppSwitcher()

        harness.press(hKeyCode)
        await letMainQueueRun()
        #expect(harness.workspace.hiddenBundleIdentifiers == ["test.app.1"], "Cmd+H did not hide the selected app")
        #expect(getFeedbackTexts(harness) == [SwitcherFeedback.hidden.text], "Cmd+H feedback was lost")

        harness.workspace.runningApps[1].isHidden = true
        harness.workspace.onAppHiddenOrShown!()
        #expect(harness.log.updatedStates.count == 1, "Hidden app was not redrawn")

        harness.press(hKeyCode)
        await letMainQueueRun()
        #expect(harness.workspace.hiddenBundleIdentifiers == ["test.app.1"], "Second Cmd+H hid the app again")
        #expect(harness.log.feedback.count == 1, "Second Cmd+H showed feedback")
        #expect(harness.panel.isVisible, "Cmd+H closed the switcher")
        await harness.finish()
    }

    @Test
    func quitSelectedApp() async {
        let harness = await openAppSwitcher()

        harness.press(qKeyCode)
        await letMainQueueRun()

        #expect(harness.workspace.quitBundleIdentifiers == ["test.app.1"], "Cmd+Q did not quit the selected app")
        #expect(getFeedbackTexts(harness) == [SwitcherFeedback.quittingApp(name: "Test App").text], "Cmd+Q feedback was lost")
        #expect(harness.panel.isVisible, "Cmd+Q closed the switcher")
        await harness.finish()
    }

    @Test
    func appShortcutsDoNothingWhileListingWindows() async {
        let harness = AppSwitcherTestHarness()
        harness.press(graveKeyCode)
        await letMainQueueRun()

        harness.press(wKeyCode)
        harness.press(fKeyCode)
        harness.press(hKeyCode)
        harness.press(qKeyCode)
        harness.press(qKeyCode, modifiers: [.maskCommand, .maskShift])
        harness.press(tabKeyCode)
        await letMainQueueRun()

        #expect(harness.settings.whitelistStore.getWhitelist().isEmpty, "Cmd+W changed the whitelist")
        #expect(!harness.settings.whitelistStore.isFilterEnabled, "Cmd+F changed the filter")
        #expect(harness.workspace.hiddenBundleIdentifiers.isEmpty, "Cmd+H hid an app")
        #expect(harness.workspace.quitBundleIdentifiers.isEmpty, "Cmd+Q quit an app")
        #expect(harness.workspace.batchQuitCount == 0, "Cmd+Shift+Q ran Batch Quit")
        #expect(harness.log.updatedStates.isEmpty, "Cmd+Tab moved the window selection")
        #expect(harness.log.shownStates.count == 1, "An app shortcut rebuilt the panel")
        #expect(harness.log.feedback.isEmpty, "An app shortcut showed feedback")
        #expect(harness.panel.isVisible, "An app shortcut closed the switcher")
        await harness.finish()
    }

    // MARK: selection

    /// Five apps, three to a row, the bottom row of two centered under the top one.
    @Test
    func arrowsAndSwitchingMoveTheAppSelection() async throws {
        let harness = AppSwitcherTestHarness(itemCount: 5)
        harness.settings.panelWidthStore.setWidth(Self.threeAppCellWidth)
        harness.press(tabKeyCode)
        await letMainQueueRun()
        #expect(try #require(harness.log.shownStates.last).list.cellsPerRow == 3, "Panel width did not give three apps to a row")

        harness.press(rightArrowKeyCode)
        harness.press(leftArrowKeyCode)
        harness.press(leftArrowKeyCode)
        harness.press(leftArrowKeyCode)
        harness.press(upArrowKeyCode)
        harness.press(downArrowKeyCode)
        harness.press(tabKeyCode)
        harness.press(tabKeyCode, modifiers: [.maskCommand, .maskShift])

        #expect(harness.log.updatedStates.map { $0.list.selectedIndex } == [2, 1, 0, 4, 1, 3, 4, 3], "Wrong selection steps")
        harness.releaseCommand()
        harness.expectActivation(listingWindows: false, selection: 3)
        await harness.finish()
    }

    @Test
    func arrowsAndSwitchingMoveTheWindowSelection() async {
        let harness = AppSwitcherTestHarness()
        harness.press(graveKeyCode)
        await letMainQueueRun()

        harness.press(graveKeyCode)
        harness.press(graveKeyCode, modifiers: [.maskCommand, .maskShift])
        harness.press(rightArrowKeyCode)
        harness.press(rightArrowKeyCode)

        #expect(harness.log.updatedStates.map { $0.list.selectedIndex } == [2, 1, 2, 0], "Wrong selection steps")
        harness.releaseCommand()
        await letMainQueueRun()
        harness.expectActivation(listingWindows: true, selection: 0)
        await harness.finish()
    }

    // MARK: mouse

    @Test(arguments: [false, true])
    func clickActivatesTheCell(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        harness.press(listingWindows ? graveKeyCode : tabKeyCode)
        await letMainQueueRun()

        harness.panel.onCellClicked(2)
        await letMainQueueRun()

        #expect(!harness.panel.isVisible, "Click left the switcher open")
        harness.expectActivation(listingWindows: listingWindows, selection: 2)
        await harness.finish()
    }

    /// A click arriving after the switcher closed, such as one queued while Esc was handled.
    @Test
    func clickAfterCloseIsIgnored() async {
        let harness = await openAppSwitcher()
        harness.press(escapeKeyCode, modifiers: [])

        harness.panel.onCellClicked(2)
        await letMainQueueRun()

        harness.expectNoActivation()
        await harness.finish()
    }

    @Test
    func edgeDragRewrapsTheCells() async throws {
        let harness = await openAppSwitcher(itemCount: 5)
        #expect(try #require(harness.log.shownStates.last).list.cellsPerRow > 3, "Default width already held only three apps to a row")

        harness.panel.onWidthDragged(Self.threeAppCellWidth)

        #expect(harness.settings.panelWidthStore.width == Self.threeAppCellWidth, "Dragged width was not remembered")
        #expect(harness.log.resizedStates.count == 1, "Drag did not resize the panel")
        #expect(try #require(harness.log.resizedStates.last).list.cellsPerRow == 3, "Drag did not re-wrap the cells")
        #expect(try #require(harness.log.resizedStates.last).list.selectedIndex == 1, "Drag moved the selection")

        harness.press(downArrowKeyCode)
        #expect(try #require(harness.log.updatedStates.last).list.selectedIndex == 3, "Row navigation did not follow the new rows")
        await harness.finish()
    }

    /// Cmd released mid-drag closes the switcher under the drag.
    @Test
    func dragAfterCloseIsIgnored() async {
        let harness = await openAppSwitcher()
        harness.releaseCommand()

        harness.panel.onWidthDragged(Self.threeAppCellWidth)

        #expect(harness.log.resizedStates.isEmpty, "Drag resized a closed switcher")
        #expect(harness.settings.panelWidthStore.width == nil, "Drag on a closed switcher remembered its width")
        await harness.finish()
    }

    // MARK: helpers

    /// Cmd+Tab, or Cmd+Shift+Tab, with the panel up on the apps.
    private func openAppSwitcher(itemCount: Int = 3, backward: Bool = false) async -> AppSwitcherTestHarness {
        let harness = AppSwitcherTestHarness(itemCount: itemCount)

        harness.press(tabKeyCode, modifiers: backward ? [.maskCommand, .maskShift] : .maskCommand)
        await letMainQueueRun()

        return harness
    }

    /// Cmd+` with the panel up on the windows of test.app.0, the frontmost app, window 1 selected.
    private func openWindowSwitcher() async -> AppSwitcherTestHarness {
        let harness = AppSwitcherTestHarness()

        harness.press(graveKeyCode)
        await letMainQueueRun()

        return harness
    }

    private func getFeedbackTexts(_ harness: AppSwitcherTestHarness) -> [String] {
        return harness.log.feedback.map { $0.text }
    }
}
