import AppKit

enum MenuBarInterfaceFactory {
    /// Puts the app's item in the menu bar, showing the app's glyph. The login item goes on to the settings window's General pane.
    static func buildInterface(loginItem: LoginItem) -> MenuBarInterface {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let interface = MenuBarInterface(statusItem: statusItem, menuBarGlyph: buildMenuBarGlyph(), loginItem: loginItem)

        interface.setMenuBarSymbol(nil)

        return interface
    }
}
