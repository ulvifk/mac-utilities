import AppKit

struct OpeningScenario {
    let name: String
    let itemCount: Int
    let backwardPresses: [Bool]
    let expectedSelection: Int?
}

let scenarios = [
    OpeningScenario(name: "forward", itemCount: 5, backwardPresses: [false], expectedSelection: 1),
    OpeningScenario(name: "backward", itemCount: 5, backwardPresses: [true], expectedSelection: 4),
    OpeningScenario(name: "pending-forward", itemCount: 5, backwardPresses: [false, false, false], expectedSelection: 3),
    OpeningScenario(name: "pending-backward", itemCount: 5, backwardPresses: [true, true, true], expectedSelection: 2),
    OpeningScenario(name: "mixed-forward", itemCount: 5, backwardPresses: [false, true, false], expectedSelection: 1),
    OpeningScenario(name: "mixed-backward", itemCount: 5, backwardPresses: [true, false, true], expectedSelection: 4),
    OpeningScenario(name: "opposite-cancel", itemCount: 5, backwardPresses: [true, false], expectedSelection: 0),
    OpeningScenario(name: "backward-wrap", itemCount: 3, backwardPresses: [true, true, true, true, true, true, true], expectedSelection: 2),
    OpeningScenario(name: "forward-wrap", itemCount: 3, backwardPresses: [false, false, false, false, false, false, false], expectedSelection: 1),
    OpeningScenario(name: "single-forward", itemCount: 1, backwardPresses: [false], expectedSelection: 0),
    OpeningScenario(name: "single-backward", itemCount: 1, backwardPresses: [true, true], expectedSelection: 0),
    OpeningScenario(name: "empty-forward", itemCount: 0, backwardPresses: [false], expectedSelection: nil),
    OpeningScenario(name: "empty-backward", itemCount: 0, backwardPresses: [true], expectedSelection: nil),
]

for listingWindows in [false, true] {
    for scenario in scenarios {
        RecentAppsTracker.apps = (0..<scenario.itemCount).map { NSRunningApplication(index: $0) }
        AppWindow.windows = (0..<scenario.itemCount).map { AppWindow(windowID: CGWindowID($0)) }
        SwitcherPanel.shownStates = []
        let feature = AppSwitcherFeature()
        feature.start()

        for backward in scenario.backwardPresses {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(listingWindows ? graveKeyCode : tabKeyCode), keyDown: true)!
            event.flags = backward ? [.maskCommand, .maskShift] : .maskCommand
            precondition(feature.handle(type: .keyDown, event: event), "Switcher shortcut was not handled")
        }

        var openingCompleted = false
        DispatchQueue.main.async { openingCompleted = true }
        while !openingCompleted {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        let actualSelection = SwitcherPanel.shownStates.last?.selectedIndex
        let list = listingWindows ? "windows" : "apps"
        precondition(actualSelection == scenario.expectedSelection, "\(list)/\(scenario.name): expected \(String(describing: scenario.expectedSelection)), got \(String(describing: actualSelection))")
        if let state = SwitcherPanel.shownStates.last {
            precondition(state.isListingWindows == listingWindows, "Wrong switcher list")
            precondition(SwitcherPanel.shownStates.count == 1, "Pending presses opened multiple panels")
        }

        feature.stop()
        print("PASS \(list)/\(scenario.name)")
    }
}
