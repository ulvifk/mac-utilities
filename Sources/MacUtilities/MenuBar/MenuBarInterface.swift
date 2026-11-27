import AppKit

/// The app's interface: the menu bar item, whose button toggles the popover, and the settings window. The item shows from the start, so a
/// feature can set its symbol before launch; the popover and the window are built at launch, once the controller they observe runs.
final class MenuBarInterface: NSObject, AppInterface {
    private let statusItem: NSStatusItem
    private let menuBarGlyph: NSImage
    private let loginItem: LoginItem // switched in the settings window's General pane

    private(set) var menuBarPopover: MenuBarPopover!
    /// Built at launch rather than when first opened, since building every pane takes a moment.
    private(set) var settingsWindow: SettingsWindow!

    init(statusItem: NSStatusItem, menuBarGlyph: NSImage, loginItem: LoginItem) {
        self.statusItem = statusItem
        self.menuBarGlyph = menuBarGlyph
        self.loginItem = loginItem
    }

    func launch(controller: AppController) {
        let popoverView = MenuBarPopoverView(controller: controller) { [unowned self] in self.openSettings(controller: controller) }

        menuBarPopover = MenuBarPopover(rootView: popoverView, statusItemButton: statusItem.button!)
        settingsWindow = SettingsWindow(controller: controller, loginItem: loginItem)
        statusItem.button!.target = self
        statusItem.button!.action = #selector(MenuBarInterface.toggleMenuBarPopover)

        runSettingsSmokeTestIfRequested(interface: self, controller: controller)
        runMenuBarSmokeTestIfRequested(interface: self)
    }

    /// A feature doing something in the background shows its own symbol in the menu bar; nil shows the app's glyph.
    func setMenuBarSymbol(_ symbolName: String?) {
        guard let symbolName else {
            statusItem.button!.image = menuBarGlyph
            return
        }

        statusItem.button!.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Mac Utilities")
    }

    /// While no shortcut works it opens on General, whose card says why. The popover would stay open over the window otherwise: it closes by
    /// itself only on a click elsewhere. The window goes first, so the popover closing finds it key and leaves the app active.
    func openSettings(controller: AppController) {
        if !controller.isEventTapRunning {
            settingsWindow.showPane(generalPaneIdentifier)
        }

        settingsWindow.open()
        menuBarPopover.close()
    }

    func openGeneralSettings() {
        settingsWindow.showPane(generalPaneIdentifier)
        settingsWindow.open()
    }

    @objc private func toggleMenuBarPopover() {
        menuBarPopover.toggle()
    }
}
