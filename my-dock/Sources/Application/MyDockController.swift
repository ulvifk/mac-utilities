import AppKit

final class MyDockController: NSObject, NSApplicationDelegate, DockEventHandler {
    private let session: DockSession
    private var timer: Timer?

    private lazy var menus = DockMenus(handler: self)
    private lazy var window = DockWindow(handler: self, menus: menus)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(session: DockSession) {
        self.session = session
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.show()
        statusItem.button!.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "MyDock")
        statusItem.menu = menus.buildStatusMenu()

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            center.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [unowned self] _ in self.refresh() }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer!.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func perform(_ action: DockAction) {
        switch action {
        case .edit(let edit): try! session.apply(edit)
        case .openApp(let app): ApplicationActions.open(app)
        case .revealApp(let app): ApplicationActions.reveal(app.url)
        case .quitApp(let app): ApplicationActions.quit(app)
        case .openTrash: ApplicationActions.openTrash()
        case .showSavedList: ApplicationActions.reveal(session.fileURL)
        case .quitDock: NSApp.terminate(nil)
        }
        refresh()
    }

    func canAcceptDrop(_ payload: DockDragPayload) -> Bool {
        switch payload {
        case .appID(let id): return session.state.getApp(id: id) != nil
        case .applications: return true
        }
    }

    func acceptDrop(_ payload: DockDragPayload, at target: DockDropTarget) -> Bool {
        if !canAcceptDrop(payload) { return false }
        try! session.apply(payload.getEdit(at: target))
        return true
    }

    func interactionDidEnd() { refresh() }

    @objc private func refresh() {
        if window.isInteracting { return }
        let running = AppCatalog.getRunningApplications()
        try! session.registerRunningApps(AppCatalog.getRunningApps(running))
        let runningIDs = Set(running.compactMap(\.bundleIdentifier))
        let items = DockItems.build(state: session.state, runningIDs: runningIDs, badges: DockBadges.read())
        window.render(items)
    }
}
