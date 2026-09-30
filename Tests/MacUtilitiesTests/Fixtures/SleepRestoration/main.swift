import AppKit
import Combine
import Foundation
import SwiftUI

var assertionReleaseCount = 0
var watchdogLaunchCount = 0
var watchdogTerminationCount = 0
var commands: [PendingSleepCommand] = []
var commandHistory: [Bool] = []

final class PendingSleepCommand {
    let disabled: Bool
    let continuation: CheckedContinuation<Bool, Never>

    init(disabled: Bool, continuation: CheckedContinuation<Bool, Never>) {
        self.disabled = disabled
        self.continuation = continuation
    }
}

final class Process {
    func terminate() {
        watchdogTerminationCount += 1
    }
}

final class PowerAssertion {
    init(type: String) {}

    func release() {
        assertionReleaseCount += 1
    }
}

@MainActor func setLidClosedSleepDisabled(_ disabled: Bool) async -> Bool {
    return await withCheckedContinuation { continuation in
        commandHistory.append(disabled)
        commands.append(PendingSleepCommand(disabled: disabled, continuation: continuation))
    }
}

func launchLidClosedSleepWatchdog() -> Process {
    watchdogLaunchCount += 1
    return Process()
}

enum KeepAwakeAutoOff: String {
    case thirtyMinutes
    case oneHour
    case untilTurnedOff

    var duration: TimeInterval? {
        if self == .untilTurnedOff { return nil }
        if self == .oneHour { return 60 }
        return 0.05
    }
}

final class KeepAwakePreferences: ObservableObject {
    static var autoOff: KeepAwakeAutoOff = .untilTurnedOff
    static var keepsAwakeWithLidClosed = true
    static var onlyWhileConnectedToPower = false
    static var current: KeepAwakePreferences!

    init() {
        Self.current = self
    }

    var autoOff: KeepAwakeAutoOff { Self.autoOff }
    var keepsAwakeWithLidClosed: Bool { Self.keepsAwakeWithLidClosed }
    var onlyWhileConnectedToPower: Bool { Self.onlyWhileConnectedToPower }

    func setAutoOff(_ autoOff: KeepAwakeAutoOff) {
        objectWillChange.send()
        Self.autoOff = autoOff
    }

    func setOnlyWhileConnectedToPower(_ enabled: Bool) {
        objectWillChange.send()
        Self.onlyWhileConnectedToPower = enabled
    }
}

final class ExternalPowerSource: ObservableObject {
    static var current: ExternalPowerSource!

    @Published var isConnected = true

    init() {
        Self.current = self
    }
}

struct KeepAwakeSettingsView: View {
    let preferences: KeepAwakePreferences
    var body: some View { EmptyView() }
}

struct KeepAwakeTile: View {
    let feature: KeepAwakeFeature
    let preferences: KeepAwakePreferences
    var body: some View { EmptyView() }
}

func require(_ condition: Bool, _ message: String) {
    if condition { return }
    fatalError(message)
}

@MainActor func waitUntil(_ condition: () -> Bool) async {
    let deadline = Date(timeIntervalSinceNow: 8)
    while !condition() {
        require(Date() < deadline, "Timed out waiting for a transition")
        try! await Task.sleep(nanoseconds: 1_000_000)
    }
}

@MainActor func completeCommand(disabled: Bool, succeeds: Bool = true) async {
    await waitUntil { !commands.isEmpty }
    let command = commands.removeFirst()
    require(command.disabled == disabled, "Power commands ran out of order")
    command.continuation.resume(returning: succeeds)
}

@MainActor func buildFeature() -> KeepAwakeFeature {
    return KeepAwakeFeature(setMenuBarSymbol: { _ in
        require(Thread.isMainThread, "The menu bar icon changed off the main thread")
    })
}

@MainActor func activate(_ feature: KeepAwakeFeature) async {
    feature.toggle()
    await completeCommand(disabled: true)
    await waitUntil { !feature.isChangingSession }
    require(feature.session != nil, "Successful activation did not publish a session")
}

@MainActor func testSessionRetry() async {
    let session = KeepAwakeSession(preferences: KeepAwakePreferences())
    let begin = Task { await session.begin() }
    await completeCommand(disabled: true)
    require(await begin.value, "Session activation failed")

    let failure = Task { await session.end() }
    await completeCommand(disabled: false, succeeds: false)
    require(!(await failure.value), "Failed restoration must report failure")
    require(assertionReleaseCount == 0, "Failed restoration released the assertion")
    require(watchdogTerminationCount == 0, "Failed restoration stopped the watchdog")

    let retry = Task { await session.end() }
    await completeCommand(disabled: false)
    require(await retry.value, "The next restoration should succeed")
    require(assertionReleaseCount == 1, "Successful restoration did not release the assertion once")
    require(watchdogTerminationCount == 1, "Successful restoration did not stop the watchdog once")
}

