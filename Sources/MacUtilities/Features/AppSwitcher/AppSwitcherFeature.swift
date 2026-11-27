import AppKit
import os
import SwiftUI

/// Replaces Cmd+Tab with the switcher panel, filtered to the whitelist when the filter is on, and Cmd+` with the same panel listing the
/// frontmost app's windows.
final class AppSwitcherFeature: Feature {
    let identifier = "app-switcher"
    let displayName = "App Switcher"
    let summary = "Replaces ⌘Tab and ⌘` with a glass switcher for apps and their windows."
    let iconSymbolName = "rectangle.stack.fill"
    let iconGradient = Gradient(colors: [.blue, .indigo])

    private let workspace: SwitcherWorkspace
    private let settings: SwitcherSettings
    private let listLoader: SwitcherListLoader
    private let thumbnailCache: WindowThumbnailCache
    private let panel: SwitcherPanel
    private let preview: SwitcherPreview
    private let smokeTest: AppSwitcherSmokeTest?

    private var phase = SwitcherPhase.closed
    /// Renewed when the feature stops.
    private let featureSession = SwitcherSession()
    /// Renewed when an opening starts and when the switcher closes.
    private let switcherSession = SwitcherSession()

    init(workspace: SwitcherWorkspace, settings: SwitcherSettings, listLoader: SwitcherListLoader, thumbnailCache: WindowThumbnailCache, panel: SwitcherPanel,
         preview: SwitcherPreview, smokeTest: AppSwitcherSmokeTest?) {
        self.workspace = workspace
        self.settings = settings
        self.listLoader = listLoader
        self.thumbnailCache = thumbnailCache
        self.panel = panel
        self.preview = preview
        self.smokeTest = smokeTest

        panel.onCellClicked = { [unowned self] index in self.activateClickedCell(index) }
        panel.onWidthDragged = { [unowned self] width in self.resizePanel(toWidth: width) }
    }

    func start() {
        workspace.startObserving(
            onAppTerminated: { [unowned self] processIdentifier in self.handleAppTermination(processIdentifier) },
            onAppHiddenOrShown: { [unowned self] in self.redrawHiddenApps() }
        )
        preview.start()
        smokeTest?.run()
    }

    func stop(because cause: FeatureStopCause) {
        featureSession.renew()

        workspace.stopObserving()
        preview.stop()
        dismissSwitcher()
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .keyDown {
            return handleKeyDown(getSwitcherShortcut(keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags))
        }

        if type == .flagsChanged {
            handleModifiersChanged(event.flags)
        }

        return false
    }

    func buildSettingsSections() -> AnyView {
        return AnyView(AppSwitcherSettingsView(settings: settings))
    }

    func settingsWindowChanged(_ window: NSWindow?) {
        preview.settingsWindowChanged(window)
    }

    func buildPopoverTile() -> AnyView? {
        return AnyView(BatchQuitTile(batchQuitStore: settings.batchQuitStore))
    }

    // MARK: workspace changes

    /// The open switcher's list loses the app; a shown preview loads afresh.
    private func handleAppTermination(_ processIdentifier: pid_t) {
        preview.reloadIfShown()
        guard case .open(let list) = phase else { return }
        guard case .apps(let apps, _) = list.items else { return }
        guard let index = apps.firstIndex(where: { $0.processIdentifier == processIdentifier }) else { return }

        removeApp(at: index, from: list)
    }

    /// Redraws the dimming once the app is really hidden or shown, whether it was our Cmd+H or done elsewhere.
    private func redrawHiddenApps() {
        if case .open(let list) = phase {
            panel.update(state: buildState(list))
        }
        preview.redrawIfShown()
    }

    // MARK: events

    /// Never does real work: macOS disables a tap whose callback is slow, and the keystroke then falls through to the Dock.
    private func handleKeyDown(_ shortcut: SwitcherShortcut?) -> Bool {
        guard let shortcut else { return false }

        switch phase {
        case .closed:
            return handleShortcutWhileClosed(shortcut)
        case .opening(let opening):
            return handleShortcutWhileOpening(shortcut, opening: opening)
        case .open(let list):
            return handleShortcutWhileOpen(shortcut, list: list)
        }
    }

    private func handleShortcutWhileClosed(_ shortcut: SwitcherShortcut) -> Bool {
        switch shortcut {
        case .switchApps(let backward):
            requestOpening(listingWindows: false, backward: backward)
            return true
        case .switchWindows(let backward):
            requestOpening(listingWindows: true, backward: backward)
            return true
        default:
            return false
        }
    }

