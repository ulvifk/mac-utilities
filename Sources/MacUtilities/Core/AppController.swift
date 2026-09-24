import AppKit

/// Owns the menu bar item, the event tap and the features; starts and stops features as their toggles change.
final class AppController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let features: [Feature]
    private let preferences: Preferences

    private var eventTap: EventTap!
    /// The running features, in the order the tap offers events to them.
    private var enabledFeatures: [Feature] = []

    init(features: [Feature]) {
        self.features = features
        preferences = Preferences(featureIdentifiers: features.map { $0.identifier })
        super.init()

        eventTap = EventTap { [unowned self] type, event in self.handle(type: type, event: event) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        startEnabledFeatures()
        requestAccessibilityTrust()
        eventTap.start()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
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

        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Mac Utilities")

        for feature in features {
            menu.addItem(buildToggleItem(feature: feature))
        }
        menu.addItem(.separator())

        for feature in features {
            for item in feature.buildMenuItems() {
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func buildToggleItem(feature: Feature) -> NSMenuItem {
        let item = NSMenuItem(title: feature.displayName, action: #selector(toggleFeature), keyEquivalent: "")

        item.target = self
        item.representedObject = feature
        item.state = preferences.isFeatureEnabled(feature.identifier) ? .on : .off

        return item
    }

    @objc private func toggleFeature(_ sender: NSMenuItem) {
        let feature = sender.representedObject as! Feature
        let enabled = !preferences.isFeatureEnabled(feature.identifier)

        preferences.setFeatureEnabled(feature.identifier, enabled)
        sender.state = enabled ? .on : .off
        enabledFeatures = getEnabledFeatures()

        if enabled {
            feature.start()
        } else {
            feature.stop()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
