import AppKit
import Combine
import SwiftUI

/// Replaces Cmd+Tab with the switcher panel, filtered to the whitelist when the filter is on, and Cmd+` with the same panel listing the
/// frontmost app's windows.
final class AppSwitcherFeature: Feature {
    let identifier = "app-switcher"
    let displayName = "App Switcher"
    let summary = "Replaces ⌘Tab and ⌘` with a glass switcher for apps and their windows."
    let iconSymbolName = "rectangle.stack.fill"
    let iconGradient = Gradient(colors: [.blue, .indigo])

    private let panel: SwitcherPanel
    /// Shows the glass live while it is set in the settings pane; clicks pass through it to the pane.
    private let previewPanel: SwitcherPanel
    private let tracker = RecentAppsTracker()
    private let whitelistStore = WhitelistStore()
    private let batchQuitStore = BatchQuitStore()
    private let appGlassStore = GlassStore(keyPrefix: "appGlass", defaultDarkness: defaultGlassDarkness)
    private let windowGlassStore = GlassStore(keyPrefix: "windowGlass", defaultDarkness: defaultGlassDarkness)
    private let windowCardStore = WindowCardStore()
    private let windowCardGlassStore = GlassStore(keyPrefix: "windowCardGlass", defaultDarkness: defaultWindowCardDarkness)
    private let panelWidthStore = PanelWidthStore()
    private var observers: [NSObjectProtocol] = []
    private var lookChanges: [AnyCancellable] = []
    private var previewHiding: DispatchWorkItem?

    private var isListingWindows = false
    /// Empty while windows are listed.
    private var candidates: [NSRunningApplication] = []
    /// Empty while apps are listed.
    private var windows: [AppWindow] = []
    /// [window id] -> the window's latest thumbnail, kept until another app's windows are listed so reopening shows it at once
    private var thumbnails: [CGWindowID: NSImage] = [:]
    private var isFiltered = false
    private var cellsPerRow = 1
    private var selectedIndex = 0

    private var isOpening = false
    private var commandReleasedWhileOpening = false
    private var pendingAdvance = 0
    private var featureSession = 0
    private var switcherSession = 0
    private var previewSession = 0

    init() {
        panel = SwitcherPanel()
        previewPanel = SwitcherPanel()

        previewPanel.ignoresMouseEvents = true
        wirePanel()
    }

    func start() {
        enableCursorChangesWhileInactive()
        tracker.start()
        observers.append(observeAppTermination())
        observers.append(contentsOf: observeAppHiding())
        lookChanges.append(observeLookChanges(of: appGlassStore, listingWindows: false))
        lookChanges.append(observeLookChanges(of: windowGlassStore, listingWindows: true))
        lookChanges.append(observeLookChanges(of: windowCardStore, listingWindows: true))
        lookChanges.append(observeLookChanges(of: windowCardGlassStore, listingWindows: true))
        runSmokeTestIfRequested()
    }

    func stop() {
        featureSession += 1

        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers = []
        lookChanges = []
        tracker.stop()
        dismissSwitcher()
        hidePreview()
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .keyDown {
            return handleKeyDown(event)
        }

        if type == .flagsChanged {
            handleFlagsChanged(event)
        }

        return false
    }

    func buildSettingsSections() -> AnyView {
        return AnyView(AppSwitcherSettingsView(
            whitelistStore: whitelistStore,
            batchQuitStore: batchQuitStore,
            appGlassStore: appGlassStore,
            windowGlassStore: windowGlassStore,
            windowCardStore: windowCardStore,
            windowCardGlassStore: windowCardGlassStore
        ))
    }

    func buildPopoverTile() -> AnyView? {
        return nil
    }

    private func runSmokeTestIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["APP_SWITCHER_SMOKE_TEST"] != nil else { return }

        whitelistStore.setFilterEnabled(environment["APP_SWITCHER_SMOKE_FILTER"] == "1")
        let session = featureSession

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.featureSession != session { return }

