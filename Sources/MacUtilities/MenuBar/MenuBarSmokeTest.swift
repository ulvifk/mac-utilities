import AppKit

/// MENU_BAR_SMOKE_TEST=1: opens the menu bar popover, captures it to /tmp/menu-bar-smoke.png and exits.
func runMenuBarSmokeTestIfRequested(controller: AppController) {
    guard ProcessInfo.processInfo.environment["MENU_BAR_SMOKE_TEST"] != nil else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        controller.menuBarPopover.toggle()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        let window = controller.menuBarPopover.contentViewController!.view.window!
        print("smoke: popover frame=\(window.frame) shown=\(controller.menuBarPopover.isShown) key=\(window.isKeyWindow)")
        writeCapture(around: window, path: "/tmp/menu-bar-smoke.png")
        exit(0)
    }
}
