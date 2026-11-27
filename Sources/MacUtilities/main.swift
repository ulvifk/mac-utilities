import AppKit

let application = NSApplication.shared
let preferences = Preferences(defaults: .standard)
let interface = buildMenuBarInterface()

let keepAwake = KeepAwakeFeatureFactory.buildFeature(setMenuBarSymbol: interface.setMenuBarSymbol)
let hotkeys = HotkeysFeature(toggleKeepAwake: {
    if !preferences.isFeatureEnabled(keepAwake.identifier) { return }
    keepAwake.toggle()
})
let microphone = MicrophoneFeature(audioInput: SystemAudioInput(hardware: SystemAudioHardware()))
let features: [Feature] = [AppSwitcherFeature(), keepAwake, hotkeys, microphone]

let controller = AppController(features: features, preferences: preferences, eventTap: SystemEventTap(), interface: interface)
application.setActivationPolicy(.accessory)
application.delegate = controller
application.run()
