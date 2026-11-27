import AppKit
@testable import MacUtilities

/// Records what the switcher draws, in a log shared with the other panel.
final class SwitcherFakePanel: SwitcherPanel {
    var onCellClicked: (Int) -> Void = { _ in }
    var onWidthDragged: (CGFloat) -> Void = { _ in }
    private(set) var isVisible = false

    private let log: SwitcherPanelLog

    init(log: SwitcherPanelLog) {
        self.log = log
    }

    func show(state: SwitcherState, glassStore: GlassStore) {
        log.shownStates.append(state)
        isVisible = true
    }

    func showPreview(state: SwitcherState, glassStore: GlassStore, beside settingsWindow: NSWindow) {
        log.shownStates.append(state)
        isVisible = true
    }

    func positionPreview(beside settingsWindow: NSWindow) {
        log.previewPositionCount += 1
    }

    func update(state: SwitcherState) {
        log.updatedStates.append(state)
    }

    func updateGlass(state: SwitcherState, glassStore: GlassStore) {
        log.glassUpdatedStates.append(state)
    }

    func resize(state: SwitcherState) {}

    func removeApp(at index: Int, state: SwitcherState) {}

    func showHintsAfterDelay() {}

    func showFeedback(_ feedback: SwitcherFeedback) {
        log.feedback.append(feedback)
    }

    func hide() {
        isVisible = false
    }
}

/// What the switcher's panel and its preview panel were asked to draw, in order.
final class SwitcherPanelLog {
    /// Shown by either panel, as the switcher or as the preview.
    var shownStates: [SwitcherState] = []
    var updatedStates: [SwitcherState] = []
    var glassUpdatedStates: [SwitcherState] = []
    var feedback: [SwitcherFeedback] = []
    var previewPositionCount = 0
}