@MainActor func testIdleSleepSession() async {
    KeepAwakePreferences.keepsAwakeWithLidClosed = false
    let session = KeepAwakeSession(preferences: KeepAwakePreferences())
    require(await session.begin(), "An idle-sleep session should activate")
    require(await session.end(), "An idle-sleep session should end successfully")
    require(commandHistory.isEmpty, "An idle-sleep session changed lid sleep")
    require(watchdogLaunchCount == 0, "An idle-sleep session launched a watchdog")
    require(assertionReleaseCount == 1, "An idle-sleep session did not release its assertion")
}

@MainActor func testActivationRefusal() async {
    let feature = KeepAwakeFeature(setMenuBarSymbol: { _ in fatalError("A refused activation changed the icon") })
    feature.toggle()
    await completeCommand(disabled: true, succeeds: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "A refused activation retained a session")
    require(feature.isPmsetRefused, "A refused activation did not expose its failure")
    require(!feature.isSleepRestorationRefused, "A refused activation claimed restoration failed")
    require(watchdogTerminationCount == 1, "A refused activation did not stop its unused watchdog")
    require(assertionReleaseCount == 0, "A refused activation acquired a power assertion")
}

@MainActor func testToggleRetry() async {
    var symbol: String?
    let feature = KeepAwakeFeature(setMenuBarSymbol: { symbol = $0 })
    await activate(feature)
    let session = feature.session!

    feature.toggle()
    await completeCommand(disabled: false, succeeds: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session === session, "Failed toggle discarded the active session")
    require(feature.isSleepRestorationRefused, "Failed toggle did not expose restoration failure")
    require(symbol == keepAwakeSymbolName, "Failed toggle reported an off icon")

    feature.toggle()
    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "A successful retry did not clear the session")
    require(!feature.isSleepRestorationRefused, "A successful retry kept the warning")
    require(symbol == nil, "A successful retry kept the active icon")
    try! await Task.sleep(nanoseconds: 5_200_000_000)
    require(commandHistory == [true, false, false], "A canceled retry ran after the session ended")
}

@MainActor func testReplacementRefusal() async {
    let feature = buildFeature()
    await activate(feature)
    let session = feature.session!

    feature.turnOn(for: .oneHour)
    await completeCommand(disabled: false, succeeds: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session === session, "A duration chip replaced an unrestored session")
    require(feature.isSleepRestorationRefused, "A duration chip hid restoration failure")
    require(commandHistory == [true, false], "A duration chip disabled sleep before restoration")
    require(watchdogLaunchCount == 1, "A duration chip orphaned the previous watchdog")

    await completeCommand(disabled: false)
    await completeCommand(disabled: true)
    await waitUntil { !feature.isChangingSession }
    require(feature.session?.autoOff == .oneHour, "The latest duration was lost during restoration retry")
    require(feature.session !== session, "The previous session was reused after restoration")
    require(watchdogTerminationCount == 1, "The restored session's watchdog was not stopped")
}

@MainActor func testStopRetry() async {
    var symbol: String?
    let feature = KeepAwakeFeature(setMenuBarSymbol: { symbol = $0 })
    await activate(feature)
    let session = feature.session!

    feature.stop()
    await completeCommand(disabled: false, succeeds: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session === session, "Stopping the feature discarded failed cleanup")
    require(symbol == keepAwakeSymbolName, "Stopping the feature hid failed cleanup")
    require(watchdogTerminationCount == 0, "Stopping the feature orphaned crash recovery")

    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "Stopping the feature canceled automatic cleanup retries")
    require(commandHistory == [true, false, false], "Stopping did not retry restoration once")
    require(symbol == nil, "Successful cleanup after stopping kept the active icon")
}

@MainActor func testTimerRetry() async {
    KeepAwakePreferences.autoOff = .thirtyMinutes
    let feature = buildFeature()
    await activate(feature)
    let session = feature.session!

    await completeCommand(disabled: false, succeeds: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session === session, "An expired timer discarded failed cleanup")
    require(feature.isSleepRestorationRefused, "An expired timer hid failed cleanup")
    require(assertionReleaseCount == 0, "An expired timer released an unrestored session")

    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "An expired timer did not retry restoration")
    require(commandHistory == [true, false, false], "An expired timer did not retry once")
}

