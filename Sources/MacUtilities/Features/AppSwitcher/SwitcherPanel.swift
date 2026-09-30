import AppKit
import QuartzCore

final class SwitcherPanel: NSPanel {
    var onCellClicked: (Int) -> Void = { _ in }
    /// The width the edge drag asks for, before clamping.
    var onWidthDragged: (CGFloat) -> Void = { _ in }

    /// The last state shown.
    private var state: SwitcherState!
    /// The last glass shown.
    private var isFrosted = false
    private var cells: [SwitcherCellView] = []
    private var highlight = NSView()
    private var nameLabel = NSTextField(labelWithString: "")
    private let hintBand = HintBandView()

    /// From the moment the hints come in or a shortcut says what it did, until the panel hides.
    private var isShowingHintBand = false
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

    /// Glass in a window without the active appearance draws a frosted, near-opaque stand-in, and this panel is never key. AppKit asks this
    /// private method, so answering yes gets the real see-through glass without taking keyboard focus from the frontmost app; Frosted keeps the stand-in.
    @objc func _hasActiveAppearance() -> Bool {
        return !isFrosted
    }

    /// On the glass as set in the store now; later changes to it show from the next call.
    func show(state: SwitcherState, glassStore: GlassStore, beside settingsWindow: NSWindow? = nil) {
        self.state = state
        isFrosted = glassStore.isFrosted
        let wasVisible = isVisible

        buildContent(glassDarkness: glassStore.darkness)
        if let settingsWindow {
            positionPreview(beside: settingsWindow)
        } else {
            center()
        }

        if wasVisible {
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

    func positionPreview(beside settingsWindow: NSWindow) {
        setFrame(getPreviewFrame(contentSize: frame.size, settingsFrame: settingsWindow.frame,
                                 screenFrame: settingsWindow.screen!.visibleFrame), display: true)
    }

    func updateGlass(state: SwitcherState, glassStore: GlassStore) {
        let glass = contentView as! NSGlassEffectView

        if isFrosted != glassStore.isFrosted {
            // The effect resolves the panel's active appearance when attached.
            isFrosted = glassStore.isFrosted
            let container = glass.contentView
            let updatedGlass = buildGlassView(size: glass.frame.size, darkness: glassStore.darkness)

            glass.contentView = nil
            updatedGlass.contentView = container
            contentView = updatedGlass
        } else {
            glass.tintColor = NSColor.black.withAlphaComponent(glassStore.darkness)
        }

        for cell in cells {
            cell.card.updateGlass(state.cardGlass)
        }

        update(state: state)
    }

    func update(state: SwitcherState) {
        self.state = state
        let layout = buildLayout()

        if state.isListingWindows {
            showWindowStatus()
        } else {
            showAppStatus(layout: layout)
        }
        hintBand.setHints(buildShortcutHints(), width: layout.contentSize.width)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            highlight.animator().frame = layout.getHighlightFrame(index: state.selectedIndex)
        }
    }

    /// Fades and shrinks the leaving icon out while the rest slide into place and the panel shrinks around them.
    func removeApp(at index: Int, state: SwitcherState) {
        self.state = state
        let layout = buildLayout()
        let cell = cells.remove(at: index) as! IconCellView

        cell.onClick = { _ in }
        for later in cells[index...] { later.index -= 1 }
        for remaining in cells {
            remaining.card.showSelected(remaining.index == state.selectedIndex)
        }
        nameLabel.stringValue = getSelectedName()
        hintBand.setHints(buildShortcutHints(), width: layout.contentSize.width)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = removalDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            cell.animator().alphaValue = 0
            cell.icon.animator().frame = cell.icon.frame.insetBy(dx: leavingIconShrink, dy: leavingIconShrink)
            animator().setFrame(getFrame(centeredOnX: frame.midX, contentSize: layout.contentSize), display: true)
            highlight.animator().frame = layout.getHighlightFrame(index: state.selectedIndex)
            nameLabel.animator().frame = getNameFrame(layout: layout)
            hintBand.animator().frame = layout.hintBandFrame

            for (index, cell) in cells.enumerated() {
                cell.animator().frame = layout.cellFrames[index]
            }
        }, completionHandler: {
            cell.removeFromSuperview()
        })
    }

    /// Re-wraps the cells to the state's row width without animation, so they follow the edge drag live; the panel stays centered.
    func resize(state: SwitcherState) {
        self.state = state
        let layout = buildLayout()

        for (cell, frame) in zip(cells, layout.cellFrames) {
            cell.frame = frame
        }
        highlight.frame = layout.getHighlightFrame(index: state.selectedIndex)
        if !state.isListingWindows {
            nameLabel.frame = getNameFrame(layout: layout)
        }
        hintBand.frame = layout.hintBandFrame
        hintBand.setHints(buildShortcutHints(), width: layout.contentSize.width)
        setFrame(getFrame(centeredOnX: screen!.visibleFrame.midX, contentSize: layout.contentSize), display: true)
    }

    /// Once the panel has stayed open a moment, so a quick Cmd+Tab never shows them.
    func showHintsAfterDelay() {
        hintShowing = DispatchWorkItem {
            self.showHintBand()
            self.hintBand.showHints()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + hintDelay, execute: hintShowing!)
    }

    /// For a moment in place of the hints, growing the band first when it is not shown yet; the hints come in after it either way.
    func showFeedback(_ feedback: SwitcherFeedback) {
        hintShowing?.cancel()
        feedbackHiding?.cancel()
        if !isShowingHintBand {
            showHintBand()
        }

        hintBand.showFeedback(feedback, width: buildLayout().contentSize.width)
        feedbackHiding = DispatchWorkItem { self.hintBand.showHints() }
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration, execute: feedbackHiding!)
    }

    /// Drops the hints and feedback still to come and takes the band away, so the next opening starts without it.
    func hide() {
        hintShowing?.cancel()
        feedbackHiding?.cancel()
        isShowingHintBand = false
        hintBand.clear()
        orderOut(nil)
    }

    private func buildContent(glassDarkness: CGFloat) {
        let layout = buildLayout()
        let container = SwitcherContentView(frame: NSRect(origin: .zero, size: layout.contentSize))

        // Icons draw as aqua like my-dock's tiles, so system images keep their light variants on the dark glass.
        container.appearance = NSAppearance(named: .aqua)
        highlight = buildHighlight()
        cells = buildCells(layout: layout)

        container.addSubview(highlight)
        if state.isFiltered {
            container.addSubview(buildWhitelistBadge(size: layout.contentSize))
        }
        for cell in cells {
            container.addSubview(cell)
        }
        if !state.isListingWindows {
            nameLabel = buildNameLabel(text: getSelectedName())
            nameLabel.frame = getNameFrame(layout: layout)
            container.addSubview(nameLabel)
        }
        hintBand.frame = layout.hintBandFrame
        hintBand.setHints(buildShortcutHints(), width: layout.contentSize.width)
        container.addSubview(hintBand)
        for handle in buildResizeHandles(size: layout.contentSize) {
            container.addSubview(handle)
        }

        highlight.frame = layout.getHighlightFrame(index: state.selectedIndex)

        let glass = buildGlassView(size: layout.contentSize, darkness: glassDarkness)
        glass.contentView = container

        contentView = glass
        setContentSize(layout.contentSize)
    }

    private func buildCells(layout: SwitcherLayout) -> [SwitcherCellView] {
        var cells: [SwitcherCellView] = []

        for index in layout.cellFrames.indices {
            let cell = state.isListingWindows ? buildWindowCell(index: index) : buildIconCell(index: index)

            cell.index = index
            cell.frame = layout.cellFrames[index]
            cell.onClick = { [unowned self] index in self.onCellClicked(index) }
            cells.append(cell)
        }

        return cells
    }

    private func buildIconCell(index: Int) -> SwitcherCellView {
        let app = state.apps[index]
        let cell = IconCellView(app: app, cardGlass: state.cardGlass)

        cell.showStatus(app: app, whitelisted: isWhitelisted(app), isFiltered: state.isFiltered, dimHiddenApps: state.dimHiddenApps)
        cell.card.showSelected(index == state.selectedIndex)

        return cell
    }

    private func buildWindowCell(index: Int) -> SwitcherCellView {
        let window = state.windows[index]
        let cell = WindowCellView(window: window, cardGlass: state.cardGlass)

        cell.card.showSelected(index == state.selectedIndex)
        if let thumbnail = state.thumbnails[window.windowID] {
            cell.showThumbnail(thumbnail)
        }

        return cell
    }

    /// Dims the hidden apps, marks the whitelisted ones and names the selected one.
    private func showAppStatus(layout: SwitcherLayout) {
        for (index, app) in state.apps.enumerated() {
            let cell = cells[index] as! IconCellView
            cell.showStatus(app: app, whitelisted: isWhitelisted(app), isFiltered: state.isFiltered, dimHiddenApps: state.dimHiddenApps)
            cell.card.showSelected(index == state.selectedIndex)
        }

        nameLabel.stringValue = getSelectedName()
        nameLabel.frame = getNameFrame(layout: layout)
    }

    /// Rings the selected window's card and swaps in the thumbnails captured since the cells were built.
    private func showWindowStatus() {
        for (index, window) in state.windows.enumerated() {
            let cell = cells[index] as! WindowCellView

            cell.card.showSelected(index == state.selectedIndex)
            if let thumbnail = state.thumbnails[window.windowID] {
                cell.showThumbnail(thumbnail)
            }
        }
    }

    /// A drag asks for the width that keeps the panel centered with the dragged edge under the mouse: twice the mouse's distance from the middle, negative once it crosses over.
    private func buildResizeHandles(size: NSSize) -> [ResizeHandleView] {
        let left = ResizeHandleView()
        let right = ResizeHandleView()

        left.frame = NSRect(x: 0, y: 0, width: resizeHandleWidth, height: size.height)
        left.autoresizingMask = [.maxXMargin, .height]
        left.onDragged = { [unowned self] mouseX in self.onWidthDragged(2 * (self.frame.midX - mouseX)) }

        right.frame = NSRect(x: size.width - resizeHandleWidth, y: 0, width: resizeHandleWidth, height: size.height)
        right.autoresizingMask = [.minXMargin, .height]
        right.onDragged = { [unowned self] mouseX in self.onWidthDragged(2 * (mouseX - self.frame.midX)) }

        return [left, right]
    }

    private func buildLayout() -> SwitcherLayout {
        let cellCount = state.isListingWindows ? state.windows.count : state.apps.count

        return SwitcherLayout(
            cellCount: cellCount,
            cellsPerRow: state.cellsPerRow,
            metrics: getCellMetrics(listingWindows: state.isListingWindows),
            showsHintBand: isShowingHintBand
        )
    }

    /// Grows the panel down by the band, its top edge staying put: the content counts from the top, so the rows keep their place and the band,
    /// waiting under them, comes into view.
    private func showHintBand() {
        isShowingHintBand = true
        let height = buildLayout().contentSize.height

        NSAnimationContext.runAnimationGroup { context in
            context.duration = hintFadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(alignToPixels(NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)), display: true)
        }
    }

    /// What can be done now: for apps worded for the selected app and the filter, for windows only moving the selection and cancelling.
    private func buildShortcutHints() -> [ShortcutHint] {
        if state.isListingWindows { return buildWindowShortcutHints() }
        return buildAppShortcutHints()
    }

    /// The band drops them from the end as the panel narrows. Hide is left out for a hidden app, where it does nothing.
    private func buildAppShortcutHints() -> [ShortcutHint] {
        let app = state.apps[state.selectedIndex]
        var hints = [
            ShortcutHint(keys: "⌘W", action: isWhitelisted(app) ? "Remove from Whitelist" : "Add to Whitelist"),
            ShortcutHint(keys: "⌘F", action: state.isFilterEnabled ? "Turn Filter Off" : "Turn Filter On"),
        ]

        if !app.isHidden {
            hints.append(ShortcutHint(keys: "⌘H", action: "Hide"))
        }
        hints.append(ShortcutHint(keys: "⌘Q", action: "Quit"))
        hints.append(ShortcutHint(keys: "⇧⌘Q", action: "Batch Quit"))
        hints.append(ShortcutHint(keys: "esc", action: "Cancel"))

        return hints
    }

    /// Up and down only with a second row to move to.
    private func buildWindowShortcutHints() -> [ShortcutHint] {
        let arrowKeys = state.windows.count > state.cellsPerRow ? "← → ↑ ↓" : "← →"

        return [
            ShortcutHint(keys: arrowKeys, action: "Select"),
            ShortcutHint(keys: "esc", action: "Cancel"),
        ]
    }

    private func isWhitelisted(_ app: NSRunningApplication) -> Bool {
        return state.whitelisted.contains(app.bundleIdentifier ?? "")
    }

    private func getSelectedName() -> String {
        return state.apps[state.selectedIndex].localizedName ?? ""
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

    /// Centered under the selected icon and no wider than twice the run to the nearer panel edge, so it truncates instead of crossing it.
    private func getNameFrame(layout: SwitcherLayout) -> NSRect {
        let iconFrame = layout.getIconFrame(index: state.selectedIndex)
        let maxWidth = 2 * min(iconFrame.midX - horizontalPadding, layout.contentSize.width - horizontalPadding - iconFrame.midX)
        let nameSize = nameLabel.fittingSize
        let width = min(nameSize.width, maxWidth)

        return alignToPixels(NSRect(x: iconFrame.midX - width / 2, y: iconFrame.maxY + nameTopSpacing, width: width, height: nameSize.height))
    }

    private func buildNameLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1

        return label
    }

    private func buildHighlight() -> NSView {
        let highlight = NSView()

        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = state.isListingWindows ? highlightCornerRadius : iconCardCornerRadius
        highlight.layer?.cornerCurve = state.isListingWindows ? .circular : .continuous
        highlight.layer?.backgroundColor = highlightColor.cgColor

        return highlight
    }

    private func buildGlassView(size: NSSize, darkness: CGFloat) -> NSGlassEffectView {
        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))

        glass.style = .clear
        glass.cornerRadius = panelCornerRadius
        glass.tintColor = NSColor.black.withAlphaComponent(darkness)

        return glass
    }

    /// Centered in the band above the top row's icons, following the top edge as the panel resizes.
    private func buildWhitelistBadge(size: NSSize) -> WhitelistBadgeView {
        let badge = WhitelistBadgeView()
        let badgeSize = badge.frame.size

        badge.frame = alignToPixels(NSRect(
            x: (size.width - badgeSize.width) / 2,
            y: iconVerticalPadding + nameBandHeight / 2 - badgeSize.height / 2,
            width: badgeSize.width,
            height: badgeSize.height
        ))
        badge.autoresizingMask = [.minXMargin, .maxXMargin]

        return badge
    }
}
