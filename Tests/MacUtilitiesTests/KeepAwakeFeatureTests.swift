import Foundation
import Testing
@testable import MacUtilities

/// Turning on and off, failed commands, retries and Quit.
@MainActor
struct KeepAwakeFeatureTests {
    private let sleepRestorationRetryInterval: TimeInterval = 5

    @Test
    func refusedActivationHoldsNothingAndShowsTheWarning() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()

        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: true, succeeds: false)
        try await waitUntil { !feature.isChangingSession }

        #expect(feature.session == nil, "A refused activation retained a session")
        #expect(feature.isPmsetRefused, "A refused activation did not expose its failure")
        #expect(!feature.isSleepRestorationRefused, "A refused activation claimed restoration failed")
        #expect(power.watchdogTerminationCount == 1, "A refused activation did not stop its unused watchdog")
        #expect(power.heldAssertionTypes.isEmpty, "A refused activation acquired a power assertion")
        #expect(harness.menuBarSymbolChangeCount == 0, "A refused activation changed the icon")
    }

    @Test
    func toggleRetriesFailedRestorationAndCancelsTheTimedRetry() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        let session = feature.session

        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session === session, "Failed toggle discarded the active session")
        #expect(feature.isSleepRestorationRefused, "Failed toggle did not expose restoration failure")
        #expect(harness.menuBarSymbol == keepAwakeSymbolName, "Failed toggle reported an off icon")

        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "A successful retry did not clear the session")
        #expect(!feature.isSleepRestorationRefused, "A successful retry kept the warning")
        #expect(harness.menuBarSymbol == nil, "A successful retry kept the active icon")

        harness.clock.advance(by: sleepRestorationRetryInterval)
        await letMainQueueRun()
        #expect(power.commandHistory == [true, false, false], "A canceled retry ran after the session ended")
    }

    @Test
    func durationChipWaitsForRefusedRestorationThenAppliesTheLatestDuration() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        let session = feature.session

        feature.turnOn(for: .oneHour)
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session === session, "A duration chip replaced an unrestored session")
        #expect(feature.isSleepRestorationRefused, "A duration chip hid restoration failure")
        #expect(power.commandHistory == [true, false], "A duration chip disabled sleep before restoration")
        #expect(power.watchdogLaunchCount == 1, "A duration chip orphaned the previous watchdog")

        harness.clock.advance(by: sleepRestorationRetryInterval)
        try await harness.completeCommand(disabled: false)
        try await harness.completeCommand(disabled: true)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session?.autoOff == .oneHour, "The latest duration was lost during restoration retry")
        #expect(feature.session !== session, "The previous session was reused after restoration")
        #expect(power.watchdogTerminationCount == 1, "The restored session's watchdog was not stopped")
    }

    @Test
    func stoppingTheFeatureKeepsRetryingFailedRestoration() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        let session = feature.session

        feature.stop(because: .switchedOff)
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session === session, "Stopping the feature discarded failed cleanup")
        #expect(harness.menuBarSymbol == keepAwakeSymbolName, "Stopping the feature hid failed cleanup")
        #expect(power.watchdogTerminationCount == 0, "Stopping the feature orphaned crash recovery")

        harness.clock.advance(by: sleepRestorationRetryInterval)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "Stopping the feature canceled automatic cleanup retries")
        #expect(power.commandHistory == [true, false, false], "Stopping did not retry restoration once")
        #expect(harness.menuBarSymbol == nil, "Successful cleanup after stopping kept the active icon")
    }

    @Test
    func expiredTimerRetriesFailedRestoration() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setAutoOff(.thirtyMinutes)
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        let session = feature.session

        harness.clock.advance(by: 30 * 60)
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session === session, "An expired timer discarded failed cleanup")
        #expect(feature.isSleepRestorationRefused, "An expired timer hid failed cleanup")
        #expect(power.assertionReleaseCount == 0, "An expired timer released an unrestored session")

        harness.clock.advance(by: sleepRestorationRetryInterval)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "An expired timer did not retry restoration")
        #expect(power.commandHistory == [true, false, false], "An expired timer did not retry once")
    }

    @Test
    func stoppingDuringActivationRestoresSleepAfterTheActivationFinishes() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()

        feature.toggle(from: .popoverToggle)
        try await waitUntil { power.pendingCommands.count == 1 }
        #expect(feature.session == nil, "An unfinished activation was presented as active")
        #expect(feature.isChangingSession, "Pending activation did not expose progress")
        #expect(power.watchdogLaunchCount == 1, "Pending activation had no crash watchdog")

        var mainQueueProgressed = false
        DispatchQueue.main.async { mainQueueProgressed = true }
        try await waitUntil { mainQueueProgressed }
        #expect(power.pendingCommands.count == 1, "Main loop progress completed an unfinished power command")

        feature.stop(because: .switchedOff)
        try await harness.completeCommand(disabled: true)
        try await waitUntil { power.pendingCommands.count == 1 }
        #expect(feature.session != nil, "Stopping dropped a successful in-flight disable")
        #expect(power.watchdogTerminationCount == 0, "Stopping killed the watchdog before restoring sleep")

        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "Stopping did not restore in-flight activation")
        #expect(power.commandHistory == [true, false], "Stopping restored sleep out of order")
    }

    @Test
    func rapidTogglesRunOneCommandAtATimeAndKeepTheLastIntent() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()

        feature.toggle(from: .popoverToggle)
        try await waitUntil { power.pendingCommands.count == 1 }
        feature.toggle(from: .popoverToggle)
        feature.toggle(from: .popoverToggle)
        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: true)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "The final off intent was lost")
        #expect(power.commandHistory == [true, false], "Rapid toggles ran overlapping or redundant commands")

        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: true)
        try await waitUntil { !feature.isChangingSession }
        feature.toggle(from: .popoverToggle)
        try await waitUntil { power.pendingCommands.count == 1 }
        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: false)
        try await harness.completeCommand(disabled: true)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session != nil, "An on intent during restoration was lost")
    }

    @Test
    func rapidDurationChipsApplyTheLatestDurationWithThePreferencesReadWhenClicked() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()

        feature.turnOn(for: .oneHour)
        try await waitUntil { power.pendingCommands.count == 1 }
        feature.turnOn(for: .thirtyMinutes)
        feature.turnOn(for: .untilTurnedOff)
        harness.preferences.setKeepsAwakeWithLidClosed(false)
        try await harness.completeCommand(disabled: true)
        try await harness.completeCommand(disabled: false)
        try await harness.completeCommand(disabled: true)
        try await waitUntil { !feature.isChangingSession }

        #expect(feature.session?.autoOff == .untilTurnedOff, "The latest duration was not applied")
        #expect(power.commandHistory == [true, false, true], "Replacement commands overlapped or used live preferences")
        #expect(power.assertionReleaseCount == 1, "The replaced session's assertion was not released")
        #expect(power.watchdogTerminationCount == 1, "The replaced session's watchdog was not stopped")
    }

    @Test(arguments: [false, true])
    func terminationFinishesActivationThenRestoresSleep(refusesRestoration: Bool) async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()

        feature.toggle(from: .popoverToggle)
        try await waitUntil { power.pendingCommands.count == 1 }
        var didFinishTermination = false
        Task { @MainActor in
            await feature.prepareForTermination()
            didFinishTermination = true
        }
        await letMainQueueRun()
        #expect(!didFinishTermination, "Termination abandoned an in-flight activation")

        feature.turnOn(for: .oneHour)
        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: true)
        try await waitUntil { power.pendingCommands.count == 1 }
        #expect(!didFinishTermination, "Termination finished before restoration completed")
        try await harness.completeCommand(disabled: false, succeeds: !refusesRestoration)
        try await waitUntil { didFinishTermination }
        #expect(power.commandHistory == [true, false], "Termination accepted a new activation or overlapped commands")

        if refusesRestoration {
            #expect(feature.session != nil, "Termination dropped failed restoration ownership")
            #expect(feature.isSleepRestorationRefused, "Termination hid restoration failure")
            #expect(power.watchdogTerminationCount == 0, "Termination killed the cleanup watchdog")
            #expect(power.assertionReleaseCount == 0, "Termination released an unrestored assertion")

            harness.clock.advance(by: sleepRestorationRetryInterval)
            await letMainQueueRun()
            #expect(power.commandHistory == [true, false], "The app retried after handing cleanup to the watchdog")
            return
        }
        #expect(feature.session == nil, "Termination failed to clear a restored session")
        #expect(power.watchdogTerminationCount == 1, "Termination did not stop the restored watchdog")
    }

    @Test
    func terminationWaitsForAnInFlightRestoration() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        feature.stop(because: .quit)
        try await waitUntil { power.pendingCommands.count == 1 }
        var didFinishTermination = false
        Task { @MainActor in
            await feature.prepareForTermination()
            didFinishTermination = true
        }
        await letMainQueueRun()
        #expect(!didFinishTermination, "Termination discarded an in-flight restore")

        try await harness.completeCommand(disabled: false)
        try await waitUntil { didFinishTermination }
        #expect(power.commandHistory == [true, false], "Termination ran overlapping restoration commands")
    }

    /// Between AppController stopping the feature and its cleanup starting, the popover tile can still be clicked.
    @Test
    func togglesBetweenStopAndCleanupOnQuitAreIgnored() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()

        feature.stop(because: .quit)
        feature.toggle(from: .popoverToggle)
        feature.turnOn(for: .oneHour)
        await letMainQueueRun()
        try #require(power.commandHistory.isEmpty, "A toggle during Quit ran a power command")
        #expect(feature.session == nil, "A toggle during Quit started a session")
        #expect(!feature.isChangingSession, "A toggle during Quit started a transition")

        // Cleanup would wait forever on a command nobody completes, so the wait also ends when one appears.
        var didFinishCleanup = false
        Task { @MainActor in
            await feature.prepareForTermination()
            didFinishCleanup = true
        }
        try await waitUntil { didFinishCleanup || !power.pendingCommands.isEmpty }
        #expect(power.commandHistory.isEmpty, "Quit ran a power command")
    }

    /// Quit handed a failed restoration to the watchdog; unplugging or changing a preference afterwards must not try again.
    @Test(arguments: [false, true])
    func conditionChangesAfterQuitRunNoCommand(changesPreference: Bool) async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        let termination = Task { await feature.prepareForTermination() }
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await waitForResult(of: termination)

        if changesPreference {
            harness.preferences.setOnlyWhileConnectedToPower(true)
        } else {
            power.setExternalPowerConnected(false)
        }
        await letMainQueueRun()
        #expect(power.commandHistory == [true, false], "A condition change after Quit ran a power command")
    }
}
