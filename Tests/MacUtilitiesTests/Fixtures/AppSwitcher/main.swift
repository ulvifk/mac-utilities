import AppKit

_ = AppKit.NSApplication.shared.setActivationPolicy(.prohibited)
let settingsWindow = NSWindow(contentRect: NSRect(x: 360, y: 180, width: 720, height: 540),
                              styleMask: .titled, backing: .buffered, defer: false)

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
    SwitcherPanel.glassUpdatedStates = []
    SwitcherPanel.feedback = []
    SwitcherPanel.previewPositionCount = 0
    WhitelistStore.filterChanges = []
    BatchQuitStore.quitCount = 0
    GlassStore.stores = [:]
    AppSwitcherSettingsView.previewStore = nil
    ThumbnailRequest.requests = []
    AppQueries.runningApps = 0
    AppQueries.appsWithWindows = 0
    AppQueries.windows = 0
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

func showPreview(_ feature: AppSwitcherFeature, listingWindows: Bool = false) {
    _ = feature.buildSettingsSections()
    feature.settingsWindowChanged(settingsWindow)
    AppSwitcherSettingsView.previewStore.isListingWindows = listingWindows
    drainMainQueue()
    AppSwitcherSettingsView.previewStore.isShown = true
    drainMainQueue()
}

func setPreviewMode(listingWindows: Bool) {
    AppSwitcherSettingsView.previewStore.isListingWindows = listingWindows
    drainMainQueue()
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
    showPreview(feature)
    GlassStore.stores["appGlass"]!.objectWillChange.send()
    feature.stop()
    feature.start()
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.count == 1, "Stopped look change showed a preview")
    precondition(!SwitcherPanel.instances[1].isVisible, "Stop left the preview visible")
    precondition(!AppSwitcherSettingsView.previewStore.isShown, "Restart kept the preview checked")
}

runScenario("preview/queued-look-before-canceled-opening") { feature in
    showPreview(feature)
    GlassStore.stores["appGlass"]!.objectWillChange.send()
    press(feature, keyCode: tabKeyCode)
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.count == 2, "Canceled opening did not restore only the checked preview")
    precondition(SwitcherPanel.glassUpdatedStates.isEmpty, "Old look change changed the restored preview")
    precondition(SwitcherPanel.instances[1].isVisible, "Cancel lost the checked preview")
}

runScenario("preview/opening-keeps-own-list") { feature in
    showPreview(feature, listingWindows: true)
    press(feature, keyCode: tabKeyCode)
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    releaseCommand(feature)
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.count == 2, "Quick switching did not restore only the checked preview")
    precondition(SwitcherPanel.shownStates.last!.isListingWindows, "Quick switching did not restore the selected preview mode")
    expectActivation(listingWindows: false, selection: 1)
}

runScenario("preview/stale-thumbnail-after-switcher-opens") { feature in
    showPreview(feature, listingWindows: true)
    let oldCapture = ThumbnailRequest.requests[0]
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()
    oldCapture.completion(0, NSImage(size: NSSize(width: 1, height: 1)))

    precondition(!SwitcherPanel.instances[1].isVisible, "Opening kept the preview visible")
    precondition(SwitcherPanel.updatedStates.isEmpty, "Preview capture redrew the switcher")
}

runScenario("preview/stale-thumbnail-next-preview") { feature in
    showPreview(feature, listingWindows: true)
    let oldCapture = ThumbnailRequest.requests[0]
    setPreviewMode(listingWindows: false)
    setPreviewMode(listingWindows: true)
    oldCapture.completion(0, NSImage(size: NSSize(width: 1, height: 1)))

    precondition(SwitcherPanel.updatedStates.isEmpty, "Old preview capture redrew a later preview")
    ThumbnailRequest.requests[1].completion(0, NSImage(size: NSSize(width: 2, height: 2)))
    precondition(SwitcherPanel.updatedStates.count == 1, "New preview capture was lost")
}

runScenario("preview/continuous-window-look") { feature in
    showPreview(feature, listingWindows: true)
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    drainMainQueue()
    ThumbnailRequest.requests[0].completion(0, NSImage(size: NSSize(width: 2, height: 2)))

    precondition(SwitcherPanel.updatedStates.count == 1, "Continuous preview lost its capture")
    precondition(ThumbnailRequest.requests.count == 1, "Continuous preview repeated thumbnail capture")
    precondition(ThumbnailRequest.requests[0].windowIDs == [0], "Compact preview captured windows outside its sample")
}

