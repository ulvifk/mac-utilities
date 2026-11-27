import AppKit
import Testing
@testable import MacUtilities

/// The live preview beside the settings pane, on fakes: when it shows, hides and comes back around the switcher, which changes reuse its
/// list and which load a fresh one, and the queued work it must drop.
@MainActor @Suite(.serialized)
struct AppSwitcherPreviewTests {
    @Test
    func queuedLookAfterStop() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.settings.appGlassStore.objectWillChange.send()
        harness.feature.stop()
        harness.feature.start()
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.count == 1, "Stopped look change showed a preview")
        #expect(!harness.previewPanel.isVisible, "Stop left the preview visible")
        #expect(!harness.settings.previewStore.isShown, "Restart kept the preview checked")
        await harness.finish()
    }

    @Test
    func queuedLookBeforeCanceledOpening() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.settings.appGlassStore.objectWillChange.send()
        harness.press(tabKeyCode)
        harness.press(escapeKeyCode, modifiers: [])
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.count == 2, "Canceled opening did not restore only the checked preview")
        #expect(harness.log.glassUpdatedStates.isEmpty, "Old look change changed the restored preview")
        #expect(harness.previewPanel.isVisible, "Cancel lost the checked preview")
        await harness.finish()
    }

    @Test
    func openingKeepsOwnList() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: true)

        harness.press(tabKeyCode)
        harness.settings.windowGlassStore.objectWillChange.send()
        harness.releaseCommand()
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.count == 2, "Quick switching did not restore only the checked preview")
        #expect(harness.log.shownStates.last!.list.isListingWindows, "Quick switching did not restore the selected preview mode")
        harness.expectActivation(listingWindows: false, selection: 1)
        await harness.finish()
    }

    @Test
    func staleThumbnailAfterSwitcherOpens() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: true)
        let oldCapture = harness.screen.thumbnailRequests[0]

        harness.press(graveKeyCode)
        await harness.drainMainQueue()
        oldCapture.onCaptured(0, NSImage(size: NSSize(width: 1, height: 1)))

        #expect(!harness.previewPanel.isVisible, "Opening kept the preview visible")
        #expect(harness.log.updatedStates.isEmpty, "Preview capture redrew the switcher")
        await harness.finish()
    }

    @Test
    func staleThumbnailInNextPreview() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: true)
        let oldCapture = harness.screen.thumbnailRequests[0]

        await harness.setPreviewMode(listingWindows: false)
        await harness.setPreviewMode(listingWindows: true)
        oldCapture.onCaptured(0, NSImage(size: NSSize(width: 1, height: 1)))

        #expect(harness.log.updatedStates.isEmpty, "Old preview capture redrew a later preview")
        harness.screen.thumbnailRequests[1].onCaptured(0, NSImage(size: NSSize(width: 2, height: 2)))
        #expect(harness.log.updatedStates.count == 1, "New preview capture was lost")
        await harness.finish()
    }

    @Test
    func continuousWindowLook() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: true)

        harness.settings.windowGlassStore.objectWillChange.send()
        await harness.drainMainQueue()
        harness.screen.thumbnailRequests[0].onCaptured(0, NSImage(size: NSSize(width: 2, height: 2)))

        #expect(harness.log.updatedStates.count == 1, "Continuous preview lost its capture")
        #expect(harness.screen.thumbnailRequests.count == 1, "Continuous preview repeated thumbnail capture")
        #expect(harness.screen.thumbnailRequests[0].windowIDs == [0, 1, 2], "Preview did not capture the full window list")
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func sliderReusesList(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        let store = listingWindows ? harness.settings.windowGlassStore : harness.settings.appGlassStore
        await harness.showPreview(listingWindows: listingWindows)
        harness.workspace.runningApps = [harness.workspace.buildApp(index: 9)]
        harness.workspace.windows = [harness.workspace.buildWindow(windowID: 9)]

        for _ in 0..<20 {
            store.objectWillChange.send()
            await harness.drainMainQueue()
        }

        #expect(harness.workspace.runningAppQueryCount == 1, "Slider repeated running app queries")
        #expect(harness.workspace.appsWithWindowsQueryCount == 1, "Slider repeated apps-with-windows queries")
        #expect(harness.workspace.windowQueryCount == (listingWindows ? 1 : 0), "Slider repeated window queries")
        #expect(harness.log.shownStates.count == 1, "Slider rebuilt the panel")
        #expect(harness.log.glassUpdatedStates.count == 20, "Slider lost appearance changes")
        #expect(harness.log.glassUpdatedStates.last!.list.count == 3, "Slider replaced preview candidates")
        #expect(harness.screen.thumbnailRequests.count == (listingWindows ? 1 : 0), "Slider repeated thumbnail capture")
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func cardsReuseList(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        let cards = listingWindows ? harness.settings.windowCardStore : harness.settings.appCardStore
        let cardGlass = listingWindows ? harness.settings.windowCardGlassStore : harness.settings.appCardGlassStore
        await harness.showPreview(listingWindows: listingWindows)

        cards.setShowsCards(true)
        await harness.drainMainQueue()
        cardGlass.objectWillChange.send()
        await harness.drainMainQueue()

        #expect(harness.workspace.runningAppQueryCount == 1, "Card changes repeated app queries")
        #expect(harness.workspace.windowQueryCount == (listingWindows ? 1 : 0), "Card changes repeated window queries")
        #expect(harness.log.shownStates.count == 1, "Card changes rebuilt the panel")
        #expect(harness.log.glassUpdatedStates.count == 2, "Card changes lost appearance updates")
        #expect(harness.log.glassUpdatedStates.last!.cardGlass === cardGlass, "Cards used the other mode's glass")
        #expect(harness.screen.thumbnailRequests.count == (listingWindows ? 1 : 0), "Card changes repeated thumbnail capture")

        cards.setShowsCards(false)
        await harness.drainMainQueue()
        #expect(harness.log.glassUpdatedStates.last!.cardGlass == nil, "Cards-off did not clear the mode's card glass")
        await harness.finish()
    }

    @Test
    func modeChangeLoadsFreshList() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.workspace.windows = [harness.workspace.buildWindow(windowID: 9)]
        await harness.setPreviewMode(listingWindows: true)

        #expect(harness.workspace.runningAppQueryCount == 2, "Mode change reused the old app query")
        #expect(harness.workspace.windowQueryCount == 1, "Mode change did not load windows")
        #expect(harness.log.shownStates.count == 2, "Mode change did not rebuild for windows")
        #expect(harness.log.shownStates.last!.windowIDs == [9], "Mode change kept stale windows")
        #expect(harness.screen.thumbnailRequests[0].windowIDs == [9], "Mode change captured the old windows")
        await harness.finish()
    }

    @Test
    func emptyModeChangeHidesList() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.workspace.windows = []
        await harness.setPreviewMode(listingWindows: true)

        #expect(!harness.previewPanel.isVisible, "Empty window preview kept the app preview visible")
        #expect(harness.log.shownStates.count == 1, "Empty window preview built content")

        harness.workspace.windows = [harness.workspace.buildWindow(windowID: 9)]
        harness.settings.windowGlassStore.objectWillChange.send()
        await harness.drainMainQueue()
        #expect(harness.log.shownStates.last!.windowIDs == [9], "Next preview did not recover after an empty list")
        #expect(harness.workspace.windowQueryCount == 2, "Next preview did not reload after an empty list")
        await harness.finish()
    }

    @Test
    func normalSwitcherLoadsFreshList() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.workspace.runningApps = [harness.workspace.buildApp(index: 9)]
        harness.press(tabKeyCode)
        await harness.drainMainQueue()

        #expect(!harness.previewPanel.isVisible, "Normal switcher kept its preview visible")
        #expect(harness.workspace.runningAppQueryCount == 2, "Normal switcher reused preview candidates")
        #expect(harness.log.shownStates.last!.bundleIdentifiers == ["test.app.9"], "Normal switcher kept stale preview apps")
        await harness.finish()
    }

    @Test
    func staysVisibleUntilUnchecked() async throws {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        try await Task.sleep(for: .seconds(1.1))
        #expect(harness.previewPanel.isVisible, "Checked preview expired while settings stayed open")
        #expect(harness.workspace.runningAppQueryCount == 1, "Idle preview reloaded apps")

        harness.settings.previewStore.isShown = false
        await harness.drainMainQueue()
        #expect(!harness.previewPanel.isVisible, "Unchecked preview stayed visible")
        harness.settings.appGlassStore.objectWillChange.send()
        await harness.drainMainQueue()
        #expect(!harness.previewPanel.isVisible, "Appearance changes reopened an unchecked preview")

        harness.workspace.runningApps = [harness.workspace.buildApp(index: 9)]
        harness.settings.previewStore.isShown = true
        await harness.drainMainQueue()

        #expect(harness.workspace.runningAppQueryCount == 2, "New preview did not reload after being unchecked")
        #expect(harness.log.shownStates.last!.bundleIdentifiers == ["test.app.9"], "New preview kept candidates from before being unchecked")
        await harness.finish()
    }

    @Test
    func uncheckedSettingsSuppressLookChanges() async {
        let harness = AppSwitcherTestHarness()

        harness.feature.settingsWindowChanged(harness.settingsWindow)
        harness.settings.appGlassStore.objectWillChange.send()
        harness.settings.windowGlassStore.objectWillChange.send()
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.isEmpty, "Unchecked settings opened a preview")
        #expect(harness.workspace.runningAppQueryCount == 0, "Unchecked settings queried preview apps")
        await harness.finish()
    }

    @Test
    func settingsExitResetsAndRejectsQueuedChanges() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: true)
        let oldCapture = harness.screen.thumbnailRequests[0]

        harness.settings.windowGlassStore.objectWillChange.send()
        harness.feature.settingsWindowChanged(nil)
        harness.feature.settingsWindowChanged(harness.settingsWindow)
        await harness.drainMainQueue()
        oldCapture.onCaptured(0, NSImage(size: NSSize(width: 1, height: 1)))

        #expect(!harness.settings.previewStore.isShown, "Settings reopening kept preview checked")
        #expect(!harness.previewPanel.isVisible, "Queued change reopened a closed preview")
        #expect(harness.log.shownStates.count == 1, "Closing rebuilt a preview")
        #expect(harness.log.updatedStates.isEmpty, "Closed preview accepted an old thumbnail")
        await harness.finish()
    }

    @Test
    func queuedCheckboxAfterClose() async {
        let harness = AppSwitcherTestHarness()

        harness.feature.settingsWindowChanged(harness.settingsWindow)
        harness.settings.previewStore.isShown = true
        harness.feature.settingsWindowChanged(nil)
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.isEmpty, "Queued checkbox showed a preview after close")
        #expect(!harness.settings.previewStore.isShown, "Close left the queued checkbox checked")
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func otherSettingsKeepSelectedMode(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: listingWindows)

        (listingWindows ? harness.settings.appGlassStore : harness.settings.windowGlassStore).objectWillChange.send()
        await harness.drainMainQueue()

        #expect(harness.settings.previewStore.isListingWindows == listingWindows, "Other settings changed the picker")
        #expect(harness.log.glassUpdatedStates.last!.list.isListingWindows == listingWindows, "Other settings changed the preview mode")
        #expect(harness.log.shownStates.count == 1, "Other settings rebuilt the preview")
        #expect(harness.workspace.runningAppQueryCount == 1, "Other settings repeated candidate queries")
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func restoresAfterOtherSwitcherCancel(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: listingWindows)

        harness.press(listingWindows ? tabKeyCode : graveKeyCode)
        await harness.drainMainQueue()
        #expect(!harness.previewPanel.isVisible, "Switching kept the preview visible")
        #expect(harness.log.shownStates.last!.list.isListingWindows != listingWindows, "Preview replaced the switcher's list")

        harness.press(escapeKeyCode, modifiers: [])
        await harness.drainMainQueue()

        #expect(harness.previewPanel.isVisible, "Cancel did not restore the checked preview")
        #expect(harness.log.shownStates.count == 3, "Cancel rebuilt more than one preview")
        #expect(harness.log.shownStates.last!.list.isListingWindows == listingWindows, "Cancel restored the wrong preview mode")
        harness.expectNoActivation()
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func restoresAfterOtherSwitcherActivation(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: listingWindows)

        harness.press(listingWindows ? tabKeyCode : graveKeyCode)
        await harness.drainMainQueue()
        harness.releaseCommand()
        await harness.drainMainQueue()

        harness.expectActivation(listingWindows: !listingWindows, selection: 1)
        #expect(harness.previewPanel.isVisible, "Activation did not restore the checked preview")
        #expect(harness.log.shownStates.last!.list.isListingWindows == listingWindows, "Activation restored the wrong preview mode")
        #expect(harness.log.shownStates.last!.list.selectedIndex == 1, "Preview did not select the next app or window")
        await harness.finish()
    }

    @Test(arguments: [false, true], [false, true])
    func restoresAfterWindowActivation(listingWindows: Bool, releaseWhileOpening: Bool) async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: listingWindows)

        harness.press(graveKeyCode)
        if !releaseWhileOpening {
            await harness.drainMainQueue()
        }

        let runningAppQueriesBeforeActivation = harness.workspace.runningAppQueryCount
        let windowQueriesBeforeActivation = harness.workspace.windowQueryCount + (releaseWhileOpening ? 1 : 0)
        harness.workspace.onBringToFront = { window in
            #expect(!harness.panel.isVisible, "Window activation kept the switcher visible")
            #expect(!harness.previewPanel.isVisible, "Preview restored before window activation")
            #expect(harness.workspace.runningAppQueryCount == runningAppQueriesBeforeActivation, "Preview queried apps before window activation")
            #expect(harness.workspace.windowQueryCount == windowQueriesBeforeActivation, "Preview queried windows before window activation")

            harness.workspace.windows = [window] + harness.workspace.windows.filter { $0.windowID != window.windowID }
        }

        harness.releaseCommand()
        await harness.drainMainQueue()

        harness.expectActivation(listingWindows: true, selection: 1)
        #expect(harness.previewPanel.isVisible, "Window activation did not restore the checked preview")
        let restoredPreview = harness.log.shownStates.last!
        #expect(restoredPreview.list.isListingWindows == listingWindows, "Window activation restored the wrong preview mode")
        if listingWindows {
            #expect(restoredPreview.windowIDs == [1, 0, 2], "Restored preview kept the previous frontmost window")
        }
        await harness.finish()
    }

    @Test
    func cancelAndReopenGuardRestoration() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(escapeKeyCode, modifiers: [])
        harness.press(graveKeyCode)
        await harness.drainMainQueue()

        #expect(!harness.previewPanel.isVisible, "Old cancel restored preview over a new switcher")
        #expect(harness.log.shownStates.count == 3, "Old cancel opened extra panels")
        #expect(harness.log.shownStates.last!.list.isListingWindows, "Old cancel replaced the new list")
        harness.releaseCommand()
        await harness.drainMainQueue()
        harness.expectActivation(listingWindows: true, selection: 1)
        await harness.finish()
    }

    @Test
    func closeDuringSwitcherPreventsRestoration() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: true)

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.feature.settingsWindowChanged(nil)
        harness.releaseCommand()
        await harness.drainMainQueue()

        harness.expectActivation(listingWindows: false, selection: 1)
        #expect(!harness.previewPanel.isVisible, "Closing settings restored preview after activation")
        #expect(!harness.settings.previewStore.isShown, "Closing during switching kept preview checked")
        await harness.finish()
    }

    @Test
    func modeChangeDuringSwitchingWaitsForCancel() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        await harness.setPreviewMode(listingWindows: true)
        #expect(!harness.previewPanel.isVisible, "Picker reopened preview during switching")
        #expect(!harness.log.shownStates.last!.list.isListingWindows, "Picker changed the active switcher's list")

        harness.press(escapeKeyCode, modifiers: [])
        await harness.drainMainQueue()
        #expect(harness.log.shownStates.last!.list.isListingWindows, "Cancel did not use the selected preview mode")
        harness.expectNoActivation()
        await harness.finish()
    }

    /// Clicks passing through the preview to the pane are set where the system's preview panel is built, AppSwitcherFeatureFactory.
    @Test
    func geometryKeepsCheckedList() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.feature.settingsWindowChanged(harness.settingsWindow)

        #expect(harness.settings.previewStore.isShown, "Geometry change unchecked the preview")
        #expect(harness.log.previewPositionCount == 1, "Geometry change did not reposition the visible preview")
        #expect(harness.log.shownStates.count == 1, "Geometry change rebuilt the preview")
        #expect(harness.workspace.runningAppQueryCount == 1, "Geometry change reloaded candidates")
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func matchesSwitcher(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: listingWindows)
        let preview = harness.log.shownStates.last!

        harness.press(listingWindows ? graveKeyCode : tabKeyCode)
        await harness.drainMainQueue()
        let switcher = harness.log.shownStates.last!

        #expect(preview.bundleIdentifiers == switcher.bundleIdentifiers, "Preview app list differs from Cmd+Tab")
        #expect(preview.windowIDs == switcher.windowIDs, "Preview window list differs from Cmd+`")
        #expect(preview.list.cellsPerRow == switcher.list.cellsPerRow, "Preview width differs from the switcher")
        #expect(preview.list.selectedIndex == switcher.list.selectedIndex, "Preview selection differs from the switcher")
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func focusLossAndReturn(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview(listingWindows: listingWindows)

        harness.settingsWindow.hasFocus = false
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: harness.settingsWindow)
        #expect(!harness.previewPanel.isVisible, "Unfocused settings kept the preview visible")
        #expect(harness.settings.previewStore.isShown, "Focus loss cleared the preview preference")

        harness.settings.appGlassStore.objectWillChange.send()
        await harness.drainMainQueue()
        #expect(!harness.previewPanel.isVisible, "Appearance change reopened an unfocused preview")

        harness.settingsWindow.hasFocus = true
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: harness.settingsWindow)
        #expect(harness.previewPanel.isVisible, "Focus return did not restore the checked preview")
        #expect(harness.log.shownStates.count == 2, "Focus return did not load a fresh preview")
        await harness.finish()
    }

    @Test
    func hideAndUnhideRefreshIcons() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        harness.workspace.onAppHiddenOrShown!()
        harness.workspace.onAppHiddenOrShown!()

        #expect(harness.log.updatedStates.count == 2, "Preview missed hide or unhide notification")
        await harness.finish()
    }

    @Test
    func filterChangesRefreshList() async {
        let harness = AppSwitcherTestHarness()
        let whitelist = harness.settings.whitelistStore
        await harness.showPreview()

        whitelist.setListed("test.app.2", true)
        whitelist.setFilterEnabled(true)
        await harness.drainMainQueue()
        #expect(harness.log.shownStates.last!.bundleIdentifiers == ["test.app.2"], "Preview ignored the filter or whitelist")
        #expect(harness.log.shownStates.last!.list.items.isWhitelistOnly, "Preview omitted the whitelist badge")

        whitelist.setFilterEnabled(false)
        await harness.drainMainQueue()
        #expect(harness.log.shownStates.last!.list.count == 3, "Preview did not restore all apps")
        await harness.finish()
    }

    @Test
    func terminationRefreshesList() async {
        let harness = AppSwitcherTestHarness()
        await harness.showPreview()

        let terminated = harness.workspace.runningApps.removeLast()
        harness.workspace.onAppTerminated!(terminated.processIdentifier)

        #expect(harness.log.shownStates.last!.list.count == 2, "Preview kept a terminated app")
        await harness.finish()
    }
}
