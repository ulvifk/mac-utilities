import AppKit
import Combine
import os

/// The app delegate. Starts the enabled features at launch and stops them as their switches change or the app quits, offers them every
/// tapped event unless paused, and launches the app's interface once they run. The installed app's first launch registers it as a login
/// item.
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    let features: [Feature]
    let loginItem: LoginItem

    private let preferences: Preferences
    private let eventTap: EventTap
    private let interface: AppInterface
    private let isInstalled: Bool // in an Applications folder; a development build never registers itself as a login item

    /// The running features, in the order the tap offers events to them.
    @Published private(set) var enabledFeatures: [Feature] = []
    /// While paused every event passes through untouched; the features keep running.
    @Published private(set) var isPaused = false

    init(features: [Feature], preferences: Preferences, eventTap: EventTap, loginItem: LoginItem, isInstalled: Bool, interface: AppInterface) {
        self.features = features
        self.preferences = preferences
        self.eventTap = eventTap
        self.loginItem = loginItem
        self.isInstalled = isInstalled
        self.interface = interface
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startEnabledFeatures()
        eventTap.start { [unowned self] type, event in self.handle(type: type, event: event) }
        interface.launch(controller: self)

        if isFirstInstalledLaunch() {
            registerLoginItem()
            openGeneralSettingsIfLoginItemAwaitsApproval()
        }
    }

    /// Stops the enabled features at once, so no event reaches them while they clean up, then lets every feature finish its cleanup before
    /// AppKit goes on quitting.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Logger.core.notice("Quitting")
        for feature in enabledFeatures {
            stop(feature, because: .quit)
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
            Logger.core.notice("Starting \(feature.displayName, privacy: .public): switched on")
            feature.start()
        } else {
            stop(feature, because: .switchedOff)
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

    /// Only the installed app records its launches, so a development build, the smoke runs included, neither registers the login item nor
    /// uses up the installed app's first launch.
    private func isFirstInstalledLaunch() -> Bool {
        if !isInstalled { return false }
        return preferences.isFirstLaunch()
    }

    /// Registers once, on the first launch, so switching it off in General sticks. The launch is recorded first, so a registration that
    /// fails is not retried on every launch either; the switch is there for that. A login item the user switched on before this version is
    /// left as it is.
    private func registerLoginItem() {
        preferences.recordFirstLaunch()

        if loginItem.status.isRegistered {
            Logger.core.notice("First launch: login item already registered, \(self.loginItem.status.logDescription, privacy: .public)")
            return
        }

        do {
            try loginItem.register()
        } catch {
            Logger.core.error("First launch: registering the login item failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        Logger.core.notice("First launch: registered the login item, \(self.loginItem.status.logDescription, privacy: .public)")
    }

    /// Until the user approves it under Login Items the app does not start at login, so General, which says so and links there, opens. The
    /// pane re-reads the status whenever its window becomes key, so it shows the registration just made.
    private func openGeneralSettingsIfLoginItemAwaitsApproval() {
        if loginItem.status != .requiresApproval { return }

        Logger.core.notice("Opening General: the login item awaits approval under Login Items")
        interface.openGeneralSettings()
    }

    private func startEnabledFeatures() {
        enabledFeatures = getEnabledFeatures()
        for feature in enabledFeatures {
            Logger.core.notice("Starting \(feature.displayName, privacy: .public): launch")
            feature.start()
        }
    }

    private func stop(_ feature: Feature, because cause: FeatureStopCause) {
        Logger.core.notice("Stopping \(feature.displayName, privacy: .public): \(cause.rawValue, privacy: .public)")
        feature.stop(because: cause)
    }

    private func getEnabledFeatures() -> [Feature] {
        return features.filter { preferences.isFeatureEnabled($0.identifier) }
    }
}