for listingWindows in [false, true] {
    let list = listingWindows ? "windows" : "apps"
    runScenario("preview/\(list)-slider-reuses-list") { feature in
        let store = GlassStore.stores[listingWindows ? "windowGlass" : "appGlass"]!
        showPreview(feature, listingWindows: listingWindows)
        RecentAppsTracker.apps = [NSRunningApplication(index: 9)]
        AppWindow.windows = [AppWindow(windowID: 9)]

        for _ in 0..<20 {
            store.objectWillChange.send()
            drainMainQueue()
        }

        precondition(AppQueries.runningApps == 1, "Slider repeated running app queries")
        precondition(AppQueries.appsWithWindows == 1, "Slider repeated apps-with-windows queries")
        precondition(AppQueries.windows == (listingWindows ? 1 : 0), "Slider repeated window queries")
        precondition(SwitcherPanel.shownStates.count == 1, "Slider rebuilt the panel")
        precondition(SwitcherPanel.glassUpdatedStates.count == 20, "Slider lost appearance changes")
        let state = SwitcherPanel.glassUpdatedStates.last!
        precondition((listingWindows ? state.windows.count : state.apps.count) == (listingWindows ? 1 : 2), "Slider replaced preview candidates")
        precondition(ThumbnailRequest.requests.count == (listingWindows ? 1 : 0), "Slider repeated thumbnail capture")
    }
}

for listingWindows in [false, true] {
    let mode = listingWindows ? "window" : "app"
    runScenario("preview/\(mode)-cards-reuse-list") { feature in
        showPreview(feature, listingWindows: listingWindows)
        let cards = SwitcherCardStore.stores[mode + "Cards"]!
        cards.objectWillChange.send()
        cards.showsCards = true
        drainMainQueue()
        let glass = GlassStore.stores[mode + "CardGlass"]!
        glass.objectWillChange.send()
        drainMainQueue()

        precondition(AppQueries.runningApps == 1, "Card changes repeated app queries")
        precondition(AppQueries.windows == (listingWindows ? 1 : 0), "Card changes repeated window queries")
        precondition(SwitcherPanel.shownStates.count == 1, "Card changes rebuilt the panel")
        precondition(SwitcherPanel.glassUpdatedStates.count == 2, "Card changes lost appearance updates")
        precondition(SwitcherPanel.glassUpdatedStates.last!.cardGlass === glass, "Cards used the other mode's glass")
        precondition(ThumbnailRequest.requests.count == (listingWindows ? 1 : 0), "Card changes repeated thumbnail capture")

        cards.objectWillChange.send()
        cards.showsCards = false
        drainMainQueue()
        precondition(SwitcherPanel.glassUpdatedStates.last!.cardGlass == nil, "Cards-off did not clear the mode's card glass")
    }
}

runScenario("preview/mode-change-loads-fresh-list") { feature in
    showPreview(feature)
    AppWindow.windows = [AppWindow(windowID: 9)]
    setPreviewMode(listingWindows: true)

    precondition(AppQueries.runningApps == 2, "Mode change reused the old app query")
    precondition(AppQueries.windows == 1, "Mode change did not load windows")
    precondition(SwitcherPanel.shownStates.count == 2, "Mode change did not rebuild for windows")
    precondition(SwitcherPanel.shownStates.last!.windows.map { $0.windowID } == [9], "Mode change kept stale windows")
    precondition(ThumbnailRequest.requests[0].windowIDs == [9], "Mode change captured the old windows")
}

runScenario("preview/empty-mode-change-hides-list") { feature in
    showPreview(feature)
    AppWindow.windows = []
    setPreviewMode(listingWindows: true)

    precondition(!SwitcherPanel.instances[1].isVisible, "Empty window preview kept the app preview visible")
    precondition(SwitcherPanel.shownStates.count == 1, "Empty window preview built content")
    AppWindow.windows = [AppWindow(windowID: 9)]
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    drainMainQueue()
    precondition(SwitcherPanel.shownStates.last!.windows.map { $0.windowID } == [9], "Next preview did not recover after an empty list")
    precondition(AppQueries.windows == 2, "Next preview did not reload after an empty list")
}

