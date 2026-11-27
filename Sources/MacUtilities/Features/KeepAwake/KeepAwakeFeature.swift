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

    private let preferences: KeepAwakePreferences
    private let powerManagement: PowerManagement
    private let clock: WallClock
    private let setMenuBarSymbol: (String?) -> Void

    @Published private(set) var session: KeepAwakeSession?
    @Published private(set) var isChangingSession = false
    @Published private(set) var isPmsetRefused = false
    @Published private(set) var isSleepRestorationRefused = false

    private var requestedSession: KeepAwakeSession?
    private var transition: Task<Void, Never>?
    private var deactivation: DispatchWorkItem?
    private var sleepRestorationRetry: DispatchWorkItem?
    private var preferenceChanges: AnyCancellable?
    private var isTerminating = false

    init(preferences: KeepAwakePreferences, powerManagement: PowerManagement, clock: WallClock, setMenuBarSymbol: @escaping (String?) -> Void) {
        self.preferences = preferences
        self.powerManagement = powerManagement
        self.clock = clock
        self.setMenuBarSymbol = setMenuBarSymbol

        // objectWillChange fires before the preference is stored, so the update waits for the next main queue turn.
        preferenceChanges = preferences.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] _ in updateSessionForChangedCondition() }
        powerManagement.startObservingExternalPower { [unowned self] in updateSessionForChangedCondition() }
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

        requestedSession = buildSessionFromPreferences()
        updateSession()
    }

    func turnOn(for autoOff: KeepAwakeAutoOff) {
        if isTerminating { return }

        preferences.setAutoOff(autoOff)
        requestedSession = buildSessionFromPreferences()
        updateSession()
    }

    /// True while an enabled session that has not run out is held back because the Mac is on battery.
    var isWaitingForPower: Bool {
        if requestedSession == nil { return false }
        if isRequestedSessionExpired() { return false }
        return !isPowerAllowed()
    }

    /// Reschedules the deadline of the requested session and starts a transition when the published session is not the eligible one. A running transition picks up the change itself.
    private func updateSession() {
        objectWillChange.send()

        deactivation?.cancel()
        deactivation = nil
        sleepRestorationRetry?.cancel()
        sleepRestorationRetry = nil

        if isRequestedSessionExpired() { requestedSession = nil }
        if let deactivationDate = requestedSession?.deactivationDate {
            deactivation = scheduleDeactivation(at: deactivationDate)
        }

        if transition != nil { return }
        if session === getEligibleSession() {
            isSleepRestorationRefused = false
            return
        }

        transition = Task { @MainActor in
            isChangingSession = true
            await reconcileSession()
            isChangingSession = false
            transition = nil
        }
    }

    /// Ends and begins sessions one command at a time until the published session is the eligible one, re-reading the eligible session after every command.
    ///
    /// - A session whose restoration fails stays published and is retried on a timer, unless it became eligible again meanwhile.
    /// - A refused activation drops the request it came from, unless a newer request replaced it.
    @MainActor private func reconcileSession() async {
        var didRestoreLidClosedSleep = false
        while true {
            let eligibleSession = getEligibleSession()
            if session === eligibleSession {
                isSleepRestorationRefused = false
                if didRestoreLidClosedSleep { sleepIfClosedLidIsLeftAwake() }
                return
            }

            if let session {
                let didRestoreSleep = await session.end()
                if !didRestoreSleep {
                    if session === getEligibleSession() { continue }

                    isSleepRestorationRefused = true
                    sleepRestorationRetry = scheduleSleepRestorationRetry()
                    return
                }

                self.session = nil
                isSleepRestorationRefused = false
                setMenuBarSymbol(nil)
                if session.keepsAwakeWithLidClosed { didRestoreLidClosedSleep = true }
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

    /// Sleeps the Mac the way macOS would have once a session stops holding a closed lid awake.
    ///
    /// - macOS decides whether a closed lid sleeps the Mac only on lid, power-source and display changes. When one of those ends the session, for example unplugging with "Only while connected to power" on, macOS decides while sleep is still disabled, and restoring sleep does not make it decide again.
    /// - Skipped when macOS's own rule keeps a closed lid awake, such as an external display on AC power; macOS then decides again on the next display or power change.
    /// - Skipped on Quit, so a log out, restart or shut down is never turned into a sleep.
    @MainActor private func sleepIfClosedLidIsLeftAwake() {
        if isTerminating { return }
        if session?.keepsAwakeWithLidClosed == true { return }
        if !powerManagement.isClosedLidCausingSleep() { return }

        powerManagement.sleepMac()
    }

    /// The duration and lid option are read once here; later changes apply to the next session.
    private func buildSessionFromPreferences() -> KeepAwakeSession {
        let autoOff = preferences.autoOff
        return KeepAwakeSession(
            autoOff: autoOff,
            deactivationDate: autoOff.duration.map { clock.now().addingTimeInterval($0) },
            keepsAwakeWithLidClosed: preferences.keepsAwakeWithLidClosed,
            powerManagement: powerManagement
        )
    }

    private func getEligibleSession() -> KeepAwakeSession? {
        if isRequestedSessionExpired() { return nil }
        if !isPowerAllowed() { return nil }
        return requestedSession
    }

    private func isRequestedSessionExpired() -> Bool {
        guard let deactivationDate = requestedSession?.deactivationDate else { return false }
        return deactivationDate <= clock.now()
    }

    private func isPowerAllowed() -> Bool {
        if !preferences.onlyWhileConnectedToPower { return true }
        return powerManagement.isConnectedToExternalPower()
    }

    private func updateSessionForChangedCondition() {
        if isTerminating { return }
        updateSession()
    }

    private func scheduleDeactivation(at date: Date) -> DispatchWorkItem {
        let deactivation = DispatchWorkItem { [unowned self] in stop() }
        clock.schedule(deactivation, at: date)
        return deactivation
    }

    private func scheduleSleepRestorationRetry() -> DispatchWorkItem {
        let retry = DispatchWorkItem { [unowned self] in updateSession() }
        clock.schedule(retry, at: clock.now().addingTimeInterval(Self.sleepRestorationRetryInterval))
        return retry
    }
}
