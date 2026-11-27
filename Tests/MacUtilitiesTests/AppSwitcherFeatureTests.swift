import AppKit
import Testing
@testable import MacUtilities

/// The switcher's key handling end to end, on fakes: openings and the presses queued before the panel is up, cancelling, stopping, the app
/// shortcuts and the work they queue.
@MainActor @Suite(.serialized)
struct AppSwitcherFeatureTests {
    struct OpeningScenario: CustomTestStringConvertible, Sendable {
        let name: String
        let itemCount: Int
        let backwardPresses: [Bool]
        let expectedSelection: Int?

        var testDescription: String { name }
    }

    nonisolated static let openingScenarios = [
        OpeningScenario(name: "forward", itemCount: 5, backwardPresses: [false], expectedSelection: 1),
        OpeningScenario(name: "backward", itemCount: 5, backwardPresses: [true], expectedSelection: 4),
        OpeningScenario(name: "pending-forward", itemCount: 5, backwardPresses: [false, false, false], expectedSelection: 3),
        OpeningScenario(name: "pending-backward", itemCount: 5, backwardPresses: [true, true, true], expectedSelection: 2),
        OpeningScenario(name: "mixed-forward", itemCount: 5, backwardPresses: [false, true, false], expectedSelection: 1),
        OpeningScenario(name: "mixed-backward", itemCount: 5, backwardPresses: [true, false, true], expectedSelection: 4),
        OpeningScenario(name: "opposite-cancel", itemCount: 5, backwardPresses: [true, false], expectedSelection: 0),
        OpeningScenario(name: "backward-wrap", itemCount: 3, backwardPresses: [true, true, true, true, true, true, true], expectedSelection: 2),
        OpeningScenario(name: "forward-wrap", itemCount: 3, backwardPresses: [false, false, false, false, false, false, false], expectedSelection: 1),
        OpeningScenario(name: "single-forward", itemCount: 1, backwardPresses: [false], expectedSelection: 0),
        OpeningScenario(name: "single-backward", itemCount: 1, backwardPresses: [true, true], expectedSelection: 0),
        OpeningScenario(name: "empty-forward", itemCount: 0, backwardPresses: [false], expectedSelection: nil),
        OpeningScenario(name: "empty-backward", itemCount: 0, backwardPresses: [true], expectedSelection: nil),
    ]

    static func getSwitchingKeyCode(listingWindows: Bool) -> Int64 {
        return listingWindows ? graveKeyCode : tabKeyCode
    }

    // MARK: openings