runScenario("preview/normal-switcher-loads-fresh-list") { feature in
    showPreview(feature)
    RecentAppsTracker.apps = [NSRunningApplication(index: 9)]
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()

    precondition(!SwitcherPanel.instances[1].isVisible, "Normal switcher kept its preview visible")
    precondition(AppQueries.runningApps == 2, "Normal switcher reused preview candidates")
    precondition(SwitcherPanel.shownStates.last!.apps.map { $0.bundleIdentifier! } == ["test.app.9"], "Normal switcher kept stale preview apps")
}

runScenario("preview/stays-visible-until-unchecked") { feature in
    let store = GlassStore.stores["appGlass"]!
    showPreview(feature)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.1))
    precondition(SwitcherPanel.instances[1].isVisible, "Checked preview expired while settings stayed open")
    precondition(AppQueries.runningApps == 1, "Idle preview reloaded apps")

    AppSwitcherSettingsView.previewStore.isShown = false
    drainMainQueue()
    precondition(!SwitcherPanel.instances[1].isVisible, "Unchecked preview stayed visible")
    store.objectWillChange.send()
    drainMainQueue()
    precondition(!SwitcherPanel.instances[1].isVisible, "Appearance changes reopened an unchecked preview")

    RecentAppsTracker.apps = [NSRunningApplication(index: 9)]
    AppSwitcherSettingsView.previewStore.isShown = true
    drainMainQueue()

    precondition(AppQueries.runningApps == 2, "New preview did not reload after being unchecked")
    precondition(SwitcherPanel.shownStates.last!.apps.map { $0.bundleIdentifier! } == ["test.app.9"], "New preview kept candidates from before being unchecked")
}

runScenario("preview/unchecked-settings-suppress-look-changes") { feature in
    _ = feature.buildSettingsSections()
    feature.settingsWindowChanged(settingsWindow)
    GlassStore.stores["appGlass"]!.objectWillChange.send()
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.isEmpty, "Unchecked settings opened a preview")
    precondition(AppQueries.runningApps == 0, "Unchecked settings queried preview apps")
}

runScenario("preview/settings-exit-resets-and-rejects-queued-changes") { feature in
    showPreview(feature, listingWindows: true)
    let oldCapture = ThumbnailRequest.requests[0]
    GlassStore.stores["windowGlass"]!.objectWillChange.send()
    feature.settingsWindowChanged(nil)
    feature.settingsWindowChanged(settingsWindow)
    drainMainQueue()
    oldCapture.completion(0, NSImage(size: NSSize(width: 1, height: 1)))

    precondition(!AppSwitcherSettingsView.previewStore.isShown, "Settings reopening kept preview checked")
    precondition(!SwitcherPanel.instances[1].isVisible, "Queued change reopened a closed preview")
    precondition(SwitcherPanel.shownStates.count == 1, "Closing rebuilt a preview")
    precondition(SwitcherPanel.updatedStates.isEmpty, "Closed preview accepted an old thumbnail")
}

runScenario("preview/queued-checkbox-after-close") { feature in
    _ = feature.buildSettingsSections()
    feature.settingsWindowChanged(settingsWindow)
    AppSwitcherSettingsView.previewStore.isShown = true
    feature.settingsWindowChanged(nil)
    drainMainQueue()

    precondition(SwitcherPanel.shownStates.isEmpty, "Queued checkbox showed a preview after close")
    precondition(!AppSwitcherSettingsView.previewStore.isShown, "Close left the queued checkbox checked")
}

