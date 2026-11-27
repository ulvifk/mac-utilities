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

    private let workspace: SwitcherWorkspace
    private let screen: SwitcherScreen
    private let settings: SwitcherSettings
    private let listLoader: SwitcherListLoader
    private let panel: SwitcherPanel
    /// Shows the glass live while it is set in the settings pane; clicks pass through it to the pane.
    private let previewPanel: SwitcherPanel
    private let smokeTest: AppSwitcherSmokeTest?
    private var previewChanges: [AnyCancellable] = []

    private weak var settingsWindow: NSWindow?

    /// The open panel's list; nil while it is closed or opening.
    private var switcherList: SwitcherList?
    /// The shown preview's list; nil while it is hidden.
    private var previewList: SwitcherList?
    /// [window id] -> the window's latest thumbnail, kept until another app's windows are listed so reopening shows it at once
    private var thumbnails: [CGWindowID: NSImage] = [:]

    private var isOpening = false
    private var commandReleasedWhileOpening = false
    private var pendingAdvance = 0
    private var featureSession = 0
    private var switcherSession = 0
    private var previewSession = 0

    init(workspace: SwitcherWorkspace, screen: SwitcherScreen, settings: SwitcherSettings, listLoader: SwitcherListLoader, panel: SwitcherPanel,
         previewPanel: SwitcherPanel, smokeTest: AppSwitcherSmokeTest?) {
        self.workspace = workspace
        self.screen = screen
        self.settings = settings
        self.listLoader = listLoader
        self.panel = panel
        self.previewPanel = previewPanel
        self.smokeTest = smokeTest

        panel.onCellClicked = { [unowned self] index in self.activateClickedCell(index) }
        panel.onWidthDragged = { [unowned self] width in self.resizePanel(toWidth: width) }
    }

    func start() {
        workspace.startObserving(
            onAppTerminated: { [unowned self] processIdentifier in self.handleAppTermination(processIdentifier) },
            onAppHiddenOrShown: { [unowned self] in self.redrawHiddenApps() }
        )
        previewChanges.append(observeSettingsFocusChanges())
        previewChanges.append(observePreviewChanges(of: settings.whitelistStore, reloadList: true))
        previewChanges.append(observePreviewChanges(of: settings.appearanceStore))
        previewChanges.append(observePreviewChanges(of: settings.appGlassStore))
        previewChanges.append(observePreviewChanges(of: settings.windowGlassStore))
        previewChanges.append(observePreviewChanges(of: settings.appCardStore))
        previewChanges.append(observePreviewChanges(of: settings.appCardGlassStore))
        previewChanges.append(observePreviewChanges(of: settings.windowCardStore))
        previewChanges.append(observePreviewChanges(of: settings.windowCardGlassStore))
        previewChanges.append(observePreviewChanges(of: settings.previewStore))
        smokeTest?.run()
    }

    func stop() {
        featureSession += 1

        workspace.stopObserving()
        previewChanges = []
        settings.previewStore.isShown = false
        dismissSwitcher()
        hidePreview()
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .keyDown {
            return handleKeyDown(getSwitcherShortcut(keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags))
        }

        if type == .flagsChanged {
            handleFlagsChanged(event)
        }

        return false
    }

    func buildSettingsSections() -> AnyView {
        return AnyView(AppSwitcherSettingsView(settings: settings))
    }

    func settingsWindowChanged(_ window: NSWindow?) {
        settingsWindow = window
        if let window {
            if previewList != nil {
                previewPanel.positionPreview(beside: window)
            }
            return
        }

        settings.previewStore.isShown = false
        hidePreview()
    }

    func buildPopoverTile() -> AnyView? {
        return AnyView(BatchQuitTile(batchQuitStore: settings.batchQuitStore))
    }

    // MARK: wiring

    /// The switcher's list loses the app; a shown preview reloads.
    private func handleAppTermination(_ processIdentifier: pid_t) {
        if previewList != nil {
            hidePreview()
            refreshPreview()
            return
        }
        guard let switcherList else { return }
        guard case .apps(let apps, _) = switcherList.items else { return }
        guard let index = apps.firstIndex(where: { $0.processIdentifier == processIdentifier }) else { return }

        removeApp(at: index, from: switcherList)
    }

    /// Redraws the dimming once the app is really hidden or shown, whether it was our Cmd+H or done elsewhere.
    private func redrawHiddenApps() {
        if let switcherList {
            panel.update(state: buildState(switcherList))
        }
        if let previewList {
            previewPanel.update(state: buildState(previewList))
        }
    }

    /// The stores announce changes before making them, so the preview reads them on the next main-queue turn.
    private func observePreviewChanges(of store: some ObservableObject, reloadList: Bool = false) -> AnyCancellable {
        return store.objectWillChange
            .map { _ in self.switcherSession }
            .receive(on: DispatchQueue.main)
            .sink { session in
                if self.switcherSession != session { return }

                if reloadList {
                    self.hidePreview()
                }
                self.refreshPreview()
            }
    }

    private func observeSettingsFocusChanges() -> AnyCancellable {
        return NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification))
            .sink { notification in
                let window = notification.object as! NSWindow
                if window !== self.settingsWindow { return }

                self.refreshPreview()
            }
    }

    // MARK: events

    /// Never does real work: macOS disables a tap whose callback is slow, and the keystroke then falls through to the Dock.
    private func handleKeyDown(_ shortcut: SwitcherShortcut?) -> Bool {
        guard let shortcut else { return false }

        if let switcherList {
            return handleShortcutWhileOpen(shortcut, list: switcherList)
        }

        switch shortcut {
        case .cancel:
            if !isOpening { return false }
            dismissSwitcher()
            return true
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

    /// The windows are the frontmost app's.
    private func openSwitcher(listingWindows: Bool) {
        let list = listingWindows ? loadWindowList(of: workspace.getFrontmostApp()) : listLoader.loadAppList()
        isOpening = false

        if list.isEmpty {
            dismissSwitcher()
            return
        }

        let selectedList = list.advancing(by: pendingAdvance)
        if commandReleasedWhileOpening {
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
            let session = switcherSession
            DispatchQueue.main.async {
                if self.switcherSession != session { return }

                self.toggleFilter()
            }
        case .batchQuit:
            let session = switcherSession
            let activeFeatureSession = featureSession
            DispatchQueue.main.async {
                if self.featureSession != activeFeatureSession { return }

                let quitCount = self.workspace.runBatchQuit()
                if self.switcherSession != session { return }

                self.panel.showFeedback(.quittingApps(count: quitCount))
            }
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

        guard let switcherList else { return }

        activateSelection(of: switcherList)
    }

    // MARK: switching

    /// Drops the thumbnails of windows no longer listed.
    private func loadWindowList(of app: SwitcherApp) -> SwitcherList {
        let list = listLoader.loadWindowList(of: app)
        guard case .windows(let windows) = list.items else { preconditionFailure("Apps were listed") }

        thumbnails = thumbnails.filter { windowID, _ in windows.contains { $0.windowID == windowID } }
        return list
    }

    private func activateClickedCell(_ index: Int) {
        activateSelection(of: switcherList!.selecting(index))
    }

    /// Remembers the dragged width and re-wraps the cells to it on the spot. A drag outliving the panel, Cmd released mid-drag, is ignored.
    private func resizePanel(toWidth width: CGFloat) {
        guard let switcherList else { return }

        settings.panelWidthStore.setWidth(width)
        let resizedList = switcherList.rewrapping(cellsPerRow: listLoader.getCellsPerRow(for: switcherList.items))
        self.switcherList = resizedList
        panel.resize(state: buildState(resizedList))
    }

    private func showSelection(_ list: SwitcherList) {
        switcherList = list
        panel.update(state: buildState(list))
    }

    /// The last app gone closes the switcher.
    private func removeApp(at index: Int, from list: SwitcherList) {
        let remainingList = list.removingApp(at: index)
        if remainingList.isEmpty {
            dismissSwitcher()
            return
        }

        switcherList = remainingList
        panel.removeApp(at: index, state: buildState(remainingList))
    }

    /// Keeps the selected app selected when it is still listed.
    private func toggleFilter() {
        let selectedIdentifier = switcherList!.selectedApp.bundleIdentifier
        let whitelistStore = settings.whitelistStore

        whitelistStore.setFilterEnabled(!whitelistStore.isFilterEnabled)
        let list = listLoader.loadAppList()
        if list.isEmpty {
            dismissSwitcher()
            return
        }

        let selectedList = list.selectingApp(bundleIdentifier: selectedIdentifier)
        switcherList = selectedList
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
        switcherList = list
        panel.show(state: buildState(list), glassStore: settings.getGlassStore(listingWindows: list.isListingWindows))
        panel.showHintsAfterDelay()
        refreshThumbnails(of: list, inPreview: false)
    }

    /// Each thumbnail shows in the panel as it arrives, while the panel is up.
    private func refreshThumbnails(of list: SwitcherList, inPreview: Bool) {
        guard case .windows(let windows) = list.items else { return }

        let session = inPreview ? previewSession : switcherSession
        screen.captureThumbnails(of: windows.map { $0.windowID }) { windowID, thumbnail in
            let currentSession = inPreview ? self.previewSession : self.switcherSession
            if currentSession != session { return }

            self.thumbnails[windowID] = thumbnail
            if inPreview {
                self.previewPanel.update(state: self.buildState(self.previewList!))
            } else {
                self.panel.update(state: self.buildState(self.switcherList!))
            }
        }
    }

    private func buildState(_ list: SwitcherList) -> SwitcherState {
        return settings.buildState(list: list, thumbnails: thumbnails)
    }

    /// A window is raised on the next turn of the main queue: its accessibility round trips must stay out of the tap callback releasing Cmd.
    private func activateSelection(of list: SwitcherList) {
        switch list.items {
        case .windows(let windows):
            let window = windows[list.selectedIndex]
            let session = featureSession
            DispatchQueue.main.async {
                if self.featureSession != session { return }

                window.bringToFront()
            }

            // Dismissal queues preview restoration after the window raise.
            dismissSwitcher()
        case .apps(let apps, _):
            dismissSwitcher()
            apps[list.selectedIndex].activate()
        }
    }

    private func dismissSwitcher() {
        switcherSession += 1
        isOpening = false
        switcherList = nil
        panel.hide()

        let session = switcherSession
        DispatchQueue.main.async {
            if self.switcherSession != session { return }

            self.refreshPreview()
        }
    }

    // MARK: preview

    /// Reuses the shown preview's list and views until its mode changes or it hides.
    private func refreshPreview() {
        guard let settingsWindow else { return }
        if !settingsWindow.isKeyWindow {
            hidePreview()
            return
        }
        if !settings.previewStore.isShown {
            hidePreview()
            return
        }
        if switcherList != nil { return }
        if isOpening { return }

        let listingWindows = settings.previewStore.isListingWindows

        if let previewList, previewList.isListingWindows == listingWindows {
            previewPanel.updateGlass(state: buildState(previewList), glassStore: settings.getGlassStore(listingWindows: listingWindows))
            return
        }

        hidePreview()
        guard let list = loadPreviewList(listingWindows: listingWindows) else { return }
        if list.isEmpty { return }

        let selectedList = list.selecting(min(1, list.count - 1))
        previewList = selectedList
        previewPanel.showPreview(state: buildState(selectedList), glassStore: settings.getGlassStore(listingWindows: listingWindows), beside: settingsWindow)
        refreshThumbnails(of: selectedList, inPreview: true)
    }

    /// The windows are the most recent app's; nil without one.
    private func loadPreviewList(listingWindows: Bool) -> SwitcherList? {
        if !listingWindows { return listLoader.loadAppList() }

        guard let app = listLoader.getRecentRunningApps().first else { return nil }
        return loadWindowList(of: app)
    }

    private func hidePreview() {
        previewSession += 1
        previewList = nil
        previewPanel.hide()
    }
}
