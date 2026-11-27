import Foundation
import Testing
@testable import MacUtilities

/// "Only while connected to power": suspending on battery, resuming on power, and power changes during commands.
@MainActor
struct KeepAwakePowerTests {
    private let sleepRestorationRetryInterval: TimeInterval = 5

    @Test(arguments: [true, false])
    func unpluggingSuspendsTheSessionAndReconnectingResumesIt(keepsLidAwake: Bool) async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setOnlyWhileConnectedToPower(true)
        harness.preferences.setKeepsAwakeWithLidClosed(keepsLidAwake)
        let feature = harness.buildFeature()

        feature.turnOn(for: .oneHour)
        if keepsLidAwake { try await harness.completeCommand(disabled: true) }
        try await harness.waitUntil { feature.session != nil }
        let session = try #require(feature.session)
        let deadline = session.deactivationDate

        power.setExternalPowerConnected(false)
        if keepsLidAwake { try await harness.completeCommand(disabled: false) }
        try await harness.waitUntil { feature.session == nil }
        #expect(feature.isWaitingForPower, "Unplugging lost the user's enabled session")
        #expect(power.assertionReleaseCount == 1, "Unplugging did not release the power assertion")
        #expect(power.watchdogTerminationCount == (keepsLidAwake ? 1 : 0), "Unplugging did not stop the restored watchdog")

        power.setExternalPowerConnected(true)
        if keepsLidAwake { try await harness.completeCommand(disabled: true) }
        try await harness.waitUntil { feature.session != nil }
        #expect(feature.session === session, "Reconnecting replaced the suspended session")
        #expect(feature.session?.deactivationDate == deadline, "Reconnecting restarted the deadline")
        #expect(!feature.isWaitingForPower, "Reconnecting kept the waiting subtitle")

