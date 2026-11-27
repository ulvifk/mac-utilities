import AppKit

/// Puts the app's item in the menu bar, showing the app's glyph.
func buildMenuBarInterface() -> MenuBarInterface {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let interface = MenuBarInterface(statusItem: statusItem, menuBarGlyph: buildMenuBarGlyph())

    interface.setMenuBarSymbol(nil)

    return interface
}