    /// Presses arriving before the panel is up only advance the selection it opens with.
    private func handleShortcutWhileOpening(_ shortcut: SwitcherShortcut, opening: SwitcherOpening) -> Bool {
        switch shortcut {
        case .cancel:
            dismissSwitcher()
            return true
        case .switchApps(let backward), .switchWindows(let backward):
            opening.addPress(backward: backward)
            return true
        default:
            return false
        }
    }

    /// Loads the list on the next turn of the main queue.
    private func requestOpening(listingWindows: Bool, backward: Bool) {
        let opening = SwitcherOpening(listsWindows: listingWindows)

        opening.addPress(backward: backward)
        phase = .opening(opening)
        switcherSession.renew()
        preview.suspend()

        switcherSession.runOnNextTurn { self.open(opening) }
    }

    /// The windows are the frontmost app's.
    private func open(_ opening: SwitcherOpening) {
        let list = opening.listsWindows ? listLoader.loadWindowList(of: workspace.getFrontmostApp()) : listLoader.loadAppList()
        if list.isEmpty {
            Logger.appSwitcher.notice("Switcher not shown: no \(opening.listsWindows ? "windows" : "apps", privacy: .public) to list")
            dismissSwitcher()
            return
        }

        let selectedList = list.advancing(by: opening.pendingAdvance)
        if opening.isCommandReleased {
            activateSelection(of: selectedList)
            return
        }

        showSwitcher(selectedList)
    }

    /// The other list's switching shortcut is swallowed while the panel is open: passed on, Cmd+Tab would open the system switcher over the
    /// panel and Cmd+` would cycle the windows of the app behind it. While windows are listed the app shortcuts are swallowed too: passed on,
    /// they would act on the app behind the panel.
    private func handleShortcutWhileOpen(_ shortcut: SwitcherShortcut, list: SwitcherList) -> Bool {
        switch shortcut {
        case .switchApps(let backward):
            if !list.isListingWindows { showSelection(list.advancing(by: backward ? -1 : 1)) }
        case .switchWindows(let backward):
            if list.isListingWindows { showSelection(list.advancing(by: backward ? -1 : 1)) }
        case .selectNext:
            showSelection(list.advancing(by: 1))
        case .selectPrevious:
            showSelection(list.advancing(by: -1))
        case .selectRowAbove:
            showSelection(list.movingBetweenRows(up: true))
        case .selectRowBelow:
            showSelection(list.movingBetweenRows(up: false))
        case .cancel:
            dismissSwitcher()
        case .toggleWhitelisted, .toggleFilter, .batchQuit, .quit, .hide:
            if !list.isListingWindows { handleAppShortcut(shortcut, list: list) }
        }

        return true
    }

    private func handleAppShortcut(_ shortcut: SwitcherShortcut, list: SwitcherList) {
        switch shortcut {
        case .toggleWhitelisted:
            let bundleIdentifier = list.selectedApp.bundleIdentifier
            let listed = !settings.whitelistStore.isListed(bundleIdentifier)
            settings.whitelistStore.setListed(bundleIdentifier, listed)
            panel.update(state: buildState(list))
            showFeedback(listed ? .addedToWhitelist : .removedFromWhitelist)
        case .toggleFilter:
            switcherSession.runOnNextTurn { self.toggleFilter() }
        case .batchQuit:
            runBatchQuit()
        case .quit:
            let app = list.selectedApp
            app.terminate()
            showFeedback(.quittingApp(name: app.name))
        case .hide:
            hideSelectedApp(list)
        default:
            preconditionFailure("\(shortcut) is not an app shortcut")
        }
    }

    /// A second press on a hidden app does nothing.
    private func hideSelectedApp(_ list: SwitcherList) {
        let app = list.selectedApp
        if app.isHidden { return }

        app.hide()
        showFeedback(.hidden)
    }

    /// On the next turn of the main queue, the quit running even if the switcher closes meanwhile; its feedback only while the switcher stays
    /// open.
    private func runBatchQuit() {
        let showQuitCount = switcherSession.guarding { (quitCount: Int) in self.panel.showFeedback(.quittingApps(count: quitCount)) }

        featureSession.runOnNextTurn { showQuitCount(self.workspace.runBatchQuit()) }
    }

