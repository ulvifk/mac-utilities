import AppKit
import ServiceManagement
import os

let application = NSApplication.shared
let preferences = Preferences(defaults: .standard)
let loginItem = SMAppService.mainApp
let interface = MenuBarInterfaceFactory.buildInterface(loginItem: loginItem)

let keepAwake = KeepAwakeFeatureFactory.buildFeature(setMenuBarSymbol: interface.setMenuBarSymbol)
let hotkeys = HotkeysFeature(toggleKeepAwake: {
    if !preferences.isFeatureEnabled(keepAwake.identifier) {
        Logger.hotkeys.notice("Keep Awake hotkey ignored: Keep Awake is switched off")
        return
    }
    keepAwake.toggle(from: .hotkey)
})
let microphone = MicrophoneFeature(audioInput: SystemAudioInput(hardware: SystemAudioHardware()))
let features: [Feature] = [AppSwitcherFeatureFactory.buildFeature(), keepAwake, hotkeys, microphone]

let controller = AppController(
    features: features,
    preferences: preferences,
    eventTap: SystemEventTap(),
    loginItem: loginItem,
    isInstalled: isInApplicationsFolder(
        bundleURL: Bundle.main.bundleURL,
        applicationsFolders: FileManager.default.urls(for: .applicationDirectory, in: [.userDomainMask, .localDomainMask])
    ),
    interface: interface
)
application.setActivationPolicy(.accessory)
application.delegate = controller
application.run()
