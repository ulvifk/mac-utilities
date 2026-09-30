import AppKit
import Combine
import SwiftUI

let keepAwakeSymbolName = "cup.and.saucer.fill"

/// Owns Keep Awake transitions and publishes the session after its power commands succeed.
final class KeepAwakeFeature: Feature, ObservableObject {
    private static let sleepRestorationRetryInterval: TimeInterval = 5

    let identifier = "keep-awake"
    let displayName = "Keep Awake"
    let summary = "Keeps the Mac awake from the menu bar, even with the lid closed."
    let iconSymbolName = keepAwakeSymbolName
    let iconGradient = Gradient(colors: [.orange, .brown])

    private let preferences = KeepAwakePreferences()
    private let powerSource = ExternalPowerSource()
    private let setMenuBarSymbol: (String?) -> Void

    @Published private(set) var session: KeepAwakeSession?
    @Published private(set) var isChangingSession = false
    @Published private(set) var isPmsetRefused = false
    @Published private(set) var isSleepRestorationRefused = false

    private var requestedSession: KeepAwakeSession?
    private var transition: Task<Void, Never>?
    private var deactivation: DispatchWorkItem?
    private var sleepRestorationRetry: DispatchWorkItem?
    private var conditionChanges: [AnyCancellable] = []
    private var isTerminating = false

    init(setMenuBarSymbol: @escaping (String?) -> Void) {
        self.setMenuBarSymbol = setMenuBarSymbol

        conditionChanges = [observeConditionChanges(of: preferences), observeConditionChanges(of: powerSource)]
    }

    func start() {}

    func stop() {
        requestedSession = nil
        updateSession()
    }

    @MainActor func prepareForTermination() async {
        isTerminating = true
        stop()
        await transition?.value

        deactivation?.cancel()
        deactivation = nil
        sleepRestorationRetry?.cancel()
        sleepRestorationRetry = nil
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        return false
    }

    func buildSettingsSections() -> AnyView {
        return AnyView(KeepAwakeSettingsView(preferences: preferences))
    }

    func buildPopoverTile() -> AnyView? {
        return AnyView(KeepAwakeTile(feature: self, preferences: preferences))
    }

    func toggle() {
        if isTerminating { return }
        if isSleepRestorationRefused {
            stop()
            return
        }
        if requestedSession != nil {
            stop()
            return
        }

        requestedSession = KeepAwakeSession(preferences: preferences)
        updateSession()
    }

    func turnOn(for autoOff: KeepAwakeAutoOff) {
        if isTerminating { return }

        preferences.setAutoOff(autoOff)
        requestedSession = KeepAwakeSession(preferences: preferences)
        updateSession()
    }

    var isWaitingForPower: Bool {
        if requestedSession == nil { return false }
        if isRequestedSessionExpired() { return false }
        return !isPowerAllowed()
    }

    private func updateSession() {
        objectWillChange.send()

        deactivation?.cancel()
        deactivation = nil
        sleepRestorationRetry?.cancel()
        sleepRestorationRetry = nil

        if isRequestedSessionExpired() { requestedSession = nil }
        if let deactivationDate = requestedSession?.deactivationDate {
            deactivation = scheduleUpdate(at: deactivationDate, turnsOff: true)
        }

        if transition != nil { return }
        if session === getEligibleSession() { return }

        transition = Task { @MainActor in
            isChangingSession = true
            await reconcileSession()
            isChangingSession = false
            transition = nil
        }
    }

    @MainActor private func reconcileSession() async {
        while true {
            let eligibleSession = getEligibleSession()
            if session === eligibleSession { return }

            if let session {
                let didRestoreSleep = await session.end()
                if !didRestoreSleep {
                    isSleepRestorationRefused = true
                    sleepRestorationRetry = scheduleUpdate(at: Date(timeIntervalSinceNow: Self.sleepRestorationRetryInterval))
                    return
                }

                self.session = nil
                isSleepRestorationRefused = false
                setMenuBarSymbol(nil)
                continue
            }

            let nextSession = eligibleSession!
            let didBegin = await nextSession.begin()
            if !didBegin {
                isPmsetRefused = true
                if requestedSession === nextSession { stop() }
                continue
            }

            session = nextSession
            isPmsetRefused = false
            setMenuBarSymbol(keepAwakeSymbolName)
        }
    }

    private func getEligibleSession() -> KeepAwakeSession? {
        if isRequestedSessionExpired() { return nil }
        if !isPowerAllowed() { return nil }
        return requestedSession
    }

    private func isRequestedSessionExpired() -> Bool {
        guard let deactivationDate = requestedSession?.deactivationDate else { return false }
        return deactivationDate <= Date()
    }

    private func isPowerAllowed() -> Bool {
        if !preferences.onlyWhileConnectedToPower { return true }
        return powerSource.isConnected
    }

    private func observeConditionChanges(of store: some ObservableObject) -> AnyCancellable {
        return store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] _ in
                if self.isTerminating { return }
                self.updateSession()
            }
    }

    /// Uses wall time so a Mac that slept past its deadline turns off on waking.
    private func scheduleUpdate(at date: Date, turnsOff: Bool = false) -> DispatchWorkItem {
        let deactivation = DispatchWorkItem { [unowned self] in
            if turnsOff {
                stop()
                return
            }
            updateSession()
        }
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + date.timeIntervalSinceNow, execute: deactivation)
        return deactivation
    }
}
