import AppKit

final class DockMenuItem: NSMenuItem {
    let command: DockAction

    init(title: String, command: DockAction, target: DockMenus) {
        self.command = command
        super.init(title: title, action: #selector(DockMenus.performMenuCommand), keyEquivalent: "")
        self.target = target
    }

    required init(coder: NSCoder) { fatalError("Use init(title:command:target:)") }
}

final class DockMenus: NSObject {
    private unowned let handler: DockEventHandler

    init(handler: DockEventHandler) {
        self.handler = handler
        super.init()
    }

    func buildAppMenu(for item: DockItem) -> NSMenu? {
        guard case .application(let tile) = item else { return nil }
        let app = tile.app
        let menu = NSMenu(title: app.name)
        menu.addItem(buildItem("Open", command: .openApp(app)))
        menu.addItem(buildItem("Show in Finder", command: .revealApp(app)))
        menu.addItem(.separator())

        let keepItem = buildItem("Keep in MyDock", command: .edit(.setKept(appID: app.id, isKept: !app.isKept)))
        keepItem.state = app.isKept ? .on : .off
        menu.addItem(keepItem)
        let destination: AppGroup = tile.group == .visible ? .hidden : .visible
        let target = DockDropTarget(group: destination, beforeAppID: nil)
        menu.addItem(buildItem("Move to \(destination.rawValue.capitalized) Group", command: .edit(.moveApp(appID: app.id, target: target))))
        if canQuit(tile) {
            menu.addItem(.separator())
            menu.addItem(buildItem("Quit", command: .quitApp(app)))
        }
        return menu
    }

    func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(buildItem("Show / Hide Hidden Group", command: .edit(.toggleHiddenGroup)))
        menu.addItem(buildItem("Open Saved App List", command: .showSavedList))
        menu.addItem(.separator())
        menu.addItem(buildItem("Quit MyDock", command: .quitDock))
        return menu
    }

    @objc func performMenuCommand(_ item: DockMenuItem) {
        handler.perform(item.command)
    }

    private func buildItem(_ title: String, command: DockAction) -> DockMenuItem {
        return DockMenuItem(title: title, command: command, target: self)
    }

    private func canQuit(_ tile: AppTile) -> Bool {
        if tile.app.id == "com.apple.finder" { return false }
        return tile.isRunning
    }
}
