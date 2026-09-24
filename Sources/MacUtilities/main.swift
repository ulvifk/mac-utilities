import AppKit

let application = NSApplication.shared
let keepAwake: KeepAwakeFeature = KeepAwakeFeature(setMenuBarSymbol: { controller.setMenuBarSymbol($0) })
let controller: AppController = AppController(features: [
    AppSwitcherFeature(),
    keepAwake,
    HotkeysFeature(toggleKeepAwake: {
        if !controller.isFeatureEnabled(keepAwake) { return }
        keepAwake.toggle()
    }),
])

application.setActivationPolicy(.accessory)
application.delegate = controller
application.run()
