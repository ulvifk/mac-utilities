import AppKit
import SwiftUI

/// Replaces Cmd+Tab with the switcher panel, filtered to the whitelist when the filter is on.
final class AppSwitcherFeature: Feature {
    let identifier = "app-switcher"
    let displayName = "App Switcher"
    let menuItems: [NSMenuItem] = []

    private let panel = SwitcherPanel()
    private let tracker = RecentAppsTracker()
    private let whitelistStore = WhitelistStore()
    private let panelWidthStore = PanelWidthStore()
    private var observers: [NSObjectProtocol] = []

    private var candidates: [NSRunningApplication] = []
    private var iconsPerRow = 1
    private var selectedIndex = 0

    private var isOpening = false
    private var commandReleasedWhileOpening = false
    private var pendingAdvance = 0

    init() {
        wirePanel()
    }

    func start() {
        enableCursorChangesWhileInactive()
        tracker.start()
        observers.append(observeAppTermination())
        observers.append(contentsOf: observeAppHiding())
        runSmokeTestIfRequested()
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers = []
        tracker.stop()
        panel.hide()
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
        return AnyView(AppSwitcherSettingsView(whitelistStore: whitelistStore))
    }

    private func runSmokeTestIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["APP_SWITCHER_SMOKE_TEST"] != nil else { return }

        whitelistStore.setFilterEnabled(environment["APP_SWITCHER_SMOKE_FILTER"] == "1")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadCandidates()
            self.selectedIndex = Int(environment["APP_SWITCHER_SMOKE_INDEX"] ?? "1")!
            self.panel.show(state: self.buildState())
            showCaptureBackdrop(behind: self.panel)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            print("smoke: frame=\(self.panel.frame) visible=\(self.panel.isVisible) alpha=\(self.panel.alphaValue) apps=\(self.candidates.count) selected=\(self.selectedIndex)")
            print("smoke: candidates=\(self.candidates.compactMap { $0.localizedName })")
            writeCapture(around: self.panel, path: smokeCapturePath)
            exit(0)
        }
    }

    // MARK: wiring

    private func wirePanel() {
        panel.onCellClicked = { index in
            self.selectedIndex = index
            self.activateSelectedApp()
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

    // MARK: events

    /// Never does real work: macOS disables a tap whose callback is slow, and the keystroke then falls through to the Dock.
    private func handleKeyDown(_ event: CGEvent) -> Bool {
        if panel.isVisible {
            return handleKeyDownWhileVisible(event)
        }

        if !isSwitcherShortcut(event) {
            return false
        }

        if isOpening {
            pendingAdvance += 1
            return true
        }

        isOpening = true
        commandReleasedWhileOpening = false
        pendingAdvance = 0
        DispatchQueue.main.async { self.openSwitcher() }
        return true
    }

    private func openSwitcher() {
        loadCandidates()
        isOpening = false

        if candidates.isEmpty { return }

        selectedIndex = (candidates.count > 1 ? 1 : 0) + pendingAdvance
        selectedIndex %= candidates.count

        if commandReleasedWhileOpening {
            activateSelectedApp()
            return
        }

        panel.show(state: buildState())
    }

    private func handleKeyDownWhileVisible(_ event: CGEvent) -> Bool {
        if isSwitcherShortcut(event) {
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

        if isCancelShortcut(event) {
            panel.hide()
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

        activateSelectedApp()
    }

    private func isSwitcherShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: tabKeyCode)
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

    /// The row width is fixed here, so the panel's layout and the row navigation agree even if the main screen changes later.
    private func loadCandidates() {
        candidates = getCandidates()
        iconsPerRow = getIconsPerRow()
    }

    /// The count nearest the panel width, so a drag has to travel half an icon either way before a column comes or goes; held between one and
    /// what fits on the visible screen, so a width dragged past the screen or remembered from a wider one still fits.
    private func getIconsPerRow() -> Int {
        let nearest = Int(getIconCount(forPanelWidth: getPanelWidth()).rounded())
        let fitting = Int(getIconCount(forPanelWidth: NSScreen.main!.visibleFrame.width).rounded(.down))

        return max(1, min(nearest, fitting))
    }

    /// How many icons a row of this panel width holds, fractional.
    private func getIconCount(forPanelWidth width: CGFloat) -> CGFloat {
        return (width - 2 * horizontalPadding + itemSpacing) / (iconSize + itemSpacing)
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
        iconsPerRow = getIconsPerRow()
        panel.resize(state: buildState())
    }

    private func advanceSelection(backward: Bool) {
        let step = backward ? -1 : 1
        selectedIndex = (selectedIndex + step + candidates.count) % candidates.count
        panel.update(state: buildState())
    }

    /// Same column one row up or down, wrapping at the top and bottom; a shorter last row clamps to its last icon.
    private func moveSelectionBetweenRows(up: Bool) {
        let rowCount = (candidates.count + iconsPerRow - 1) / iconsPerRow
        let column = selectedIndex % iconsPerRow
        let step = up ? -1 : 1
        let targetRow = (selectedIndex / iconsPerRow + step + rowCount) % rowCount

        selectedIndex = min(targetRow * iconsPerRow + column, candidates.count - 1)
        panel.update(state: buildState())
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
        loadCandidates()
        if candidates.isEmpty {
            panel.hide()
            return
        }

        selectedIndex = candidates.firstIndex { $0.bundleIdentifier == selectedIdentifier } ?? 0
        panel.show(state: buildState())
    }

    private func buildState() -> SwitcherState {
        return SwitcherState(
            apps: candidates,
            iconsPerRow: iconsPerRow,
            selectedIndex: selectedIndex,
            filterEnabled: whitelistStore.isFilterEnabled,
            whitelisted: whitelistStore.getWhitelist()
        )
    }

    private func activateSelectedApp() {
        panel.hide()
        candidates[selectedIndex].activate(options: [.activateAllWindows])
    }
}
