import AppKit

let application = NSApplication.shared
let controller = AppController(features: [
    AppSwitcherFeature(),
    KeepAwakeFeature(setMenuBarSymbol: { controller.setMenuBarSymbol($0) }),
])

application.setActivationPolicy(.accessory)
application.delegate = controller
application.run()