@MainActor func testPendingActivationStop() async {
    let feature = buildFeature()
    feature.toggle()
    await waitUntil { commands.count == 1 }
    require(feature.session == nil, "An unfinished activation was presented as active")
    require(feature.isChangingSession, "Pending activation did not expose progress")
    require(watchdogLaunchCount == 1, "Pending activation had no crash watchdog")

    var mainQueueProgressed = false
    DispatchQueue.main.async { mainQueueProgressed = true }
    await waitUntil { mainQueueProgressed }
    require(commands.count == 1, "Main loop progress completed an unfinished power command")
    feature.stop()
    await completeCommand(disabled: true)
    await waitUntil { commands.count == 1 }
    require(feature.session != nil, "Stopping dropped a successful in-flight disable")
    require(watchdogTerminationCount == 0, "Stopping killed the watchdog before restoring sleep")
    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "Stopping did not restore in-flight activation")
    require(commandHistory == [true, false], "Stopping restored sleep out of order")
}

@MainActor func testRapidToggles() async {
    let feature = buildFeature()
    feature.toggle()
    await waitUntil { commands.count == 1 }
    feature.toggle()
    feature.toggle()
    feature.toggle()
    await completeCommand(disabled: true)
    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "The final off intent was lost")
    require(commandHistory == [true, false], "Rapid toggles ran overlapping or redundant commands")

    feature.toggle()
    await completeCommand(disabled: true)
    await waitUntil { !feature.isChangingSession }
    feature.toggle()
    await waitUntil { commands.count == 1 }
    feature.toggle()
    await completeCommand(disabled: false)
    await completeCommand(disabled: true)
    await waitUntil { !feature.isChangingSession }
    require(feature.session != nil, "An on intent during restoration was lost")
}

@MainActor func testRapidDurationReplacement() async {
    let feature = buildFeature()
    feature.turnOn(for: .oneHour)
    await waitUntil { commands.count == 1 }
    feature.turnOn(for: .thirtyMinutes)
    feature.turnOn(for: .untilTurnedOff)
    KeepAwakePreferences.keepsAwakeWithLidClosed = false
    await completeCommand(disabled: true)
    await completeCommand(disabled: false)
    await completeCommand(disabled: true)
    await waitUntil { !feature.isChangingSession }
    require(feature.session?.autoOff == .untilTurnedOff, "The latest duration was not applied")
    require(commandHistory == [true, false, true], "Replacement commands overlapped or used live preferences")
    require(assertionReleaseCount == 1, "The replaced session's assertion was not released")
    require(watchdogTerminationCount == 1, "The replaced session's watchdog was not stopped")
}

@MainActor func testTermination(_ refusesRestoration: Bool) async {
    let feature = buildFeature()
    feature.toggle()
    await waitUntil { commands.count == 1 }
    var didFinishTermination = false
    Task { @MainActor in
        await feature.prepareForTermination()
        didFinishTermination = true
    }
    await Task.yield()
    require(!didFinishTermination, "Termination abandoned an in-flight activation")
    feature.turnOn(for: .oneHour)
    feature.toggle()
    await completeCommand(disabled: true)
    await waitUntil { commands.count == 1 }
    require(!didFinishTermination, "Termination finished before restoration completed")
    await completeCommand(disabled: false, succeeds: !refusesRestoration)
    await waitUntil { didFinishTermination }
    require(commandHistory == [true, false], "Termination accepted a new activation or overlapped commands")

    if refusesRestoration {
        require(feature.session != nil, "Termination dropped failed restoration ownership")
        require(feature.isSleepRestorationRefused, "Termination hid restoration failure")
        require(watchdogTerminationCount == 0, "Termination killed the cleanup watchdog")
        require(assertionReleaseCount == 0, "Termination released an unrestored assertion")
        try! await Task.sleep(nanoseconds: 5_200_000_000)
        require(commandHistory == [true, false], "The app retried after handing cleanup to the watchdog")
        return
    }
    require(feature.session == nil, "Termination failed to clear a restored session")
    require(watchdogTerminationCount == 1, "Termination did not stop the restored watchdog")
}

