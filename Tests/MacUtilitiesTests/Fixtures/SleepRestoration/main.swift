import AppKit
import Combine
import Foundation
import SwiftUI

var restorationResults: [Bool] = []
var activationResult = true
var activationCount = 0
var restorationCount = 0
var assertionReleaseCount = 0
var watchdogLaunchCount = 0
var watchdogTerminationCount = 0

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

func setLidClosedSleepDisabled(_ disabled: Bool) -> Bool {
    if disabled {
        activationCount += 1
        return activationResult
    }

    restorationCount += 1
    return restorationResults.removeFirst()
}

func launchLidClosedSleepWatchdog() -> Process {
    watchdogLaunchCount += 1
    return Process()
}

enum KeepAwakeAutoOff: String {
    case thirtyMinutes
    case untilTurnedOff

    var duration: TimeInterval? {
        if self == .untilTurnedOff { return nil }
        return 0.05
    }
}

final class KeepAwakePreferences {
    static var autoOff: KeepAwakeAutoOff = .untilTurnedOff
    static var keepsAwakeWithLidClosed = true

    var autoOff: KeepAwakeAutoOff { Self.autoOff }
    var keepsAwakeWithLidClosed: Bool { Self.keepsAwakeWithLidClosed }

    func setAutoOff(_ autoOff: KeepAwakeAutoOff) {
        Self.autoOff = autoOff
    }
}

struct KeepAwakeSettingsView: View {
    let preferences: KeepAwakePreferences
    var body: some View { EmptyView() }
}

struct KeepAwakeTile: View {
    let feature: KeepAwakeFeature
    var body: some View { EmptyView() }
}

func require(_ condition: Bool, _ message: String) {
    if condition { return }
    fatalError(message)
}

func testSessionRetry() {
    restorationResults = [false, true]
    let session = KeepAwakeSession(preferences: KeepAwakePreferences())!

    require(!session.end(), "Failed restoration must report failure")
    require(assertionReleaseCount == 0, "Failed restoration released the assertion")
    require(watchdogTerminationCount == 0, "Failed restoration stopped the watchdog")

    require(session.end(), "The next restoration should succeed")
    require(restorationCount == 2, "Restoration was not retried")
    require(assertionReleaseCount == 1, "Successful restoration did not release the assertion once")
    require(watchdogTerminationCount == 1, "Successful restoration did not stop the watchdog once")
}

func testIdleSleepSession() {
    KeepAwakePreferences.keepsAwakeWithLidClosed = false
    let session = KeepAwakeSession(preferences: KeepAwakePreferences())!

    require(session.end(), "An idle-sleep session should end successfully")
    require(activationCount == 0, "An idle-sleep session changed lid sleep")
    require(restorationCount == 0, "An idle-sleep session restored lid sleep")
    require(watchdogLaunchCount == 0, "An idle-sleep session launched a watchdog")
    require(assertionReleaseCount == 1, "An idle-sleep session did not release its assertion")
}

func testActivationRefusal() {
    activationResult = false
    let feature = KeepAwakeFeature(setMenuBarSymbol: { _ in fatalError("A refused activation changed the icon") })

    feature.toggle()
    require(feature.session == nil, "A refused activation retained a session")
    require(feature.isPmsetRefused, "A refused activation did not expose its failure")
    require(!feature.isSleepRestorationRefused, "A refused activation claimed restoration failed")
    require(watchdogTerminationCount == 1, "A refused activation did not stop its unused watchdog")
    require(assertionReleaseCount == 0, "A refused activation acquired a power assertion")
}

func testToggleRetry() {
    restorationResults = [false, true]
    var symbol: String?
    let feature = KeepAwakeFeature(setMenuBarSymbol: { symbol = $0 })
    feature.toggle()
    let session = feature.session!

    feature.toggle()
    require(feature.session === session, "Failed toggle discarded the active session")
    require(feature.isSleepRestorationRefused, "Failed toggle did not expose restoration failure")
    require(symbol == keepAwakeSymbolName, "Failed toggle reported an off icon")

    feature.toggle()
    require(feature.session == nil, "A successful retry did not clear the session")
    require(!feature.isSleepRestorationRefused, "A successful retry kept the warning")
    require(symbol == nil, "A successful retry kept the active icon")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 5.2))
    require(restorationCount == 2, "A canceled retry ran after the session ended")
}

func testReplacementRefusal() {
    restorationResults = [false, true]
    let feature = KeepAwakeFeature(setMenuBarSymbol: { _ in })
    feature.toggle()
    let session = feature.session!

    feature.turnOn(for: .thirtyMinutes)
    require(feature.session === session, "A duration chip replaced an unrestored session")
    require(feature.isSleepRestorationRefused, "A duration chip hid restoration failure")
    require(activationCount == 1, "A duration chip disabled sleep again before restoration")
    require(watchdogLaunchCount == 1, "A duration chip orphaned the previous watchdog")

    feature.toggle()
    require(feature.session == nil, "The blocked replacement could not be cleaned up")
}

func testStopRetry() {
    restorationResults = [false, true]
    var symbol: String?
    let feature = KeepAwakeFeature(setMenuBarSymbol: { symbol = $0 })
    feature.toggle()
    let session = feature.session!

    feature.stop()
    require(feature.session === session, "Stopping the feature discarded failed cleanup")
    require(symbol == keepAwakeSymbolName, "Stopping the feature hid failed cleanup")
    require(watchdogTerminationCount == 0, "Stopping the feature orphaned crash recovery")

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 5.2))
    require(feature.session == nil, "Stopping the feature canceled automatic cleanup retries")
    require(restorationCount == 2, "Stopping the feature did not retry restoration")
    require(symbol == nil, "Successful cleanup after stopping kept the active icon")
}

func testTimerRetry() {
    KeepAwakePreferences.autoOff = .thirtyMinutes
    restorationResults = [false, true]
    let feature = KeepAwakeFeature(setMenuBarSymbol: { _ in })
    feature.toggle()
    let session = feature.session!

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
    require(feature.session === session, "An expired timer discarded failed cleanup")
    require(feature.isSleepRestorationRefused, "An expired timer hid failed cleanup")
    require(assertionReleaseCount == 0, "An expired timer released an unrestored session")

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 5.2))
    require(feature.session == nil, "An expired timer did not retry restoration")
    require(restorationCount == 2, "An expired timer did not retry once")
}

switch CommandLine.arguments[1] {
case "session-retry": testSessionRetry()
case "idle-sleep": testIdleSleepSession()
case "activation-refusal": testActivationRefusal()
case "toggle-retry": testToggleRetry()
case "replacement-refusal": testReplacementRefusal()
case "stop-retry": testStopRetry()
case "timer-retry": testTimerRetry()
default: fatalError("Unknown test scenario")
}
