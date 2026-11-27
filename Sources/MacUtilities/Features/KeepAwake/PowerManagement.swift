import Foundation
import IOKit.pwr_mgt

/// The macOS power management Keep Awake drives: what holds sleep off, what restores it, and the power and lid state that decide whether it should.
protocol PowerManagement {
    /// Holds an IOKit power assertion of the given kIOPMAssertionType until releaseAssertion.
    func createAssertion(type: String) -> IOPMAssertionID
    func releaseAssertion(_ id: IOPMAssertionID)

    /// pmset -a disablesleep, so a closed lid does not sleep the Mac. False when sudo refuses it.
    @MainActor func setLidClosedSleepDisabled(_ disabled: Bool) async -> Bool
    /// Starts a process that restores lid-closed sleep once the app has exited, however it exits.
    func launchLidClosedSleepWatchdog() -> Process
    func terminateLidClosedSleepWatchdog(_ watchdog: Process)

    /// True when the lid is closed and macOS's own verdict is that a closed lid sleeps the Mac.
    func isClosedLidCausingSleep() -> Bool
    func sleepMac()

    func isConnectedToExternalPower() -> Bool
    /// Calls onChange on the main thread whenever the power source changes.
    func startObservingExternalPower(_ onChange: @escaping () -> Void)
}