@MainActor func testTerminationWhileRestoring() async {
    let feature = buildFeature()
    await activate(feature)
    feature.stop()
    await waitUntil { commands.count == 1 }
    var didFinishTermination = false
    Task { @MainActor in
        await feature.prepareForTermination()
        didFinishTermination = true
    }
    await Task.yield()
    require(!didFinishTermination, "Termination discarded an in-flight restore")
    await completeCommand(disabled: false)
    await waitUntil { didFinishTermination }
    require(commandHistory == [true, false], "Termination ran overlapping restoration commands")
}

@MainActor func testPowerSuspension(_ keepsLidAwake: Bool) async {
    KeepAwakePreferences.onlyWhileConnectedToPower = true
    KeepAwakePreferences.keepsAwakeWithLidClosed = keepsLidAwake
    let feature = buildFeature()
    feature.turnOn(for: .oneHour)
    if keepsLidAwake { await completeCommand(disabled: true) }
    await waitUntil { feature.session != nil }
    let session = feature.session!
    let deadline = session.deactivationDate

    ExternalPowerSource.current.isConnected = false
    if keepsLidAwake { await completeCommand(disabled: false) }
    await waitUntil { feature.session == nil }
    require(feature.isWaitingForPower, "Unplugging lost the user's enabled session")
    require(assertionReleaseCount == 1, "Unplugging did not release the power assertion")
    require(watchdogTerminationCount == (keepsLidAwake ? 1 : 0), "Unplugging did not stop the restored watchdog")

    ExternalPowerSource.current.isConnected = true
    if keepsLidAwake { await completeCommand(disabled: true) }
    await waitUntil { feature.session != nil }
    require(feature.session === session, "Reconnecting replaced the suspended session")
    require(feature.session!.deactivationDate == deadline, "Reconnecting restarted the deadline")
    require(!feature.isWaitingForPower, "Reconnecting kept the waiting subtitle")

    feature.stop()
    if keepsLidAwake { await completeCommand(disabled: false) }
    await waitUntil { feature.session == nil }
    require(assertionReleaseCount == 2, "The resumed assertion was not released")
    if keepsLidAwake {
        require(commandHistory == [true, false, true, false], "Power changes did not serialize lid commands")
        return
    }
    require(commandHistory.isEmpty, "Idle-sleep power changes ran lid commands")
}

@MainActor func testBatteryActivation(_ usesDurationChip: Bool) async {
    KeepAwakePreferences.onlyWhileConnectedToPower = true
    let feature = buildFeature()
    ExternalPowerSource.current.isConnected = false

    if usesDurationChip {
        feature.turnOn(for: .oneHour)
    } else {
        feature.toggle()
    }
    require(feature.isWaitingForPower, "Battery activation did not retain the user's enablement")
    await Task.yield()
    require(feature.session == nil, "Keep Awake activated on battery")
    require(commandHistory.isEmpty, "Battery activation disabled lid sleep")
    require(watchdogLaunchCount == 0, "Battery activation launched a watchdog")

    ExternalPowerSource.current.isConnected = true
    await completeCommand(disabled: true)
    await waitUntil { !feature.isChangingSession }
    require(feature.session != nil, "Reconnecting did not honor battery enablement")
    if usesDurationChip {
        require(feature.session!.autoOff == .oneHour, "The battery duration chip lost its duration")
    }
}

@MainActor func testPowerManualStop(_ stopsFeature: Bool) async {
    KeepAwakePreferences.onlyWhileConnectedToPower = true
    let feature = buildFeature()
    await activate(feature)
    ExternalPowerSource.current.isConnected = false
    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }

    if stopsFeature {
        feature.stop()
        feature.start()
    } else {
        feature.toggle()
    }
    require(!feature.isWaitingForPower, "Turning off retained suspended enablement")
    ExternalPowerSource.current.isConnected = true
    try! await Task.sleep(nanoseconds: 20_000_000)
    require(feature.session == nil, "Reconnecting enabled a manually disabled session")
    require(commandHistory == [true, false], "Reconnecting ran commands for a disabled session")
}

@MainActor func testPowerExpiration() async {
    KeepAwakePreferences.onlyWhileConnectedToPower = true
    KeepAwakePreferences.autoOff = .thirtyMinutes
    let feature = buildFeature()
    await activate(feature)
    ExternalPowerSource.current.isConnected = false
    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    await waitUntil { !feature.isWaitingForPower }

    ExternalPowerSource.current.isConnected = true
    try! await Task.sleep(nanoseconds: 20_000_000)
    require(feature.session == nil, "Reconnecting restarted an expired session")
    require(commandHistory == [true, false], "Reconnecting disabled sleep after expiration")
}