    @Test(arguments: [false, true], openingScenarios)
    func opening(listingWindows: Bool, scenario: OpeningScenario) async {
        let harness = AppSwitcherTestHarness(itemCount: scenario.itemCount)

        for backward in scenario.backwardPresses {
            harness.press(Self.getSwitchingKeyCode(listingWindows: listingWindows), modifiers: backward ? [.maskCommand, .maskShift] : .maskCommand)
        }
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.last?.list.selectedIndex == scenario.expectedSelection)
        if let state = harness.log.shownStates.last {
            #expect(state.list.isListingWindows == listingWindows, "Wrong switcher list")
            #expect(harness.log.shownStates.count == 1, "Pending presses opened multiple panels")
        }
        await harness.finish()
        harness.expectNoActivation()
    }

    @Test(arguments: [false, true])
    func cancelOpening(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()

        harness.press(Self.getSwitchingKeyCode(listingWindows: listingWindows))
        harness.press(escapeKeyCode, modifiers: [])
        harness.releaseCommand()
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.isEmpty, "Canceled opening showed a panel")
        harness.expectNoActivation()
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func cancelAndReopen(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        let keyCode = Self.getSwitchingKeyCode(listingWindows: listingWindows)

        harness.press(keyCode)
        harness.press(escapeKeyCode, modifiers: [])
        harness.press(keyCode, modifiers: [.maskCommand, .maskShift])
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.count == 1, "Canceled work showed an extra panel")
        #expect(harness.log.shownStates.last!.list.selectedIndex == 2, "Canceled presses changed new selection")
        harness.expectNoActivation()
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func stopOpeningAndRestart(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()
        let keyCode = Self.getSwitchingKeyCode(listingWindows: listingWindows)

        harness.press(keyCode)
        harness.feature.stop()
        await harness.drainMainQueue()
        #expect(harness.log.shownStates.isEmpty, "Disabled feature showed a panel")

        harness.feature.start()
        harness.press(keyCode)
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.count == 1, "Restart opened stale work")
        #expect(harness.log.shownStates.last!.list.selectedIndex == 1, "Restart lost opening selection")
        harness.expectNoActivation()
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func quickCommandRelease(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()

        harness.press(Self.getSwitchingKeyCode(listingWindows: listingWindows), modifiers: [.maskCommand, .maskShift])
        harness.releaseCommand()
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.isEmpty, "Quick release showed a panel")
        harness.expectActivation(listingWindows: listingWindows, selection: 2)
        await harness.finish()
    }

    @Test(arguments: [false, true])
    func releaseVisibleSelection(listingWindows: Bool) async {
        let harness = AppSwitcherTestHarness()

        harness.press(Self.getSwitchingKeyCode(listingWindows: listingWindows))
        await harness.drainMainQueue()
        harness.releaseCommand()
        await harness.drainMainQueue()

        #expect(!harness.panel.isVisible, "Released panel stayed visible")
        harness.expectActivation(listingWindows: listingWindows, selection: 1)
        await harness.finish()
    }

    @Test
    func neverActivatedAppsFollowRecentOnes() async {
        let harness = AppSwitcherTestHarness()
        harness.workspace.recentBundleIdentifiers = ["test.app.2", "test.app.0"]

        harness.press(tabKeyCode)
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.last!.bundleIdentifiers == ["test.app.2", "test.app.0", "test.app.1"])
        await harness.finish()
    }

    // MARK: app shortcuts

    @Test
    func canceledFilter() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(fKeyCode)
        harness.press(escapeKeyCode, modifiers: [])
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.count == 1, "Canceled filter reopened the panel")
        #expect(!harness.settings.whitelistStore.isFilterEnabled, "Canceled filter changed the preference")
        #expect(harness.log.feedback.isEmpty, "Canceled filter showed feedback")
        await harness.finish()
    }

    @Test
    func staleFilterInNewSession() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(fKeyCode)
        harness.press(escapeKeyCode, modifiers: [])
        harness.press(tabKeyCode, modifiers: [.maskCommand, .maskShift])
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.count == 2, "Old filter rebuilt a new session")
        #expect(harness.log.shownStates.last!.list.selectedIndex == 2, "Old filter changed the new selection")
        #expect(!harness.settings.whitelistStore.isFilterEnabled, "Old filter changed a new session's preference")
        await harness.finish()
    }

    @Test
    func normalFilter() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(fKeyCode)
        await harness.drainMainQueue()

        #expect(harness.settings.whitelistStore.isFilterEnabled, "Filter was not applied")
        #expect(harness.log.shownStates.last!.list.selectedIndex == 1, "Filter lost the selected app")
        #expect(harness.log.feedback.count == 1, "Filter feedback was lost")
        await harness.finish()
    }

    @Test
    func stoppedFilterAndRestart() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(fKeyCode)
        harness.feature.stop()
        harness.feature.start()
        harness.press(tabKeyCode)
        await harness.drainMainQueue()

        #expect(harness.log.shownStates.count == 2, "Disabled filter reopened or rebuilt the panel")
        #expect(!harness.settings.whitelistStore.isFilterEnabled, "Disabled filter changed the preference")
        await harness.finish()
    }

    @Test
    func canceledFeedback() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(wKeyCode)
        harness.press(escapeKeyCode, modifiers: [])
        harness.press(tabKeyCode)
        await harness.drainMainQueue()

        #expect(harness.log.feedback.isEmpty, "Old feedback reached the new session")
        await harness.finish()
    }

    @Test
    func acceptedQuitAfterCancel() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(qKeyCode)
        harness.press(escapeKeyCode, modifiers: [])
        await harness.drainMainQueue()

        #expect(harness.workspace.quitBundleIdentifiers == ["test.app.1"], "Accepted quit was lost")
        #expect(harness.log.feedback.isEmpty, "Quit feedback outlived the switcher")
        await harness.finish()
    }

    @Test
    func acceptedBatchQuitAfterCancel() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(qKeyCode, modifiers: [.maskCommand, .maskShift])
        harness.press(escapeKeyCode, modifiers: [])
        harness.press(tabKeyCode)
        await harness.drainMainQueue()

        #expect(harness.workspace.batchQuitCount == 1, "Accepted batch quit was lost")
        #expect(harness.log.feedback.isEmpty, "Batch quit feedback reached the new session")
        await harness.finish()
    }

    @Test
    func normalBatchQuit() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(qKeyCode, modifiers: [.maskCommand, .maskShift])
        await harness.drainMainQueue()

        #expect(harness.workspace.batchQuitCount == 1, "Batch quit did not run")
        #expect(harness.log.feedback.count == 1, "Batch quit feedback was lost")
        await harness.finish()
    }

    @Test
    func stoppedBatchQuit() async {
        let harness = AppSwitcherTestHarness()

        harness.press(tabKeyCode)
        await harness.drainMainQueue()
        harness.press(qKeyCode, modifiers: [.maskCommand, .maskShift])
        harness.feature.stop()
        await harness.drainMainQueue()

        #expect(harness.workspace.batchQuitCount == 0, "Disabled feature ran batch quit")
        #expect(harness.log.feedback.isEmpty, "Disabled feature showed batch quit feedback")
        await harness.finish()
    }

    // MARK: windows

    @Test
    func stoppedCommittedWindowActivation() async {
        let harness = AppSwitcherTestHarness()

        harness.press(graveKeyCode)
        await harness.drainMainQueue()
        harness.releaseCommand()
        harness.feature.stop()
        harness.feature.start()
        harness.press(tabKeyCode)
        await harness.drainMainQueue()

        harness.expectNoActivation()
        #expect(harness.log.shownStates.count == 2, "Stopped activation reopened a panel")
        await harness.finish()
    }

    @Test
    func committedWindowActivationBeforeNextSession() async {
        let harness = AppSwitcherTestHarness()

        harness.press(graveKeyCode)
        await harness.drainMainQueue()
        harness.releaseCommand()
        harness.press(tabKeyCode)
        await harness.drainMainQueue()

        harness.expectActivation(listingWindows: true, selection: 1)
        #expect(!harness.log.shownStates.last!.list.isListingWindows, "Committed window activation changed the new list")
        await harness.finish()
    }

    @Test
    func consecutiveCommittedWindowActivations() async {
        let harness = AppSwitcherTestHarness()

        harness.press(graveKeyCode)
        await harness.drainMainQueue()
        harness.releaseCommand()
        harness.press(graveKeyCode, modifiers: [.maskCommand, .maskShift])
        harness.releaseCommand()
        await harness.drainMainQueue()

        #expect(harness.workspace.raisedWindowIDs == [1, 2], "Consecutive gestures dropped a committed activation")
        #expect(harness.log.shownStates.count == 1, "Second quick gesture showed a panel")
        await harness.finish()
    }

    @Test
    func staleThumbnailInNewSession() async {
        let harness = AppSwitcherTestHarness()

        harness.press(graveKeyCode)
        await harness.drainMainQueue()
        let oldCapture = harness.screen.thumbnailRequests[0]
        harness.press(escapeKeyCode, modifiers: [])
        harness.press(graveKeyCode)
        await harness.drainMainQueue()

        let newThumbnail = NSImage(size: NSSize(width: 2, height: 2))
        harness.screen.thumbnailRequests[1].onCaptured(1, newThumbnail)
        oldCapture.onCaptured(1, NSImage(size: NSSize(width: 1, height: 1)))
        #expect(harness.log.updatedStates.count == 1, "Old thumbnail redrew a new session")
        #expect(harness.log.updatedStates.last!.thumbnails[1] === newThumbnail, "Old thumbnail replaced the new capture")

        harness.press(escapeKeyCode, modifiers: [])
        harness.press(graveKeyCode)
        await harness.drainMainQueue()
        #expect(harness.log.shownStates.last!.thumbnails[1] === newThumbnail, "Accepted thumbnail was not cached")
        await harness.finish()
    }

    @Test
    func stoppedThumbnailAndRestart() async {
        let harness = AppSwitcherTestHarness()

        harness.press(graveKeyCode)
        await harness.drainMainQueue()
        let oldCapture = harness.screen.thumbnailRequests[0]
        harness.feature.stop()
        harness.feature.start()
        harness.press(graveKeyCode)
        await harness.drainMainQueue()
        oldCapture.onCaptured(1, NSImage(size: NSSize(width: 1, height: 1)))

        #expect(harness.log.updatedStates.isEmpty, "Stopped capture redrew a restarted panel")
        await harness.finish()
    }
}
