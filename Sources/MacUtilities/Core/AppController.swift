import AppKit
import Combine

private let appSymbolName = "square.stack.3d.up"

/// Owns the menu bar item, the event tap, the settings window and the features; starts and stops features as their toggles change.
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    let features: [Feature]

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let pauseItem = NSMenuItem(title: "Paused", action: #selector(AppController.togglePause), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings...", action: #selector(AppController.openSettings), keyEquivalent: ",")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(AppController.quit), keyEquivalent: "q")
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
        pauseItem.target = self
        settingsItem.target = self
        quitItem.target = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setMenuBarSymbol(nil)
        statusItem.menu = menu
        startEnabledFeatures()
        populateMenu()
        requestAccessibilityTrust()
        eventTap.start()
        runSettingsSmokeTestIfRequested(controller: self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        for feature in enabledFeatures {
            feature.stop()
        }
    }

    func isFeatureEnabled(_ feature: Feature) -> Bool {
        return preferences.isFeatureEnabled(feature.identifier)
    }

    func setFeatureEnabled(_ feature: Feature, _ enabled: Bool) {
        preferences.setFeatureEnabled(feature.identifier, enabled)
        enabledFeatures = getEnabledFeatures()
        populateMenu()

        if enabled {
            feature.start()
        } else {
            feature.stop()
        }
    }

    /// A feature doing something in the background shows its own symbol in the menu bar; nil shows the app's.
    func setMenuBarSymbol(_ symbolName: String?) {
        statusItem.button?.image = NSImage(systemSymbolName: symbolName ?? appSymbolName, accessibilityDescription: "Mac Utilities")
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

    /// Paused, then the enabled features' entries, then Settings and Quit.
    private func populateMenu() {
        menu.removeAllItems()

        menu.addItem(pauseItem)
        for feature in enabledFeatures {
            for item in feature.menuItems {
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        isPaused = !isPaused
        sender.state = isPaused ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
