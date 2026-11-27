import AppKit
import Combine

/// The app delegate. Starts the enabled features at launch and stops them as their switches change or the app quits, offers them every
/// tapped event unless paused, and launches the app's interface once they run.
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    let features: [Feature]

    private let preferences: Preferences
    private let eventTap: EventTap
    private let interface: AppInterface

    /// The running features, in the order the tap offers events to them.
    @Published private(set) var enabledFeatures: [Feature] = []
    /// While paused every event passes through untouched; the features keep running.
    @Published private(set) var isPaused = false

    init(features: [Feature], preferences: Preferences, eventTap: EventTap, interface: AppInterface) {
        self.features = features
        self.preferences = preferences
        self.eventTap = eventTap
        self.interface = interface
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startEnabledFeatures()
        eventTap.start { [unowned self] type, event in self.handle(type: type, event: event) }
        interface.launch(controller: self)
    }

    /// Stops the enabled features at once, so no event reaches them while they clean up, then lets every feature finish its cleanup before
    /// AppKit goes on quitting.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for feature in enabledFeatures {
            feature.stop()
        }
        enabledFeatures = []

        Task { @MainActor in
            for feature in features {
                await feature.prepareForTermination()
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
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
}
