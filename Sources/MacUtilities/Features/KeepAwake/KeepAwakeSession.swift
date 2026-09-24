import Foundation
import IOKit.pwr_mgt

/// One stretch of keeping the Mac awake, from init until end(): the power assertion, lid-closed sleep disabled when the preference says so, and when it ends on its own. nil when sudo refuses pmset; nothing is left held then.
final class KeepAwakeSession {
    /// nil when the session runs until turned off.
    let deactivationDate: Date?

    private let assertion: PowerAssertion
    private let lidClosedSleepWatchdog: Process?

    init?(preferences: KeepAwakePreferences) {
        deactivationDate = preferences.autoOff.duration.map { Date(timeIntervalSinceNow: $0) }

        if !preferences.keepsAwakeWithLidClosed {
            assertion = PowerAssertion(type: kIOPMAssertionTypePreventUserIdleSystemSleep as String)
            lidClosedSleepWatchdog = nil
            return
        }

        let watchdog = launchLidClosedSleepWatchdog()
        if !setLidClosedSleepDisabled(true) {
            watchdog.terminate()
            return nil
        }

        assertion = PowerAssertion(type: kIOPMAssertionTypePreventUserIdleDisplaySleep as String)
        lidClosedSleepWatchdog = watchdog
    }

    func end() {
        assertion.release()

        guard let lidClosedSleepWatchdog else { return }
        lidClosedSleepWatchdog.terminate()
        setLidClosedSleepDisabled(false)
    }
}
