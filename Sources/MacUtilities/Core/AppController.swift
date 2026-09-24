import AppKit
import Combine

/// Owns the menu bar item, the event tap, the settings window and the features; starts and stops features as their toggles change.
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    let features: [Feature]

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let preferences = Preferences()
    private(set) lazy var settingsWindow = SettingsWindow(rootView: SettingsView(controller: self))

    private var eventTap: EventTap!
    /// The running features, in the order the tap offers events to them.
    @Published private(set) var enabledFeatures: [Feature] = []
    /// While paused every event passes through untouched; the features keep running.
    private var isPaused = false
    @Published var selectedSettingsTabIdentifier = generalTabIdentifier

    init(features: [Feature]) {
        self.features = features
        super.init()

        eventTap = EventTap { [unowned self] type, event in self.handle(type: type, event: event) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        startEnabledFeatures()
        requestAccessibilityTrust()
        eventTap.start()
        runSettingsSmokeTestIfRequested(controller: self)
    }

    func isFeatureEnabled(_ feature: Feature) -> Bool {
        return preferences.isFeatureEnabled(feature.identifier)
    }

    func setFeatureEnabled(_ feature: Feature, _ enabled: Bool) {
        preferences.setFeatureEnabled(feature.identifier, enabled)
        enabledFeatures = getEnabledFeatures()

        if enabled {
            feature.start()
        } else {
            feature.stop()
        }
    }

    @objc func openSettings() {
        settingsWindow.open()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        if isPaused { return false }

        for feature in enabledFeatures {
            if feature.handle(type: type, event: event) { return true }
        }

        return false
    }

    private func startEnabledFeatures() {
        enabledFeatures = getEnabledFeatures()
        for feature in enabledFeatures {
            feature.start()
        }
    }

    private func getEnabledFeatures() -> [Feature] {
        return features.filter { preferences.isFeatureEnabled($0.identifier) }
    }

    private func buildMenu() {
        let menu = NSMenu()
        let pauseItem = NSMenuItem(title: "Paused", action: #selector(togglePause), keyEquivalent: "")
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Mac Utilities")
        pauseItem.target = self
        settingsItem.target = self
        quitItem.target = self

        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        isPaused = !isPaused
        sender.state = isPaused ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