    /// On the next turn of the main queue: showing it can grow the panel, an animation the tap callback must not wait on.
    private func showFeedback(_ feedback: SwitcherFeedback) {
        switcherSession.runOnNextTurn { self.panel.showFeedback(feedback) }
    }

    /// Releasing Cmd activates the selection; the release itself always reaches the focused app.
    private func handleModifiersChanged(_ modifiers: CGEventFlags) {
        if modifiers.contains(.maskCommand) { return }

        switch phase {
        case .closed:
            return
        case .opening(let opening):
            opening.releaseCommand()
        case .open(let list):
            activateSelection(of: list)
        }
    }

    // MARK: switching

    private func activateClickedCell(_ index: Int) {
        guard case .open(let list) = phase else { return }

        activateSelection(of: list.selecting(index))
    }

    /// Remembers the dragged width and re-wraps the cells to it on the spot. A drag outliving the panel, Cmd released mid-drag, is ignored.
    private func resizePanel(toWidth width: CGFloat) {
        guard case .open(let list) = phase else { return }

        settings.panelWidthStore.setWidth(width)
        let resizedList = list.rewrapping(cellsPerRow: listLoader.getCellsPerRow(for: list.items))
        phase = .open(resizedList)
        panel.resize(state: buildState(resizedList))
    }

    private func showSelection(_ list: SwitcherList) {
        phase = .open(list)
        panel.update(state: buildState(list))
    }

    /// The last app gone closes the switcher.
    private func removeApp(at index: Int, from list: SwitcherList) {
        let remainingList = list.removingApp(at: index)
        if remainingList.isEmpty {
            dismissSwitcher()
            return
        }

        phase = .open(remainingList)
        panel.removeApp(at: index, state: buildState(remainingList))
    }

    /// Keeps the selected app selected when it is still listed.
    private func toggleFilter() {
        guard case .open(let openList) = phase else { return }

        let selectedIdentifier = openList.selectedApp.bundleIdentifier
        let whitelistStore = settings.whitelistStore

        whitelistStore.setFilterEnabled(!whitelistStore.isFilterEnabled)
        let list = listLoader.loadAppList()
        if list.isEmpty {
            dismissSwitcher()
            return
        }

        let selectedList = list.selectingApp(bundleIdentifier: selectedIdentifier)
        phase = .open(selectedList)
        panel.show(state: buildState(selectedList), glassStore: settings.getGlassStore(listingWindows: false))
        panel.showFeedback(getFilterFeedback(selectedList))
    }

    /// What is listed now: with the filter on, every app still is while no whitelisted app has a window.
    private func getFilterFeedback(_ list: SwitcherList) -> SwitcherFeedback {
        if list.items.isWhitelistOnly { return .showingWhitelist }
        if settings.whitelistStore.isFilterEnabled { return .noWhitelistedApps }
        return .showingAllApps
    }

    /// Windows show their last thumbnail, or their app's icon, until a fresh one comes in.
    private func showSwitcher(_ list: SwitcherList) {
        phase = .open(list)
        panel.show(state: buildState(list), glassStore: settings.getGlassStore(listingWindows: list.isListingWindows))
        panel.showHintsAfterDelay()

        guard case .windows(let windows) = list.items else { return }
        thumbnailCache.refresh(of: windows, session: switcherSession) { self.redrawThumbnails() }
    }

    /// In the list as it is now; the selection may have moved since the capture started.
    private func redrawThumbnails() {
        guard case .open(let list) = phase else { return }

        panel.update(state: buildState(list))
    }

    private func buildState(_ list: SwitcherList) -> SwitcherState {
        return settings.buildState(list: list, thumbnails: thumbnailCache.thumbnails)
    }

    /// A window is raised on the next turn of the main queue: its accessibility round trips must stay out of the tap callback releasing Cmd.
    private func activateSelection(of list: SwitcherList) {
        switch list.items {
        case .windows(let windows):
            let window = windows[list.selectedIndex]
            featureSession.runOnNextTurn { window.bringToFront() }

            // Dismissal queues preview restoration after the window raise.
            dismissSwitcher()
        case .apps(let apps, _):
            dismissSwitcher()
            apps[list.selectedIndex].activate()
        }
    }

    /// Queues the preview's return.
    private func dismissSwitcher() {
        switcherSession.renew()
        phase = .closed
        panel.hide()

        switcherSession.runOnNextTurn { self.preview.resume() }
    }
}
