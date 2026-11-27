import AppKit
import QuartzCore

/// A borderless floating window on every Space that never takes keyboard focus, its content the glass of a SwitcherPanelContent. It orders
/// itself in and out, places itself and grows for the hint band; what it draws is the content's. Not final so tests can keep it off the screen.
class GlassSwitcherPanel: NSPanel, SwitcherPanel {
    private let content = SwitcherPanelContent()
    private var hintShowing: DispatchWorkItem?
    private var feedbackHiding: DispatchWorkItem?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    var onCellClicked: (Int) -> Void {
        get { return content.onCellClicked }
        set { content.onCellClicked = newValue }
    }

    var onWidthDragged: (CGFloat) -> Void {
        get { return content.onWidthDragged }
        set { content.onWidthDragged = newValue }
    }

    /// Glass in a window without the active appearance draws a frosted, near-opaque stand-in, and this panel is never key. AppKit asks this
    /// private method, so answering yes gets the real see-through glass without taking keyboard focus from the frontmost app; Frosted keeps the stand-in.
    @objc func _hasActiveAppearance() -> Bool {
        return !content.isFrosted
    }

    /// Lets the resize cursor show over the edges first, while the app stays inactive.
    func show(state: SwitcherState, glassStore: GlassStore) {
        enableCursorChangesWhileInactive()
        content.rebuild(state: state, glassStore: glassStore, showsHintsAtOnce: false)
        attachContent()
        center()
        orderFrontFadingIn()
    }

    func showPreview(state: SwitcherState, glassStore: GlassStore, beside settingsWindow: NSWindow) {
        content.rebuild(state: state, glassStore: glassStore, showsHintsAtOnce: true)
        attachContent()
        positionPreview(beside: settingsWindow)
        orderFrontFadingIn()
    }

    func positionPreview(beside settingsWindow: NSWindow) {
        setFrame(getPreviewFrame(contentSize: frame.size, settingsFrame: settingsWindow.frame,
                                 screenFrame: settingsWindow.screen!.visibleFrame), display: true)
    }

    func update(state: SwitcherState) {
        content.update(state: state)
    }

    /// Attaches the content's new glass when the look changed between Clear and Frosted: the effect resolves the panel's active appearance when attached.
    func updateGlass(state: SwitcherState, glassStore: GlassStore) {
        content.updateGlass(state: state, glassStore: glassStore)
        if contentView !== content.glass {
            contentView = content.glass
        }
    }

    /// Shrinks around the panel's own middle while the cell goes.
    func removeApp(at index: Int, state: SwitcherState) {
        let leavingCell = content.removeCell(at: index, state: state)
        let contentSize = content.layout.contentSize

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = removalDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            content.animateRemoval(of: leavingCell)
            animator().setFrame(getFrame(centeredOnX: frame.midX, contentSize: contentSize), display: true)
        }, completionHandler: {
            leavingCell.removeFromSuperview()
        })
    }

    /// Centered on the screen, so the cells follow the edge drag live.
    func resize(state: SwitcherState) {
        content.relayout(state: state)
        setFrame(getFrame(centeredOnX: screen!.visibleFrame.midX, contentSize: content.layout.contentSize), display: true)
    }

    func showHintsAfterDelay() {
        hintShowing = DispatchWorkItem {
            self.showHintBand()
            self.content.showHints()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + hintDelay, execute: hintShowing!)
    }

    /// Grows the band first when it is not shown yet; the hints come in after the feedback either way.
    func showFeedback(_ feedback: SwitcherFeedback) {
        hintShowing?.cancel()
        feedbackHiding?.cancel()
        if !content.isShowingHintBand {
            showHintBand()
        }

        content.showFeedback(feedback)
        feedbackHiding = DispatchWorkItem { self.content.showHints() }
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration, execute: feedbackHiding!)
    }

    /// Also takes the band away, so the next opening starts without it.
    func hide() {
        hintShowing?.cancel()
        feedbackHiding?.cancel()
        content.hideHintBand()
        orderOut(nil)
    }

    private func attachContent() {
        contentView = content.glass
        setContentSize(content.layout.contentSize)
    }

    /// Already on screen, as when Cmd+F rebuilt the content, it just stays in front.
    private func orderFrontFadingIn() {
        if isVisible {
            orderFrontRegardless()
            return
        }

        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            animator().alphaValue = 1
        }
    }

    /// Grows the panel down by the band, its top edge staying put: the content counts from the top, so the rows keep their place and the band,
    /// waiting under them, comes into view.
    private func showHintBand() {
        content.showHintBand()
        let height = content.layout.contentSize.height

        NSAnimationContext.runAnimationGroup { context in
            context.duration = hintFadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(alignToPixels(NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)), display: true)
        }
    }

    /// At the panel's current height. Removal shrinks around the panel's own middle; a resize centers on the screen instead, because keeping the
    /// current center would drift half a pixel every other snap as the widths alternate between odd and even.
    private func getFrame(centeredOnX centerX: CGFloat, contentSize: NSSize) -> NSRect {
        return alignToPixels(NSRect(
            x: centerX - contentSize.width / 2,
            y: frame.midY - contentSize.height / 2,
            width: contentSize.width,
            height: contentSize.height
        ))
    }
}