        feature.stop(because: .switchedOff)
        if keepsLidAwake { try await harness.completeCommand(disabled: false) }
        try await harness.waitUntil { feature.session == nil }
        #expect(power.assertionReleaseCount == 2, "The resumed assertion was not released")
        if keepsLidAwake {
            #expect(power.commandHistory == [true, false, true, false], "Power changes did not serialize lid commands")
            return
        }
        #expect(power.commandHistory.isEmpty, "Idle-sleep power changes ran lid commands")
    }

    @Test(arguments: [false, true])
    func turningOnOnBatteryWaitsForPower(usesDurationChip: Bool) async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setOnlyWhileConnectedToPower(true)
        let feature = harness.buildFeature()
        power.setExternalPowerConnected(false)

        if usesDurationChip {
            feature.turnOn(for: .oneHour)
        } else {
            feature.toggle(from: .popoverToggle)
        }
        #expect(feature.isWaitingForPower, "Battery activation did not retain the user's enablement")
        await Task.yield()
        #expect(feature.session == nil, "Keep Awake activated on battery")
        #expect(power.commandHistory.isEmpty, "Battery activation disabled lid sleep")
        #expect(power.watchdogLaunchCount == 0, "Battery activation launched a watchdog")

        power.setExternalPowerConnected(true)
        try await harness.completeCommand(disabled: true)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(feature.session != nil, "Reconnecting did not honor battery enablement")
        if usesDurationChip {
            #expect(feature.session?.autoOff == .oneHour, "The battery duration chip lost its duration")
        }
    }

    @Test(arguments: [false, true])
    func turningOffWhileWaitingForPowerKeepsItOffOnReconnect(stopsFeature: Bool) async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setOnlyWhileConnectedToPower(true)
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        power.setExternalPowerConnected(false)
        try await harness.completeCommand(disabled: false)
        try await harness.waitUntil { !feature.isChangingSession }

        if stopsFeature {
            feature.stop(because: .switchedOff)
            feature.start()
        } else {
            feature.toggle(from: .popoverToggle)
        }
        #expect(!feature.isWaitingForPower, "Turning off retained suspended enablement")

        power.setExternalPowerConnected(true)
        try await harness.letMainQueueRun()
        #expect(feature.session == nil, "Reconnecting enabled a manually disabled session")
        #expect(power.commandHistory == [true, false], "Reconnecting ran commands for a disabled session")
    }

    @Test
    func sessionThatExpiredOnBatteryStaysOffOnReconnect() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setOnlyWhileConnectedToPower(true)
        harness.preferences.setAutoOff(.thirtyMinutes)
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        power.setExternalPowerConnected(false)
        try await harness.completeCommand(disabled: false)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(feature.isWaitingForPower)

        harness.clock.advance(by: 30 * 60)
        #expect(!feature.isWaitingForPower, "An expired session still waited for power")

        power.setExternalPowerConnected(true)
        try await harness.letMainQueueRun()
        #expect(feature.session == nil, "Reconnecting restarted an expired session")
        #expect(power.commandHistory == [true, false], "Reconnecting disabled sleep after expiration")
    }

    @Test
    func powerOptionAppliesImmediatelyToAnActiveSession() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let feature = harness.buildFeature()
        power.setExternalPowerConnected(false)
        try await harness.activate(feature)
        let session = feature.session

        harness.preferences.setOnlyWhileConnectedToPower(true)
        try await harness.completeCommand(disabled: false)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "Enabling the power option did not restore sleep on battery")
        #expect(feature.isWaitingForPower, "Enabling the power option lost user enablement")

        harness.preferences.setOnlyWhileConnectedToPower(false)
        try await harness.completeCommand(disabled: true)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(feature.session === session, "Disabling the power option replaced the session")
        #expect(!feature.isWaitingForPower, "Disabling the power option left battery gating active")
    }

    @Test
    func unpluggingDuringActivationRestoresSleepAfterTheActivationFinishes() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setOnlyWhileConnectedToPower(true)
        let feature = harness.buildFeature()
        feature.turnOn(for: .oneHour)
        try await harness.waitUntil { power.pendingCommands.count == 1 }

        power.setExternalPowerConnected(false)
        try await harness.completeCommand(disabled: true)
        try await harness.completeCommand(disabled: false)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "Unplugging retained an in-flight activation")
        #expect(feature.isWaitingForPower, "Unplugging discarded in-flight enablement")
        #expect(power.commandHistory == [true, false], "Unplugging overlapped activation and restoration")
        #expect(power.assertionReleaseCount == 1, "Unplugging leaked the late activation's assertion")
        #expect(power.watchdogTerminationCount == 1, "Unplugging orphaned the late activation's watchdog")
    }

    @Test
    func reconnectingDuringRestorationResumesTheSameSession() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setOnlyWhileConnectedToPower(true)
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        let session = feature.session
        power.setExternalPowerConnected(false)
        try await harness.waitUntil { power.pendingCommands.count == 1 }

        power.setExternalPowerConnected(true)
        try await harness.completeCommand(disabled: false)
        try await harness.completeCommand(disabled: true)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(feature.session === session, "Reconnecting during restoration lost the enabled session")
        #expect(power.commandHistory == [true, false, true], "Reconnecting during restoration overlapped power commands")
    }

    @Test
    func unpluggingRetriesFailedRestorationWithoutActivatingOnBattery() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setOnlyWhileConnectedToPower(true)
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        power.setExternalPowerConnected(false)
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(feature.isSleepRestorationRefused, "Unplugging hid restoration failure")
        #expect(power.assertionReleaseCount == 0, "Unplugging released an unrestored assertion")
        #expect(power.watchdogTerminationCount == 0, "Unplugging abandoned failed cleanup")

        harness.clock.advance(by: sleepRestorationRetryInterval)
        try await harness.completeCommand(disabled: false)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "Unplugging did not retry failed cleanup")
        #expect(feature.isWaitingForPower, "Cleanup retry discarded suspended enablement")
        #expect(power.commandHistory == [true, false, false], "Cleanup retry activated on battery")
    }

    /// Power is allowed again, by reconnecting or by turning the power option off, after or while restoration fails.
    @Test(arguments: [
        (reconnectsPower: true, beforeRestorationFails: false),
        (reconnectsPower: true, beforeRestorationFails: true),
        (reconnectsPower: false, beforeRestorationFails: false),
        (reconnectsPower: false, beforeRestorationFails: true),
    ])
    func allowingPowerAgainKeepsTheSessionWhoseRestorationFailed(reconnectsPower: Bool, beforeRestorationFails: Bool) async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setOnlyWhileConnectedToPower(true)
        harness.preferences.setAutoOff(.oneHour)
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        let session = feature.session
        let deadline = session?.deactivationDate

        power.setExternalPowerConnected(false)
        try await harness.waitUntil { power.pendingCommands.count == 1 }
        if !beforeRestorationFails {
            try await harness.completeCommand(disabled: false, succeeds: false)
            try await harness.waitUntil { !feature.isChangingSession }
            #expect(feature.isSleepRestorationRefused, "Failed restoration did not report its warning")
        }

        if reconnectsPower {
            power.setExternalPowerConnected(true)
        } else {
            harness.preferences.setOnlyWhileConnectedToPower(false)
        }
        if beforeRestorationFails {
            try await harness.completeCommand(disabled: false, succeeds: false)
        }
        try await harness.letMainQueueRun()
        try await harness.waitUntil { !feature.isChangingSession }

        #expect(feature.session === session, "Allowing power replaced the already active session")
        #expect(feature.session?.deactivationDate == deadline, "Allowing power restarted the deadline")
        #expect(!feature.isSleepRestorationRefused, "An eligible session retained an obsolete restoration warning")
        #expect(!feature.isWaitingForPower, "An eligible session still claimed it was waiting for power")
        #expect(power.assertionReleaseCount == 0, "Failed restoration released the eligible session's assertion")
        #expect(power.watchdogTerminationCount == 0, "Failed restoration stopped the eligible session's watchdog")

        harness.clock.advance(by: sleepRestorationRetryInterval)
        try await harness.letMainQueueRun()
        #expect(power.commandHistory == [true, false], "An eligible session retried obsolete restoration")
    }
}