for listingWindows in [false, true] {
    let list = listingWindows ? "windows" : "apps"
    runScenario("preview/\(list)-other-settings-keep-selected-mode") { feature in
        showPreview(feature, listingWindows: listingWindows)
        GlassStore.stores[listingWindows ? "appGlass" : "windowGlass"]!.objectWillChange.send()
        drainMainQueue()

        precondition(AppSwitcherSettingsView.previewStore.isListingWindows == listingWindows, "Other settings changed the picker")
        precondition(SwitcherPanel.glassUpdatedStates.last!.isListingWindows == listingWindows, "Other settings changed the preview mode")
        precondition(SwitcherPanel.shownStates.count == 1, "Other settings rebuilt the preview")
        precondition(AppQueries.runningApps == 1, "Other settings repeated candidate queries")
    }

    runScenario("preview/\(list)-restores-after-other-switcher-cancel") { feature in
        showPreview(feature, listingWindows: listingWindows)
        press(feature, keyCode: listingWindows ? tabKeyCode : graveKeyCode)
        drainMainQueue()
        precondition(!SwitcherPanel.instances[1].isVisible, "Switching kept the preview visible")
        precondition(SwitcherPanel.shownStates.last!.isListingWindows != listingWindows, "Preview replaced the switcher's list")

        press(feature, keyCode: escapeKeyCode, modifiers: [])
        drainMainQueue()

        precondition(SwitcherPanel.instances[1].isVisible, "Cancel did not restore the checked preview")
        precondition(SwitcherPanel.shownStates.count == 3, "Cancel rebuilt more than one preview")
        precondition(SwitcherPanel.shownStates.last!.isListingWindows == listingWindows, "Cancel restored the wrong preview mode")
        expectNoActivation()
    }

    runScenario("preview/\(list)-restores-after-other-switcher-activation") { feature in
        showPreview(feature, listingWindows: listingWindows)
        press(feature, keyCode: listingWindows ? tabKeyCode : graveKeyCode)
        drainMainQueue()
        releaseCommand(feature)
        drainMainQueue()

        expectActivation(listingWindows: !listingWindows, selection: 1)
        precondition(SwitcherPanel.instances[1].isVisible, "Activation did not restore the checked preview")
        precondition(SwitcherPanel.shownStates.last!.isListingWindows == listingWindows, "Activation restored the wrong preview mode")
        precondition(SwitcherPanel.shownStates.last!.selectedIndex == 0, "Preview kept the switcher's selection")
    }
}

runScenario("preview/cancel-reopen-guards-restoration") { feature in
    showPreview(feature)
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    press(feature, keyCode: escapeKeyCode, modifiers: [])
    press(feature, keyCode: graveKeyCode)
    drainMainQueue()

    precondition(!SwitcherPanel.instances[1].isVisible, "Old cancel restored preview over a new switcher")
    precondition(SwitcherPanel.shownStates.count == 3, "Old cancel opened extra panels")
    precondition(SwitcherPanel.shownStates.last!.isListingWindows, "Old cancel replaced the new list")
    releaseCommand(feature)
    drainMainQueue()
    expectActivation(listingWindows: true, selection: 1)
}

runScenario("preview/close-during-switcher-prevents-restoration") { feature in
    showPreview(feature, listingWindows: true)
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    feature.settingsWindowChanged(nil)
    releaseCommand(feature)
    drainMainQueue()

    expectActivation(listingWindows: false, selection: 1)
    precondition(!SwitcherPanel.instances[1].isVisible, "Closing settings restored preview after activation")
    precondition(!AppSwitcherSettingsView.previewStore.isShown, "Closing during switching kept preview checked")
}

runScenario("preview/mode-change-during-switching-waits-for-cancel") { feature in
    showPreview(feature)
    press(feature, keyCode: tabKeyCode)
    drainMainQueue()
    setPreviewMode(listingWindows: true)
    precondition(!SwitcherPanel.instances[1].isVisible, "Picker reopened preview during switching")
    precondition(!SwitcherPanel.shownStates.last!.isListingWindows, "Picker changed the active switcher's list")

    press(feature, keyCode: escapeKeyCode, modifiers: [])
    drainMainQueue()
    precondition(SwitcherPanel.shownStates.last!.isListingWindows, "Cancel did not use the selected preview mode")
    expectNoActivation()
}

runScenario("preview/geometry-keeps-checked-list") { feature in
    showPreview(feature)
    feature.settingsWindowChanged(settingsWindow)

    precondition(AppSwitcherSettingsView.previewStore.isShown, "Geometry change unchecked the preview")
    precondition(SwitcherPanel.previewPositionCount == 1, "Geometry change did not reposition the visible preview")
    precondition(SwitcherPanel.shownStates.count == 1, "Geometry change rebuilt the preview")
    precondition(AppQueries.runningApps == 1, "Geometry change reloaded candidates")
    precondition(SwitcherPanel.instances[1].ignoresMouseEvents, "Preview prevented settings interaction")
}
