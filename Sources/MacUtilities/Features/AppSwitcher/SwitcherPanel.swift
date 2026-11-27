import AppKit

/// The floating panel a switcher state is drawn in: the switcher's own, centered on the screen, or the preview beside the settings window.
protocol SwitcherPanel: AnyObject {
    var onCellClicked: (Int) -> Void { get set }
    /// The width the edge drag asks for, before clamping.
    var onWidthDragged: (CGFloat) -> Void { get set }

    /// On the glass as set in the store now; later changes to it show from updateGlass.
    func show(state: SwitcherState, glassStore: GlassStore)
    /// With the hints in from the start, so it is placed at its final size, and positioned beside the settings window.
    func showPreview(state: SwitcherState, glassStore: GlassStore, beside settingsWindow: NSWindow)
    func positionPreview(beside settingsWindow: NSWindow)
    /// The selection, the apps' dimming and marks, the thumbnails and the hints, in the cells already built.
    func update(state: SwitcherState)
    /// The glass and cards as set now, in the cells already built.
    func updateGlass(state: SwitcherState, glassStore: GlassStore)
    /// Re-wraps the cells to the state's row width at once, the panel staying centered.
    func resize(state: SwitcherState)
    /// Animates the app's cell out while the rest slide into place.
    func removeApp(at index: Int, state: SwitcherState)
    /// Once the panel has stayed open a moment, so a quick Cmd+Tab never shows them.
    func showHintsAfterDelay()
    /// For a moment in place of the hints.
    func showFeedback(_ feedback: SwitcherFeedback)
    /// Drops the hints and feedback still to come, for the next opening.
    func hide()
}
