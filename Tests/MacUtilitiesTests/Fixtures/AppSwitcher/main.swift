import AppKit

struct OpeningScenario {
    let name: String
    let itemCount: Int
    let backwardPresses: [Bool]
    let expectedSelection: Int?
}

let scenarios = [
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

func resetFixtures(itemCount: Int = 3) {
    RecentAppsTracker.apps = (0..<itemCount).map { NSRunningApplication(index: $0) }
    AppWindow.windows = (0..<itemCount).map { AppWindow(windowID: CGWindowID($0)) }
    NSRunningApplication.activatedIdentifiers = []
    NSRunningApplication.quitIdentifiers = []
    NSRunningApplication.hiddenIdentifiers = []
    AppWindow.raisedWindowIDs = []
    SwitcherPanel.instances = []
    SwitcherPanel.shownStates = []
    SwitcherPanel.updatedStates = []
    SwitcherPanel.feedback = []
    WhitelistStore.filterChanges = []
    BatchQuitStore.quitCount = 0
    GlassStore.stores = [:]
    ThumbnailRequest.requests = []
}

func drainMainQueue() {
    for _ in 0..<2 {
        var completed = false
        DispatchQueue.main.async { completed = true }
        while !completed {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }
}

func press(_ feature: AppSwitcherFeature, keyCode: Int64, modifiers: CGEventFlags = .maskCommand) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)!
    event.flags = modifiers
    precondition(feature.handle(type: .keyDown, event: event), "Shortcut \(keyCode) was not handled")
}

func releaseCommand(_ feature: AppSwitcherFeature) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!
    event.flags = []
    precondition(!feature.handle(type: .flagsChanged, event: event), "Command release must pass through")
}

func expectNoActivation() {
    precondition(NSRunningApplication.activatedIdentifiers.isEmpty, "Unexpected app activation")
    precondition(AppWindow.raisedWindowIDs.isEmpty, "Unexpected window activation")
}

func expectActivation(listingWindows: Bool, selection: Int) {
    if listingWindows {
        precondition(AppWindow.raisedWindowIDs == [CGWindowID(selection)], "Wrong window activated")
        precondition(NSRunningApplication.activatedIdentifiers.isEmpty, "Window switching activated all app windows")
        return
    }

    precondition(NSRunningApplication.activatedIdentifiers == ["test.app.\(selection)"], "Wrong app activated")
    precondition(AppWindow.raisedWindowIDs.isEmpty, "App switching raised a window")
}

func runScenario(_ name: String, _ scenario: (AppSwitcherFeature) -> Void) {
    resetFixtures()
    let feature = AppSwitcherFeature()
    feature.start()

    scenario(feature)

    feature.stop()
    drainMainQueue()
    print("PASS \(name)")
}

for listingWindows in [false, true] {
    for scenario in scenarios {
        resetFixtures(itemCount: scenario.itemCount)
        let feature = AppSwitcherFeature()
        feature.start()

        for backward in scenario.backwardPresses {
            press(feature, keyCode: listingWindows ? graveKeyCode : tabKeyCode,
                  modifiers: backward ? [.maskCommand, .maskShift] : .maskCommand)
        }

        drainMainQueue()

        let actualSelection = SwitcherPanel.shownStates.last?.selectedIndex
        let list = listingWindows ? "windows" : "apps"
        precondition(actualSelection == scenario.expectedSelection, "\(list)/\(scenario.name): expected \(String(describing: scenario.expectedSelection)), got \(String(describing: actualSelection))")
        if let state = SwitcherPanel.shownStates.last {
            precondition(state.isListingWindows == listingWindows, "Wrong switcher list")
            precondition(SwitcherPanel.shownStates.count == 1, "Pending presses opened multiple panels")
        }

        feature.stop()
        expectNoActivation()
        print("PASS \(list)/\(scenario.name)")
    }
}

