import AppKit
import Combine

/// Owns the menu bar item and its popover, the event tap, the settings window and the features; starts and stops features as their toggles change.
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    let features: [Feature]

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menuBarGlyph = buildMenuBarGlyph()
    private let preferences = Preferences()
    private lazy var menuBarPopover = MenuBarPopover(rootView: MenuBarPopoverView(controller: self), statusItemButton: statusItem.button!)
    private(set) lazy var settingsWindow = SettingsWindow(rootView: SettingsView(controller: self))

    private var eventTap: EventTap!
    /// The running features, in the order the tap offers events to them.
    @Published private(set) var enabledFeatures: [Feature] = []
    /// While paused every event passes through untouched; the features keep running.
    @Published private(set) var isPaused = false
    @Published var selectedSettingsTabIdentifier = generalTabIdentifier

    init(features: [Feature]) {
        self.features = features
        super.init()

        eventTap = EventTap { [unowned self] type, event in self.handle(type: type, event: event) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setMenuBarSymbol(nil)
        statusItem.button!.target = self
        statusItem.button!.action = #selector(AppController.toggleMenuBarPopover)
        startEnabledFeatures()
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

        if enabled {
            feature.start()
        } else {
            feature.stop()
        }
    }

    /// Every shortcut depends on it; without Accessibility at launch there is none until the app is reopened.
    var isEventTapRunning: Bool {
        return eventTap.isRunning
    }

    func togglePause() {
        isPaused = !isPaused
    }

    /// A feature doing something in the background shows its own symbol in the menu bar; nil shows the app's glyph.
    func setMenuBarSymbol(_ symbolName: String?) {
        guard let symbolName else {
            statusItem.button!.image = menuBarGlyph
            return
        }

        statusItem.button!.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Mac Utilities")
    }

    /// The popover would stay open over the window otherwise: it closes by itself only on a click elsewhere. The window goes first, so the
    /// popover closing finds it key and leaves the app active.
    func openSettings() {
        settingsWindow.open()
        menuBarPopover.close()
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

    @objc private func toggleMenuBarPopover() {
        menuBarPopover.toggle()
    }
}