            self.loadCandidates(listingWindows: environment["APP_SWITCHER_SMOKE_WINDOWS"] == "1")
            self.selectedIndex = Int(environment["APP_SWITCHER_SMOKE_INDEX"] ?? "1")!
            self.showPanel()
            showCaptureBackdrop(behind: self.panel)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 + hintDelay) {
            if self.featureSession != session { return }

            print("smoke: frame=\(self.panel.frame) visible=\(self.panel.isVisible) alpha=\(self.panel.alphaValue) apps=\(self.candidates.count) windows=\(self.windows.count) selected=\(self.selectedIndex)")
            print("smoke: candidates=\(self.candidates.compactMap { $0.localizedName }) windows=\(self.windows.map { $0.title }) thumbnails=\(self.thumbnails.count)")
            writeCapture(around: self.panel, path: smokeCapturePath)
            exit(0)
        }
    }

    // MARK: wiring

    private func wirePanel() {
        panel.onCellClicked = { index in
            self.selectedIndex = index
            self.activateSelection()
        }
        panel.onWidthDragged = { width in
            self.resizePanel(toWidth: width)
        }
    }

    private func observeAppTermination() -> NSObjectProtocol {
        return NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            if !self.panel.isVisible { return }

            let app = notification.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
            guard let index = self.candidates.firstIndex(where: { $0.processIdentifier == app.processIdentifier }) else { return }

            self.removeCandidate(at: index)
        }
    }

    /// Redraws the dimming once the app is really hidden or shown, whether it was our Cmd+H or done elsewhere.
    private func observeAppHiding() -> [NSObjectProtocol] {
        var observers: [NSObjectProtocol] = []

        for name in [NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                if !self.panel.isVisible { return }

                self.panel.update(state: self.buildState())
            })
        }

        return observers
    }

    /// The store announces a change before making it; the main queue runs the preview of the list it styles after, and also while a slider
    /// is being dragged.
    private func observeLookChanges(of store: some ObservableObject, listingWindows: Bool) -> AnyCancellable {
        return store.objectWillChange
            .map { _ in self.switcherSession }
            .receive(on: DispatchQueue.main)
            .sink { session in
                if self.switcherSession != session { return }

                self.previewGlass(listingWindows: listingWindows)
            }
    }

    // MARK: events

    /// Never does real work: macOS disables a tap whose callback is slow, and the keystroke then falls through to the Dock.
    private func handleKeyDown(_ event: CGEvent) -> Bool {
        if panel.isVisible {
            return handleKeyDownWhileVisible(event)
        }

        if isOpening {
            if isCancelShortcut(event) {
                dismissSwitcher()
                return true
            }
        }

        if isSwitcherShortcut(event) {
            requestOpening(listingWindows: false, backward: event.flags.contains(.maskShift))
            return true
        }

        if isWindowSwitcherShortcut(event) {
            requestOpening(listingWindows: true, backward: event.flags.contains(.maskShift))
            return true
        }

        return false
    }

    /// Presses arriving before the panel is up only advance the selection it opens with.
    private func requestOpening(listingWindows: Bool, backward: Bool) {
        let step = backward ? -1 : 1

        if isOpening {
            pendingAdvance += step
            return
        }

        isOpening = true
        commandReleasedWhileOpening = false
        pendingAdvance = step
        switcherSession += 1
        hidePreview()

        let session = switcherSession
        DispatchQueue.main.async {
            if self.switcherSession != session { return }

            self.openSwitcher(listingWindows: listingWindows)
        }
    }

    private func openSwitcher(listingWindows: Bool) {
        loadCandidates(listingWindows: listingWindows)
        isOpening = false

        let itemCount = getItemCount()
        if itemCount == 0 { return }

        selectedIndex = (pendingAdvance % itemCount + itemCount) % itemCount

        if commandReleasedWhileOpening {
            activateSelection()
            return
        }

        showPanel()
    }

    private func handleKeyDownWhileVisible(_ event: CGEvent) -> Bool {
        if isListedSwitcherShortcut(event) {
            advanceSelection(backward: event.flags.contains(.maskShift))
            return true
        }

        if isAnySwitcherShortcut(event) {
            return true
        }

        if isForwardShortcut(event) {
            advanceSelection(backward: false)
            return true
        }

        if isBackwardShortcut(event) {
            advanceSelection(backward: true)
            return true
        }

        if isRowUpShortcut(event) {
            moveSelectionBetweenRows(up: true)
            return true
        }

        if isRowDownShortcut(event) {
            moveSelectionBetweenRows(up: false)
            return true
        }

        if isCancelShortcut(event) {
            dismissSwitcher()
            return true
        }

        if isListingWindows {
            return isAppShortcut(event)
        }

        if isWhitelistToggleShortcut(event) {
            let bundleIdentifier = candidates[selectedIndex].bundleIdentifier!
            let listed = !whitelistStore.isListed(bundleIdentifier)
            whitelistStore.setListed(bundleIdentifier, listed)
            panel.update(state: buildState())
            showFeedback(listed ? .addedToWhitelist : .removedFromWhitelist)
            return true
        }

        if isFilterToggleShortcut(event) {
            let session = switcherSession
            DispatchQueue.main.async {
                if self.switcherSession != session { return }

                self.toggleFilterAndRefreshCandidates()
            }
            return true
        }

        if isBatchQuitShortcut(event) {
            let session = switcherSession
            let activeFeatureSession = featureSession
            DispatchQueue.main.async {
                if self.featureSession != activeFeatureSession { return }

                let quitCount = runBatchQuit(self.batchQuitStore)
                if self.switcherSession != session { return }

                self.panel.showFeedback(.quittingApps(count: quitCount))
            }
            return true
        }

        if isQuitShortcut(event) {
            let app = candidates[selectedIndex]
            app.terminate()
            showFeedback(.quittingApp(name: getAppName(app)))
            return true
        }

        if isHideShortcut(event) {
            hideSelectedApp()
            return true
        }

        return false
    }

    /// A second press on a hidden app does nothing.
    private func hideSelectedApp() {
        let app = candidates[selectedIndex]
        if app.isHidden { return }

        app.hide()
        showFeedback(.hidden)
    }

    /// On the next turn of the main queue: showing it can grow the panel, an animation the tap callback must not wait on.
    private func showFeedback(_ feedback: SwitcherFeedback) {
        let session = switcherSession
        DispatchQueue.main.async {
            if self.switcherSession != session { return }

            self.panel.showFeedback(feedback)
        }
    }

    /// Releasing Cmd activates the selection; the release itself always reaches the focused app.
    private func handleFlagsChanged(_ event: CGEvent) {
        if event.flags.contains(.maskCommand) { return }

        if isOpening {
            commandReleasedWhileOpening = true
            return
        }

        if !panel.isVisible { return }

        activateSelection()
    }

    private func isSwitcherShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: tabKeyCode)
    }

    private func isWindowSwitcherShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: graveKeyCode)
    }

    /// Cmd+Tab while apps are listed, Cmd+` while windows are.
    private func isListedSwitcherShortcut(_ event: CGEvent) -> Bool {
        if isListingWindows { return isWindowSwitcherShortcut(event) }
        return isSwitcherShortcut(event)
    }

    /// The other list's one is swallowed while the panel is open: passed on, Cmd+Tab would open the system switcher over the panel and Cmd+`
    /// would cycle the windows of the app behind it.
    private func isAnySwitcherShortcut(_ event: CGEvent) -> Bool {
        if isSwitcherShortcut(event) { return true }
        return isWindowSwitcherShortcut(event)
    }

    /// Swallowed while windows are listed: passed on, they would act on the app behind the panel.
    private func isAppShortcut(_ event: CGEvent) -> Bool {
        if isWhitelistToggleShortcut(event) { return true }
        if isFilterToggleShortcut(event) { return true }
        if isBatchQuitShortcut(event) { return true }
        if isQuitShortcut(event) { return true }
        if isHideShortcut(event) { return true }
        return false
    }

    private func isForwardShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: rightArrowKeyCode)
    }

    private func isBackwardShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: leftArrowKeyCode)
    }

    private func isRowUpShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: upArrowKeyCode)
    }

    private func isRowDownShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: downArrowKeyCode)
    }

    private func isWhitelistToggleShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: wKeyCode)
    }

    private func isFilterToggleShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: fKeyCode)
    }

    /// Cmd+Shift+Q is also a Cmd+Q, so it is asked first.
    private func isBatchQuitShortcut(_ event: CGEvent) -> Bool {
        return isShortcut(event, keyCode: qKeyCode, modifiers: [.maskCommand, .maskShift])
    }

    private func isQuitShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: qKeyCode)
    }

    private func isHideShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: hKeyCode)
    }

    private func isCancelShortcut(_ event: CGEvent) -> Bool {
        return isKey(event, keyCode: escapeKeyCode)
    }

    private func isCommandShortcut(_ event: CGEvent, keyCode: Int64) -> Bool {
        return isShortcut(event, keyCode: keyCode, modifiers: .maskCommand)
    }

    // MARK: switching

    /// The windows are the frontmost app's.
    private func loadCandidates(listingWindows: Bool) {
        if listingWindows {
            loadWindows(of: NSWorkspace.shared.frontmostApplication!)
            return
        }

        loadApps()
    }

    /// The row width is fixed here, so the panel's layout and the row navigation agree even if the main screen changes later.
    private func loadApps() {
        isListingWindows = false
        candidates = getCandidates()
        windows = []
        isFiltered = isListingWhitelistOnly()
        cellsPerRow = getCellsPerRow()
    }

    /// Whatever the whitelist and the filter say. Drops the thumbnails of windows no longer listed; the row width is fixed as for the apps.
    private func loadWindows(of app: NSRunningApplication) {
        isListingWindows = true
        candidates = []
        windows = getWindows(of: app)
        thumbnails = thumbnails.filter { windowID, _ in windows.contains { $0.windowID == windowID } }
        isFiltered = false
        cellsPerRow = getCellsPerRow()
    }

    /// The count nearest the panel width, so a drag has to travel half a cell either way before a column comes or goes; raised when that many
    /// rows and the hint band would run past the visible screen's height, then held between one and what fits on its width, so a width dragged
    /// past the screen or remembered from a wider one still fits.
    private func getCellsPerRow() -> Int {
        let metrics = getCellMetrics(listingWindows: isListingWindows)
        let screenSize = NSScreen.main!.visibleFrame.size
        let nearest = Int(metrics.getCellCount(forPanelWidth: getPanelWidth()).rounded())
        let fittingRows = max(1, Int(metrics.getRowCount(forPanelHeight: screenSize.height - metrics.hintBandHeight).rounded(.down)))
        let fewestForHeight = (getItemCount() + fittingRows - 1) / fittingRows
        let fitting = Int(metrics.getCellCount(forPanelWidth: screenSize.width).rounded(.down))

        let wanted = max(nearest, fewestForHeight)
        return max(1, min(wanted, fitting))
    }

    /// The remembered width, or the default share of the screen until the edge has been dragged once.
    private func getPanelWidth() -> CGFloat {
        return panelWidthStore.width ?? NSScreen.main!.visibleFrame.width * defaultPanelWidthFraction
    }

    private func getCandidates() -> [NSRunningApplication] {
        let recentApps = getRecentRunningApps()
        if !whitelistStore.isFilterEnabled {
            return recentApps
        }

        let whitelist = whitelistStore.getWhitelist()
        let whitelistedApps = recentApps.filter { whitelist.contains($0.bundleIdentifier!) }
        if whitelistedApps.isEmpty {
            return recentApps
        }

        return whitelistedApps
    }

    /// False in the fallback to every running app, when the filter is on but no whitelisted app is running.
    private func isListingWhitelistOnly() -> Bool {
        if !whitelistStore.isFilterEnabled { return false }

        let whitelist = whitelistStore.getWhitelist()
        return candidates.contains { whitelist.contains($0.bundleIdentifier!) }
    }

    /// Regular running apps, most recently activated first.
    private func getRecentRunningApps() -> [NSRunningApplication] {
        var appsByIdentifier: [String: NSRunningApplication] = [:]

        for app in getRegularRunningApps() {
            guard let bundleIdentifier = app.bundleIdentifier else { continue }
            appsByIdentifier[bundleIdentifier] = app
        }

        var recentApps: [NSRunningApplication] = []
        for bundleIdentifier in tracker.bundleIdentifiers {
            guard let app = appsByIdentifier[bundleIdentifier] else { continue }
            recentApps.append(app)
        }

        return getAppsWithWindows(recentApps)
    }

    /// Remembers the dragged width and re-wraps the icons to it on the spot. A drag outliving the panel, Cmd released mid-drag, is ignored.
    private func resizePanel(toWidth width: CGFloat) {
        if !panel.isVisible { return }

        panelWidthStore.setWidth(width)
        cellsPerRow = getCellsPerRow()
        panel.resize(state: buildState())
    }

    private func getItemCount() -> Int {
        if isListingWindows { return windows.count }
        return candidates.count
    }

    private func advanceSelection(backward: Bool) {
        let itemCount = getItemCount()
        let step = backward ? -1 : 1

        selectedIndex = (selectedIndex + step + itemCount) % itemCount
        panel.update(state: buildState())
    }

    /// The cell drawn nearest above or below, wrapping at the top and bottom; of two equally near, the left one, as `min` keeps the first.
    private func moveSelectionBetweenRows(up: Bool) {
        let itemCount = getItemCount()
        let rowCount = (itemCount + cellsPerRow - 1) / cellsPerRow
        let step = up ? -1 : 1
        let targetRow = (selectedIndex / cellsPerRow + step + rowCount) % rowCount
        let targetRowIndices = targetRow * cellsPerRow..<min((targetRow + 1) * cellsPerRow, itemCount)

        selectedIndex = targetRowIndices.min { getColumnDistance(from: $0, to: selectedIndex) < getColumnDistance(from: $1, to: selectedIndex) }!
        panel.update(state: buildState())
    }

    /// How far apart the two cells are drawn, in columns.
    private func getColumnDistance(from index: Int, to otherIndex: Int) -> CGFloat {
        let itemCount = getItemCount()
        let column = getVisualColumn(index: index, cellCount: itemCount, cellsPerRow: cellsPerRow)
        let otherColumn = getVisualColumn(index: otherIndex, cellCount: itemCount, cellsPerRow: cellsPerRow)

        return abs(column - otherColumn)
    }

    /// The selection stays on its app; when that is the one gone, it moves to the neighbour.
    private func removeCandidate(at index: Int) {
        candidates.remove(at: index)
        if candidates.isEmpty {
            dismissSwitcher()
            return
        }

        if index < selectedIndex { selectedIndex -= 1 }
        selectedIndex = min(selectedIndex, candidates.count - 1)
        panel.removeApp(at: index, state: buildState())
    }

    private func toggleFilterAndRefreshCandidates() {
        let selectedIdentifier = candidates[selectedIndex].bundleIdentifier

        whitelistStore.setFilterEnabled(!whitelistStore.isFilterEnabled)
        loadApps()
        if candidates.isEmpty {
            dismissSwitcher()
            return
        }

        selectedIndex = candidates.firstIndex { $0.bundleIdentifier == selectedIdentifier } ?? 0
        panel.show(state: buildState(), glassStore: getGlassStore())
        panel.showFeedback(getFilterFeedback())
    }

    /// What is listed now: with the filter on, every app still is while no whitelisted app has a window.
    private func getFilterFeedback() -> SwitcherFeedback {
        if isFiltered { return .showingWhitelist }
        if whitelistStore.isFilterEnabled { return .noWhitelistedApps }
        return .showingAllApps
    }

    /// Windows show their last thumbnail, or their app's icon, until a fresh one comes in.
    private func showPanel() {
        panel.show(state: buildState(), glassStore: getGlassStore())
        panel.showHintsAfterDelay()
        refreshThumbnails(of: windows.map { $0.windowID }, in: panel)
    }

    /// Each thumbnail shows in the panel as it arrives, while the panel is up.
    private func refreshThumbnails(of windowIDs: [CGWindowID], in switcherPanel: SwitcherPanel) {
        let session = switcherPanel === panel ? switcherSession : previewSession
        captureThumbnails(of: windowIDs) { windowID, thumbnail in
            let currentSession = switcherPanel === self.panel ? self.switcherSession : self.previewSession
            if currentSession != session { return }
            if !switcherPanel.isVisible { return }

            self.thumbnails[windowID] = thumbnail
            switcherPanel.update(state: self.buildState())
        }
    }

    /// The glass of the list loaded last.
    private func getGlassStore() -> GlassStore {
        if isListingWindows { return windowGlassStore }
        return appGlassStore
    }

    private func buildState() -> SwitcherState {
        return SwitcherState(
            apps: candidates,
            windows: windows,
            thumbnails: thumbnails,
            isListingWindows: isListingWindows,
            windowCardGlass: windowCardStore.showsCards ? windowCardGlassStore : nil,
            cellsPerRow: cellsPerRow,
            selectedIndex: selectedIndex,
            isFiltered: isFiltered,
            isFilterEnabled: whitelistStore.isFilterEnabled,
            whitelisted: whitelistStore.getWhitelist()
        )
    }

    /// A window is raised on the next turn of the main queue: its accessibility round trips must stay out of the tap callback releasing Cmd.
    private func activateSelection() {
        if isListingWindows {
            let window = windows[selectedIndex]
            dismissSwitcher()

            let session = featureSession
            DispatchQueue.main.async {
                if self.featureSession != session { return }

                window.bringToFront()
            }
            return
        }

        dismissSwitcher()
        candidates[selectedIndex].activate(options: [.activateAllWindows])
    }

    private func dismissSwitcher() {
        switcherSession += 1
        isOpening = false
        panel.hide()
    }

    // MARK: preview

    /// Shows what the glass is for on the glass just set and hides it a moment after the last change: the running apps, or the windows of the
    /// app used last, the one behind the settings window. Their thumbnails are captured when the preview comes up on them, not again on every
    /// step of a slider drag. Left out while the switcher is open, since it shares the candidates, and hidden with nothing to list, since a
    /// thumbnail still arriving would redraw it from the empty list.
    private func previewGlass(listingWindows: Bool) {
        if panel.isVisible { return }
        if isOpening { return }

        let wasPreviewingWindows = isPreviewingWindows()
        if !previewPanel.isVisible {
            previewSession += 1
        } else if isListingWindows != listingWindows {
            hidePreview()
        }

        if listingWindows {
            guard let app = getRecentRunningApps().first else { return }
            loadWindows(of: app)
        } else {
            loadApps()
        }
        if getItemCount() == 0 {
            hidePreview()
            return
        }

        selectedIndex = 0
        previewPanel.show(state: buildState(), glassStore: getGlassStore())
        if !wasPreviewingWindows {
            refreshThumbnails(of: windows.map { $0.windowID }, in: previewPanel)
        }

        previewHiding?.cancel()
        previewHiding = DispatchWorkItem { self.hidePreview() }
        DispatchQueue.main.asyncAfter(deadline: .now() + glassPreviewDuration, execute: previewHiding!)
    }

    /// While the preview is up, the candidates are its own: the switcher hides it before loading.
    private func isPreviewingWindows() -> Bool {
        if !previewPanel.isVisible { return false }
        return isListingWindows
    }

    private func hidePreview() {
        previewSession += 1
        previewHiding?.cancel()
        previewHiding = nil
        previewPanel.hide()
    }
}