for listingWindows in [false, true] {
    let keyCode = listingWindows ? graveKeyCode : tabKeyCode
    let list = listingWindows ? "windows" : "apps"

    runScenario("\(list)/cancel-opening") { feature in
        press(feature, keyCode: keyCode)
        press(feature, keyCode: escapeKeyCode, modifiers: [])
        releaseCommand(feature)
        drainMainQueue()

        precondition(SwitcherPanel.shownStates.isEmpty, "Canceled opening showed a panel")
        expectNoActivation()
    }

    runScenario("\(list)/cancel-and-reopen") { feature in
        press(feature, keyCode: keyCode)
        press(feature, keyCode: escapeKeyCode, modifiers: [])
        press(feature, keyCode: keyCode, modifiers: [.maskCommand, .maskShift])
        drainMainQueue()

        precondition(SwitcherPanel.shownStates.count == 1, "Canceled work showed an extra panel")
        precondition(SwitcherPanel.shownStates.last!.selectedIndex == 2, "Canceled presses changed new selection")
        expectNoActivation()
    }

    runScenario("\(list)/stop-opening-and-restart") { feature in
        press(feature, keyCode: keyCode)
        feature.stop()
        drainMainQueue()
        precondition(SwitcherPanel.shownStates.isEmpty, "Disabled feature showed a panel")

        feature.start()
        press(feature, keyCode: keyCode)
        drainMainQueue()

        precondition(SwitcherPanel.shownStates.count == 1, "Restart opened stale work")
        precondition(SwitcherPanel.shownStates.last!.selectedIndex == 1, "Restart lost opening selection")
        expectNoActivation()
    }

    runScenario("\(list)/quick-command-release") { feature in
        press(feature, keyCode: keyCode, modifiers: [.maskCommand, .maskShift])
        releaseCommand(feature)
        drainMainQueue()

        precondition(SwitcherPanel.shownStates.isEmpty, "Quick release showed a panel")
        expectActivation(listingWindows: listingWindows, selection: 2)
    }

    runScenario("\(list)/release-visible-selection") { feature in
        press(feature, keyCode: keyCode)
        drainMainQueue()
        releaseCommand(feature)
        drainMainQueue()

        precondition(!SwitcherPanel.instances[0].isVisible, "Released panel stayed visible")
        expectActivation(listingWindows: listingWindows, selection: 1)
    }
}

runScenario("apps/canceled-filter") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: fKeyCode)
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.count == 1, "Canceled filter reopened the panel")
    precondition(WhitelistStore.filterChanges.isEmpty, "Canceled filter changed the preference")
    precondition(SwitcherPanel.feedback.isEmpty, "Canceled filter showed feedback")
}

runScenario("apps/stale-filter-new-session") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: fKeyCode)
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    press(feature, keyCode: tabKeyCode, modifiers: [.maskCommand, .maskShift])
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.count == 2, "Old filter rebuilt a new session")
    precondition(SwitcherPanel.shownStates.last!.selectedIndex == 2, "Old filter changed the new selection")
    precondition(WhitelistStore.filterChanges.isEmpty, "Old filter changed a new session's preference")
}

runScenario("apps/normal-filter") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: fKeyCode)
    drainMainQueue()

    precondition(WhitelistStore.filterChanges == [true], "Filter was not applied")
    precondition(SwitcherPanel.shownStates.last!.selectedIndex == 1, "Filter lost the selected app")
    precondition(SwitcherPanel.feedback.count == 1, "Filter feedback was lost")
}

runScenario("apps/stopped-filter-and-restart") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: fKeyCode)
    feature.stop()
    feature.start()
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.count == 2, "Disabled filter reopened or rebuilt the panel")
    precondition(WhitelistStore.filterChanges.isEmpty, "Disabled filter changed the preference")
}

runScenario("apps/canceled-feedback") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: wKeyCode)
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()

    precondition(SwitcherPanel.feedback.isEmpty, "Old feedback reached the new session")
}

runScenario("apps/accepted-quit-after-cancel") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: qKeyCode)
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    drainMainQueue()

    precondition(NSRunningApplication.quitIdentifiers == ["test.app.1"], "Accepted quit was lost")
    precondition(SwitcherPanel.feedback.isEmpty, "Quit feedback outlived the switcher")
}

runScenario("apps/accepted-batch-quit-after-cancel") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: qKeyCode, modifiers: [.maskCommand, .maskShift])
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()

    precondition(BatchQuitStore.quitCount == 1, "Accepted batch quit was lost")
    precondition(SwitcherPanel.feedback.isEmpty, "Batch quit feedback reached the new session")
}

runScenario("apps/normal-batch-quit") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: qKeyCode, modifiers: [.maskCommand, .maskShift])
    drainMainQueue()

    precondition(BatchQuitStore.quitCount == 1, "Batch quit did not run")
    precondition(SwitcherPanel.feedback.count == 1, "Batch quit feedback was lost")
}

runScenario("apps/stopped-batch-quit") { feature in
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: qKeyCode, modifiers: [.maskCommand, .maskShift])
    feature.stop()
    drainMainQueue()

    precondition(BatchQuitStore.quitCount == 0, "Disabled feature ran batch quit")
    precondition(SwitcherPanel.feedback.isEmpty, "Disabled feature showed batch quit feedback")
}

