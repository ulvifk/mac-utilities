import AppKit

/// MENU_BAR_SMOKE_TEST=1: opens the menu bar popover, captures it to /tmp/menu-bar-smoke.png and exits.
func runMenuBarSmokeTestIfRequested(interface: MenuBarInterface) {
    guard ProcessInfo.processInfo.environment["MENU_BAR_SMOKE_TEST"] != nil else { return }

    let popover = interface.menuBarPopover!

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        popover.toggle()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        let window = popover.contentViewController!.view.window!
        print("smoke: popover frame=\(window.frame) shown=\(popover.isShown) key=\(window.isKeyWindow)")
        writeCapture(around: window, path: "/tmp/menu-bar-smoke.png")
        exit(0)
    }
}
