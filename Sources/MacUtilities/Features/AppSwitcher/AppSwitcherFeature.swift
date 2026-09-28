import AppKit
import Combine
import SwiftUI

/// Replaces Cmd+Tab with the switcher panel, filtered to the whitelist when the filter is on, and Cmd+` with the same panel listing the
/// frontmost app's windows.
final class AppSwitcherFeature: Feature {
    let identifier = "app-switcher"
    let displayName = "App Switcher"
    let menuItems: [NSMenuItem] = []

    private let panel: SwitcherPanel
    /// Shows the glass live while it is set in the settings tab; clicks pass through it to the tab.
    private let previewPanel: SwitcherPanel
    private let tracker = RecentAppsTracker()
    private let whitelistStore = WhitelistStore()
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
        lookChanges.append(observeLookChanges(of: appGlassStore, previewing: appGlassStore))
        lookChanges.append(observeLookChanges(of: windowGlassStore, previewing: windowGlassStore))
        lookChanges.append(observeLookChanges(of: windowCardStore, previewing: windowGlassStore))
        lookChanges.append(observeLookChanges(of: windowCardGlassStore, previewing: windowGlassStore))
        runSmokeTestIfRequested()
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers = []
        lookChanges = []
        tracker.stop()
        panel.hide()
        previewPanel.hide()
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

    func buildSettingsView() -> AnyView {
        return AnyView(AppSwitcherSettingsView(
            whitelistStore: whitelistStore,
            appGlassStore: appGlassStore,
            windowGlassStore: windowGlassStore,
            windowCardStore: windowCardStore,
            windowCardGlassStore: windowCardGlassStore
        ))
    }

    private func runSmokeTestIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["APP_SWITCHER_SMOKE_TEST"] != nil else { return }

        whitelistStore.setFilterEnabled(environment["APP_SWITCHER_SMOKE_FILTER"] == "1")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadCandidates(listingWindows: environment["APP_SWITCHER_SMOKE_WINDOWS"] == "1")
            self.selectedIndex = Int(environment["APP_SWITCHER_SMOKE_INDEX"] ?? "1")!
            self.showPanel()
            showCaptureBackdrop(behind: self.panel)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
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