runScenario("windows/stopped-committed-activation") { feature in
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    releaseCommand(feature)
    feature.stop()
    feature.start()
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()

    expectNoActivation()
    precondition(SwitcherPanel.shownStates.count == 2, "Stopped activation reopened a panel")
}

runScenario("windows/committed-activation-next-session") { feature in
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    releaseCommand(feature)
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()

    expectActivation(listingWindows: true, selection: 1)
    precondition(!SwitcherPanel.shownStates.last!.isListingWindows, "Committed window activation changed the new list")
}

runScenario("windows/consecutive-committed-activations") { feature in
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    releaseCommand(feature)
    press(feature, keyCode: graveKeyCode, modifiers: [.maskCommand, .maskShift])
    releaseCommand(feature)
    drainMainQueue()

    precondition(AppWindow.raisedWindowIDs == [1, 2], "Consecutive gestures dropped a committed activation")
    precondition(SwitcherPanel.shownStates.count == 1, "Second quick gesture showed a panel")
}

runScenario("windows/stale-thumbnail-new-session") { feature in
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    let oldCapture = ThumbnailRequest.requests[0]
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()

    let newThumbnail = NSImage(size: NSSize(width: 2, height: 2))
    ThumbnailRequest.requests[1].completion(1, newThumbnail)
    oldCapture.completion(1, NSImage(size: NSSize(width: 1, height: 1)))
    precondition(SwitcherPanel.updatedStates.count == 1, "Old thumbnail redrew a new session")
    precondition(SwitcherPanel.updatedStates.last!.thumbnails[1] === newThumbnail, "Old thumbnail replaced the new capture")

    press(feature, keyCode: escapeKeyCode, modifiers: [])
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    precondition(SwitcherPanel.shownStates.last!.thumbnails[1] === newThumbnail, "Accepted thumbnail was not cached")
}

runScenario("windows/stopped-thumbnail-and-restart") { feature in
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    let oldCapture = ThumbnailRequest.requests[0]
    feature.stop()
    feature.start()
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    oldCapture.completion(1, NSImage(size: NSSize(width: 1, height: 1)))

    precondition(SwitcherPanel.updatedStates.isEmpty, "Stopped capture redrew a restarted panel")
}

runScenario("preview/queued-look-after-stop") { feature in
    GlassStore.stores["appGlass"]!.objectWillChange.send()
    feature.stop()
    feature.start()
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.isEmpty, "Stopped look change showed a preview")
}

runScenario("preview/queued-look-before-canceled-opening") { feature in
    GlassStore.stores["appGlass"]!.objectWillChange.send()
    press(feature, keyCode: tabKeyCode)
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.isEmpty, "Old look change appeared after canceled opening")
}

runScenario("preview/opening-keeps-own-list") { feature in
    press(feature, keyCode: tabKeyCode)
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    releaseCommand(feature)
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.isEmpty, "Queued preview replaced a quick switch")
    expectActivation(listingWindows: false, selection: 1)
}

runScenario("preview/stale-thumbnail-after-switcher-opens") { feature in
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    drainMainQueue()
    let oldCapture = ThumbnailRequest.requests[0]
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    oldCapture.completion(1, NSImage(size: NSSize(width: 1, height: 1)))

    precondition(!SwitcherPanel.instances[1].isVisible, "Opening kept the preview visible")
    precondition(SwitcherPanel.updatedStates.isEmpty, "Preview capture redrew the switcher")
}

runScenario("preview/stale-thumbnail-next-preview") { feature in
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    drainMainQueue()
    let oldCapture = ThumbnailRequest.requests[0]
    GlassStore.stores["appGlass"]!.objectWillChange.send()
    drainMainQueue()
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    drainMainQueue()
    oldCapture.completion(1, NSImage(size: NSSize(width: 1, height: 1)))

    precondition(SwitcherPanel.updatedStates.isEmpty, "Old preview capture redrew a later preview")
    ThumbnailRequest.requests[1].completion(1, NSImage(size: NSSize(width: 2, height: 2)))
    precondition(SwitcherPanel.updatedStates.count == 1, "New preview capture was lost")
}

runScenario("preview/continuous-window-look") { feature in
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    drainMainQueue()
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    drainMainQueue()
    ThumbnailRequest.requests[0].completion(1, NSImage(size: NSSize(width: 2, height: 2)))

    precondition(SwitcherPanel.updatedStates.count == 1, "Continuous preview lost its capture")
    precondition(ThumbnailRequest.requests.count == 1, "Continuous preview repeated thumbnail capture")
}
