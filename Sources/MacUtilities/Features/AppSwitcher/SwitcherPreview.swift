import AppKit
import Combine

/// The switcher drawn live beside the settings pane while Show preview is checked and the pane has focus, listing as the switcher would. It
/// keeps its list and views while only the look changes, loads afresh when the mode or the whitelist changes, and steps aside while the
/// switcher is up.
final class SwitcherPreview {
    private let panel: SwitcherPanel
    private let settings: SwitcherSettings
    private let listLoader: SwitcherListLoader
    private let thumbnailCache: WindowThumbnailCache
    private var subscriptions: [AnyCancellable] = []

    private weak var settingsWindow: NSWindow?

    /// The shown preview's list; nil while it is hidden.
    private var list: SwitcherList?
    /// While the switcher is opening or open.
    private var isSuspended = false
    /// Renewed when the preview hides.
    private let session = SwitcherSession()

    init(panel: SwitcherPanel, settings: SwitcherSettings, listLoader: SwitcherListLoader, thumbnailCache: WindowThumbnailCache) {
        self.panel = panel
        self.settings = settings
        self.listLoader = listLoader
        self.thumbnailCache = thumbnailCache
    }

    /// Follows the settings and the settings window's focus from here on.
    func start() {
        subscriptions = [
            observeSettingsFocusChanges(),
            observeChanges(of: settings.whitelistStore, reloadingList: true),
            observeChanges(of: settings.appearanceStore),
            observeChanges(of: settings.appGlassStore),
            observeChanges(of: settings.windowGlassStore),
            observeChanges(of: settings.appCardStore),
            observeChanges(of: settings.appCardGlassStore),
            observeChanges(of: settings.windowCardStore),
            observeChanges(of: settings.windowCardGlassStore),
            observeChanges(of: settings.previewStore),
        ]
    }

    /// Unchecks Show preview and hides.
    func stop() {
        subscriptions = []
        settings.previewStore.isShown = false
        hide()
    }

    /// A shown preview follows the window; closing it unchecks Show preview.
    func settingsWindowChanged(_ window: NSWindow?) {
        settingsWindow = window
        if let window {
            if list != nil {
                panel.positionPreview(beside: window)
            }
            return
        }

        settings.previewStore.isShown = false
        hide()
    }

    /// Hides for the switcher, which is opening.
    func suspend() {
        isSuspended = true
        hide()
    }

    /// Comes back once the switcher has closed.
    func resume() {
        isSuspended = false
        refresh()
    }

    /// An app quit: a shown preview loads afresh.
    func reloadIfShown() {
        if list == nil { return }

        hide()
        refresh()
    }

    /// An app was hidden or shown: a shown preview redraws its dimming.
    func redrawIfShown() {
        guard let list else { return }

        panel.update(state: buildState(list))
    }

    /// The stores announce changes before making them, so the preview reads them on the next main-queue turn.
    private func observeChanges(of store: some ObservableObject, reloadingList: Bool = false) -> AnyCancellable {
        return store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in
                if reloadingList {
                    self.hide()
                }
                self.refresh()
            }
    }

    private func observeSettingsFocusChanges() -> AnyCancellable {
        return NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification))
            .sink { notification in
                let window = notification.object as! NSWindow
                if window !== self.settingsWindow { return }

                self.refresh()
            }
    }

    /// Shows, keeps or hides the preview as the settings window, the checkbox and the switcher have it now. Reuses the shown preview's list
    /// and views until its mode changes or it hides.
    private func refresh() {
        guard let settingsWindow else { return }
        if !settingsWindow.isKeyWindow {
            hide()
            return
        }
        if !settings.previewStore.isShown {
            hide()
            return
        }
        if isSuspended { return }

        let listingWindows = settings.previewStore.isListingWindows

        if let list, list.isListingWindows == listingWindows {
            panel.updateGlass(state: buildState(list), glassStore: settings.getGlassStore(listingWindows: listingWindows))
            return
        }

        hide()
        guard let loadedList = loadList(listingWindows: listingWindows) else { return }
        if loadedList.isEmpty { return }

        show(loadedList.selecting(min(1, loadedList.count - 1)), beside: settingsWindow)
    }

    /// The windows are the most recent app's; nil without one.
    private func loadList(listingWindows: Bool) -> SwitcherList? {
        if !listingWindows { return listLoader.loadAppList() }

        guard let app = listLoader.getRecentRunningApps().first else { return nil }
        return listLoader.loadWindowList(of: app)
    }

    /// Windows show their last thumbnail, or their app's icon, until a fresh one comes in.
    private func show(_ list: SwitcherList, beside settingsWindow: NSWindow) {
        self.list = list
        panel.showPreview(state: buildState(list), glassStore: settings.getGlassStore(listingWindows: list.isListingWindows), beside: settingsWindow)

        guard case .windows(let windows, _) = list.items else { return }
        thumbnailCache.refresh(of: windows, session: session) { self.panel.update(state: self.buildState(self.list!)) }
    }

    private func hide() {
        session.renew()
        list = nil
        panel.hide()
    }

    private func buildState(_ list: SwitcherList) -> SwitcherState {
        return settings.buildState(list: list, thumbnails: thumbnailCache.thumbnails)
    }
}
