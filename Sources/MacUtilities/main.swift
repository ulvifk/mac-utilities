import AppKit

let application = NSApplication.shared
let controller = AppController(features: [AppSwitcherFeature()])

application.setActivationPolicy(.accessory)
application.delegate = controller
application.run()