    /// The store announces a change before making it; the main queue runs the preview on the list's glass after, and also while a slider is
    /// being dragged.
    private func observeLookChanges(of store: some ObservableObject, previewing glassStore: GlassStore) -> AnyCancellable {
        return store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in self.previewGlass(glassStore) }
    }

    // MARK: events

    /// Never does real work: macOS disables a tap whose callback is slow, and the keystroke then falls through to the Dock.
    private func handleKeyDown(_ event: CGEvent) -> Bool {
        if panel.isVisible {
            return handleKeyDownWhileVisible(event)
        }

        if isSwitcherShortcut(event) {
            requestOpening(listingWindows: false)
            return true
        }

        if isWindowSwitcherShortcut(event) {
            requestOpening(listingWindows: true)
            return true
        }

        return false
    }

    /// Presses arriving before the panel is up only advance the selection it opens with.
    private func requestOpening(listingWindows: Bool) {
        if isOpening {
            pendingAdvance += 1
            return
        }

        isOpening = true
        commandReleasedWhileOpening = false
        pendingAdvance = 0
        DispatchQueue.main.async { self.openSwitcher(listingWindows: listingWindows) }
    }

    /// The glass preview goes first: it shares the candidates, and a thumbnail arriving for it would redraw it from the ones loaded here.
    private func openSwitcher(listingWindows: Bool) {
        previewPanel.hide()
        loadCandidates(listingWindows: listingWindows)
        isOpening = false

        let itemCount = getItemCount()
        if itemCount == 0 { return }

        selectedIndex = (itemCount > 1 ? 1 : 0) + pendingAdvance
        selectedIndex %= itemCount

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
            panel.hide()
            return true
        }

        if isListingWindows {
            return isAppShortcut(event)
        }

        if isWhitelistToggleShortcut(event) {
            let bundleIdentifier = candidates[selectedIndex].bundleIdentifier!
            whitelistStore.setWhitelisted(bundleIdentifier, !whitelistStore.isWhitelisted(bundleIdentifier))
            panel.update(state: buildState())
            return true
        }

        if isFilterToggleShortcut(event) {
            DispatchQueue.main.async { self.toggleFilterAndRefreshCandidates() }
            return true
        }

        if isQuitShortcut(event) {
            candidates[selectedIndex].terminate()
            return true
        }

        if isQuitAppsNotInWhitelistShortcut(event) {
            DispatchQueue.main.async { quitRegularAppsNotIn(whitelist: self.whitelistStore.getWhitelist()) }
            return true
        }

        if isHideShortcut(event) {
            candidates[selectedIndex].hide()
            return true
        }

        return false
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

    /// Swallowed while windows are listed: passed on, Cmd+Tab would open the system switcher over the panel and the others would act on the
    /// app behind it.
    private func isAppShortcut(_ event: CGEvent) -> Bool {
        if isSwitcherShortcut(event) { return true }
        if isWhitelistToggleShortcut(event) { return true }
        if isFilterToggleShortcut(event) { return true }
        if isQuitShortcut(event) { return true }
        if isQuitAppsNotInWhitelistShortcut(event) { return true }
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

    private func isQuitShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: qKeyCode)
    }

    private func isQuitAppsNotInWhitelistShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: xKeyCode)
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

    /// The count nearest the panel width, so a drag has to travel half a cell either way before a column comes or goes; held between one and
    /// what fits on the visible screen, so a width dragged past the screen or remembered from a wider one still fits.
    private func getCellsPerRow() -> Int {
        let metrics = getCellMetrics(listingWindows: isListingWindows)
        let nearest = Int(metrics.getCellCount(forPanelWidth: getPanelWidth()).rounded())
        let fitting = Int(metrics.getCellCount(forPanelWidth: NSScreen.main!.visibleFrame.width).rounded(.down))

        return max(1, min(nearest, fitting))
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
            panel.hide()
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
            panel.hide()
            return
        }

        selectedIndex = candidates.firstIndex { $0.bundleIdentifier == selectedIdentifier } ?? 0
        panel.show(state: buildState(), glassStore: appGlassStore)
    }

    /// Windows show their last thumbnail, or their app's icon, until a fresh one comes in.
    private func showPanel() {
        panel.show(state: buildState(), glassStore: isListingWindows ? windowGlassStore : appGlassStore)
        refreshThumbnails(of: windows.map { $0.windowID }, in: panel)
    }

    /// Each thumbnail shows in the panel as it arrives, while the panel is up.
    private func refreshThumbnails(of windowIDs: [CGWindowID], in switcherPanel: SwitcherPanel) {
        captureThumbnails(of: windowIDs) { windowID, thumbnail in
            self.thumbnails[windowID] = thumbnail
            if !switcherPanel.isVisible { return }

            switcherPanel.update(state: self.buildState())
        }
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
            whitelisted: whitelistStore.getWhitelist()
        )
    }

    /// A window is raised on the next turn of the main queue: its accessibility round trips must stay out of the tap callback releasing Cmd.
    private func activateSelection() {
        panel.hide()

        if isListingWindows {
            let window = windows[selectedIndex]
            DispatchQueue.main.async { window.bringToFront() }
            return
        }

        candidates[selectedIndex].activate(options: [.activateAllWindows])
    }

    // MARK: preview

    /// Shows what the glass is for on the glass just set and hides it a moment after the last change: the running apps, or the windows of the
    /// app used last, the one behind the settings window. Only windows without a thumbnail yet are captured, so dragging the slider does not
    /// capture on every step. Left out while the switcher is open, since it shares the candidates.
    private func previewGlass(_ glassStore: GlassStore) {
        if panel.isVisible { return }

        if glassStore === windowGlassStore {
            guard let app = getRecentRunningApps().first else { return }
            loadWindows(of: app)
        } else {
            loadApps()
        }
        if getItemCount() == 0 { return }

        selectedIndex = 0
        previewPanel.show(state: buildState(), glassStore: glassStore)
        refreshThumbnails(of: windows.map { $0.windowID }.filter { thumbnails[$0] == nil }, in: previewPanel)

        previewHiding?.cancel()
        previewHiding = DispatchWorkItem { self.previewPanel.hide() }
        DispatchQueue.main.asyncAfter(deadline: .now() + glassPreviewDuration, execute: previewHiding!)
    }
}