@MainActor func testPowerSetting() async {
    let feature = buildFeature()
    ExternalPowerSource.current.isConnected = false
    await activate(feature)
    let session = feature.session!

    KeepAwakePreferences.current.setOnlyWhileConnectedToPower(true)
    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "Enabling the power option did not restore sleep on battery")
    require(feature.isWaitingForPower, "Enabling the power option lost user enablement")

    KeepAwakePreferences.current.setOnlyWhileConnectedToPower(false)
    await completeCommand(disabled: true)
    await waitUntil { !feature.isChangingSession }
    require(feature.session === session, "Disabling the power option replaced the session")
    require(!feature.isWaitingForPower, "Disabling the power option left battery gating active")
}

@MainActor func testPowerPendingActivation() async {
    KeepAwakePreferences.onlyWhileConnectedToPower = true
    let feature = buildFeature()
    feature.turnOn(for: .oneHour)
    await waitUntil { commands.count == 1 }

    ExternalPowerSource.current.isConnected = false
    await completeCommand(disabled: true)
    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "Unplugging retained an in-flight activation")
    require(feature.isWaitingForPower, "Unplugging discarded in-flight enablement")
    require(commandHistory == [true, false], "Unplugging overlapped activation and restoration")
    require(assertionReleaseCount == 1, "Unplugging leaked the late activation's assertion")
    require(watchdogTerminationCount == 1, "Unplugging orphaned the late activation's watchdog")
}

@MainActor func testPowerPendingRestoration() async {
    KeepAwakePreferences.onlyWhileConnectedToPower = true
    let feature = buildFeature()
    await activate(feature)
    let session = feature.session!
    ExternalPowerSource.current.isConnected = false
    await waitUntil { commands.count == 1 }

    ExternalPowerSource.current.isConnected = true
    await completeCommand(disabled: false)
    await completeCommand(disabled: true)
    await waitUntil { !feature.isChangingSession }
    require(feature.session === session, "Reconnecting during restoration lost the enabled session")
    require(commandHistory == [true, false, true], "Reconnecting during restoration overlapped power commands")
}

@MainActor func testPowerRestorationRetry() async {
    KeepAwakePreferences.onlyWhileConnectedToPower = true
    let feature = buildFeature()
    await activate(feature)
    ExternalPowerSource.current.isConnected = false
    await completeCommand(disabled: false, succeeds: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.isSleepRestorationRefused, "Unplugging hid restoration failure")
    require(assertionReleaseCount == 0, "Unplugging released an unrestored assertion")
    require(watchdogTerminationCount == 0, "Unplugging abandoned failed cleanup")

    await completeCommand(disabled: false)
    await waitUntil { !feature.isChangingSession }
    require(feature.session == nil, "Unplugging did not retry failed cleanup")
    require(feature.isWaitingForPower, "Cleanup retry discarded suspended enablement")
    require(commandHistory == [true, false, false], "Cleanup retry activated on battery")
}

Task { @MainActor in
    switch CommandLine.arguments[1] {
    case "session-retry": await testSessionRetry()
    case "idle-sleep": await testIdleSleepSession()
    case "activation-refusal": await testActivationRefusal()
    case "toggle-retry": await testToggleRetry()
    case "replacement-refusal": await testReplacementRefusal()
    case "stop-retry": await testStopRetry()
    case "timer-retry": await testTimerRetry()
    case "pending-activation-stop": await testPendingActivationStop()
    case "rapid-toggles": await testRapidToggles()
    case "rapid-duration-replacement": await testRapidDurationReplacement()
    case "termination": await testTermination(false)
    case "termination-refusal": await testTermination(true)
    case "termination-restoring": await testTerminationWhileRestoring()
    case "power-lid-sleep": await testPowerSuspension(true)
    case "power-idle-sleep": await testPowerSuspension(false)
    case "battery-toggle": await testBatteryActivation(false)
    case "battery-duration": await testBatteryActivation(true)
    case "power-manual-off": await testPowerManualStop(false)
    case "power-feature-stop": await testPowerManualStop(true)
    case "power-expiration": await testPowerExpiration()
    case "power-setting": await testPowerSetting()
    case "power-pending-activation": await testPowerPendingActivation()
    case "power-pending-restoration": await testPowerPendingRestoration()
    case "power-restoration-retry": await testPowerRestorationRetry()
    default: fatalError("Unknown test scenario")
    }
    exit(0)
}
RunLoop.main.run()
