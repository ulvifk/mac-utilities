import AppKit
import Testing
@testable import MacUtilities

/// Which key presses the switcher swallows and which it passes on to the focused app, in each of its phases.
@MainActor @Suite(.serialized)
struct AppSwitcherKeyRoutingTests {
    nonisolated static let keyPresses = [
        SwitcherTestKeyPress(name: "⌘⇥", keyCode: tabKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.allPhases),
        SwitcherTestKeyPress(name: "⇧⌘⇥", keyCode: tabKeyCode, modifiers: [.maskCommand, .maskShift], swallowedIn: SwitcherTestPhase.allPhases),
        SwitcherTestKeyPress(name: "⌘`", keyCode: graveKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.allPhases),
        SwitcherTestKeyPress(name: "⇧⌘`", keyCode: graveKeyCode, modifiers: [.maskCommand, .maskShift], swallowedIn: SwitcherTestPhase.allPhases),
        SwitcherTestKeyPress(name: "esc", keyCode: escapeKeyCode, modifiers: [], swallowedIn: [.opening, .listingApps, .listingWindows]),
        SwitcherTestKeyPress(name: "⌘→", keyCode: rightArrowKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⌘←", keyCode: leftArrowKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⌘↑", keyCode: upArrowKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⌘↓", keyCode: downArrowKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⌘W", keyCode: wKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⌘F", keyCode: fKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⌘H", keyCode: hKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⌘Q", keyCode: qKeyCode, modifiers: .maskCommand, swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⇧⌘Q", keyCode: qKeyCode, modifiers: [.maskCommand, .maskShift], swallowedIn: SwitcherTestPhase.openPhases),
        SwitcherTestKeyPress(name: "⌘A, no switcher shortcut", keyCode: 0, modifiers: .maskCommand, swallowedIn: []),
        SwitcherTestKeyPress(name: "⇥ without ⌘", keyCode: tabKeyCode, modifiers: [], swallowedIn: []),
    ]

    @Test(arguments: SwitcherTestPhase.allCases, keyPresses)
    func keyPress(phase: SwitcherTestPhase, keyPress: SwitcherTestKeyPress) async {
        let harness = AppSwitcherTestHarness()
        await enter(phase, harness: harness)

        let swallowed = harness.sendKeyDown(keyPress.keyCode, modifiers: keyPress.modifiers)

        #expect(swallowed == keyPress.swallowedIn.contains(phase), "\(keyPress.name) was \(swallowed ? "swallowed" : "passed on") while \(phase)")
        await harness.finish()
    }

    @Test(arguments: SwitcherTestPhase.allCases)
    func commandReleasePassesOn(phase: SwitcherTestPhase) async {
        let harness = AppSwitcherTestHarness()
        await enter(phase, harness: harness)

        harness.releaseCommand()
        await harness.finish()
    }

    private func enter(_ phase: SwitcherTestPhase, harness: AppSwitcherTestHarness) async {
        switch phase {
        case .closed:
            return
        case .opening:
            harness.press(tabKeyCode)
        case .listingApps:
            harness.press(tabKeyCode)
            await harness.drainMainQueue()
        case .listingWindows:
            harness.press(graveKeyCode)
            await harness.drainMainQueue()
        }
    }
}

/// What the switcher is doing when a key arrives: opening is before the list has loaded on the next main-queue turn.
enum SwitcherTestPhase: CaseIterable, Sendable {
    case closed
    case opening
    case listingApps
    case listingWindows

    static let allPhases = Set(allCases)
    static let openPhases: Set<SwitcherTestPhase> = [.listingApps, .listingWindows]
}

struct SwitcherTestKeyPress: CustomTestStringConvertible, Sendable {
    let name: String
    let keyCode: Int64
    let modifiers: CGEventFlags
    let swallowedIn: Set<SwitcherTestPhase>

    var testDescription: String { name }
}
