import AppKit
import Combine
import os
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

    private var requestDropCause: KeepAwakeEndCause? // why requestedSession was last dropped; a session can end after its request
    private var wasWaitingForPower = false

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

    func stop(because cause: FeatureStopCause) {
        switch cause {
        case .switchedOff: dropRequest(because: .featureSwitchedOff)
        case .quit: beginTerminating()
        }
    }

    /// A feature switched off earlier is not stopped on Quit, so this begins terminating too.
    @MainActor func prepareForTermination() async {
        beginTerminating()
        await transition?.value

        sleepRestorationRetry?.cancel()
        sleepRestorationRetry = nil
    }

    func buildSettingsSections() -> AnyView {
        return AnyView(KeepAwakeSettingsView(preferences: preferences))
    }

    func buildPopoverTile() -> AnyView? {
        return AnyView(KeepAwakeTile(feature: self, preferences: preferences))
    }

    func toggle(from source: KeepAwakeRequestSource) {
        if isTerminating { return }
        if isSleepRestorationRefused {
            Logger.keepAwake.notice("Turn-off requested from \(source.rawValue, privacy: .public) while restoring sleep is refused; retrying now")
            dropRequest(because: .toggledOff)
            return
        }
        if requestedSession != nil {
            Logger.keepAwake.notice("Turn-off requested from \(source.rawValue, privacy: .public)")
            dropRequest(because: .toggledOff)
            return
        }

        requestedSession = buildSessionFromPreferences()
        logRequestedSession(from: source)
        updateSession()
    }

    func turnOn(for autoOff: KeepAwakeAutoOff) {
        if isTerminating { return }

        preferences.setAutoOff(autoOff)
        requestedSession = buildSessionFromPreferences()
        logRequestedSession(from: .durationChip)
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

        if isRequestedSessionExpired() {
            requestDropCause = .deadlineReached
            requestedSession = nil
        }
        if let deactivationDate = requestedSession?.deactivationDate {
            deactivation = scheduleDeactivation(at: deactivationDate)
        }
        logWaitingForPowerChange()

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
                let endCause = getEndCause(of: session)
                let didRestoreSleep = await session.end()
                if !didRestoreSleep {
                    if session === getEligibleSession() {
                        Logger.keepAwake.notice("Session kept: restoring sleep was refused and the session is eligible again")
                        continue
                    }

                    Logger.keepAwake.notice("Session kept: restoring sleep was refused while ending it (\(endCause.rawValue, privacy: .public)); retrying in \(Int(Self.sleepRestorationRetryInterval)) s")
                    isSleepRestorationRefused = true
                    sleepRestorationRetry = scheduleSleepRestorationRetry()
                    return
                }

                self.session = nil
                isSleepRestorationRefused = false
                setMenuBarSymbol(nil)
                Logger.keepAwake.notice("Session ended: \(endCause.rawValue, privacy: .public)")
                if session.keepsAwakeWithLidClosed { didRestoreLidClosedSleep = true }
                continue
            }

            let nextSession = eligibleSession!
            let didBegin = await nextSession.begin()
            if !didBegin {
                Logger.keepAwake.notice("Session refused: lid-closed sleep could not be disabled")
                isPmsetRefused = true
                if requestedSession === nextSession { dropRequest(because: .activationRefused) }
                continue
            }

            session = nextSession
            isPmsetRefused = false
            setMenuBarSymbol(keepAwakeSymbolName)
            Logger.keepAwake.notice("Session began: auto-off \(nextSession.autoOff.rawValue, privacy: .public), keeps awake with the lid closed \(nextSession.keepsAwakeWithLidClosed, privacy: .public)")
        }
    }

    /// Sleeps the Mac as macOS would have once a session stops holding a closed lid awake, since macOS does not re-check a closed lid when sleep is restored. Skipped:
    ///
    /// - when the next session keeps the lid awake;
    /// - when macOS's own verdict keeps a closed lid awake, such as an external display on AC power (closed-display mode);
    /// - on Quit, so a log out, restart or shut down never becomes a sleep.
    @MainActor private func sleepIfClosedLidIsLeftAwake() {
        if isTerminating {
            Logger.keepAwake.notice("Not putting the Mac to sleep after the lid-closed session: quitting")
            return
        }
        if session?.keepsAwakeWithLidClosed == true {
            Logger.keepAwake.notice("Not putting the Mac to sleep after the lid-closed session: the next session keeps the lid awake")
            return
        }
        if !powerManagement.isClosedLidCausingSleep() {
            Logger.keepAwake.notice("Not putting the Mac to sleep after the lid-closed session: the lid is open or a closed lid does not sleep the Mac")
            return
        }

        Logger.keepAwake.notice("Putting the Mac to sleep: the lid-closed session ended and macOS would sleep the Mac with the lid closed")
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

    /// Drops the request and from then on ignores toggles, duration chips and condition changes, so no session starts during Quit and the
    /// session Quit ends never sleeps the Mac, however long the other features take to clean up.
    private func beginTerminating() {
        isTerminating = true
        dropRequest(because: .quit)
    }

    /// Drops the request. The cause is recorded only when there was a request, so a session still restoring sleep keeps the cause it ended for.
    private func dropRequest(because cause: KeepAwakeEndCause) {
        if requestedSession != nil { requestDropCause = cause }
        requestedSession = nil
        updateSession()
    }

    /// Why the published session is no longer the eligible one.
    private func getEndCause(of session: KeepAwakeSession) -> KeepAwakeEndCause {
        guard let requestedSession else { return requestDropCause! }
        if requestedSession !== session { return .replaced }
        if isRequestedSessionExpired() { return .deadlineReached }
        return .notConnectedToPower
    }

    private func logRequestedSession(from source: KeepAwakeRequestSource) {
        let session = requestedSession!
        Logger.keepAwake.notice("Session requested from \(source.rawValue, privacy: .public): auto-off \(session.autoOff.rawValue, privacy: .public), keeps awake with the lid closed \(session.keepsAwakeWithLidClosed, privacy: .public), only while connected to power \(self.preferences.onlyWhileConnectedToPower, privacy: .public)")
    }

    private func logWaitingForPowerChange() {
        let isWaiting = isWaitingForPower
        if isWaiting == wasWaitingForPower { return }

        wasWaitingForPower = isWaiting
        if isWaiting {
            Logger.keepAwake.notice("Waiting for power: the session is held back while not connected to power")
        } else {
            Logger.keepAwake.notice("No longer waiting for power")
        }
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
        let deactivation = DispatchWorkItem { [unowned self] in dropRequest(because: .deadlineReached) }
        clock.schedule(deactivation, at: date)
        return deactivation
    }

    private func scheduleSleepRestorationRetry() -> DispatchWorkItem {
        let retry = DispatchWorkItem { [unowned self] in
            Logger.keepAwake.notice("Retrying to restore sleep")
            updateSession()
        }
        clock.schedule(retry, at: clock.now().addingTimeInterval(Self.sleepRestorationRetryInterval))
        return retry
    }
}
