import AppKit
import QuartzCore

/// What the switcher panel draws, in a glass the panel shows as its content view: the cells, the highlight, the selected app's name, the
/// whitelist badge, the hint band and the resize handles, laid out from the top down. The cells are built for each opening and reused while
/// the selection, the look or the width changes; the hint band is kept across openings. Needs no window.
final class SwitcherPanelContent {
    var onCellClicked: (Int) -> Void = { _ in }
    /// The width the edge drag asks for, before clamping.
    var onWidthDragged: (CGFloat) -> Void = { _ in }

    /// Replaced when the look changes between Clear and Frosted.
    private(set) var glass: NSGlassEffectView!
    private(set) var isFrosted = false
    /// From the moment the hints come in or a shortcut says what it did, until the panel hides.
    private(set) var isShowingHintBand = false

    /// The last state drawn.
    private var state: SwitcherState!
    private var cells: [SwitcherCellView] = []
    private var highlight = NSView()
    private var nameLabel = NSTextField(labelWithString: "")
    private let hintBand = HintBandView()

    /// Where everything sits for the last state drawn.
    var layout: SwitcherLayout {
        return SwitcherLayout(
            cellCount: state.list.count,
            cellsPerRow: state.list.cellsPerRow,
            metrics: getCellMetrics(listingWindows: state.list.isListingWindows),
            showsHintBand: isShowingHintBand
        )
    }

    /// New cells for a new list, on the glass as set in the store now. With showsHintsAtOnce the hint band is in from the start, showing the
    /// hints; otherwise it stays as it was.
    func rebuild(state: SwitcherState, glassStore: GlassStore, showsHintsAtOnce: Bool) {
        self.state = state
        isFrosted = glassStore.isFrosted
        if showsHintsAtOnce {
            isShowingHintBand = true
        }

        buildContent(glassDarkness: glassStore.darkness)
        if showsHintsAtOnce {
            hintBand.showHints()
        }
    }

    /// A change between Clear and Frosted moves the content into a new glass, since the effect resolves the window's active appearance when
    /// attached; a darkness change only retints it.
    func updateGlass(state: SwitcherState, glassStore: GlassStore) {
        if isFrosted != glassStore.isFrosted {
            isFrosted = glassStore.isFrosted
            let container = glass.contentView
            let updatedGlass = buildGlassView(size: glass.frame.size, darkness: glassStore.darkness)

            glass.contentView = nil
            updatedGlass.contentView = container
            glass = updatedGlass
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
        let layout = layout

        switch state.list.items {
        case .apps(let apps, _):
            showAppStatus(apps, layout: layout)
        case .windows(let windows):
            showWindowStatus(windows)
        }
        hintBand.setHints(buildShortcutHints(), width: layout.contentSize.width)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            highlight.animator().frame = layout.getHighlightFrame(index: state.list.selectedIndex)
        }
    }

    /// Takes the app's cell out of the rows and moves the selection's ring, name and hints to the state's; the cell stays in place until
    /// animateRemoval moves it out. Returns that cell.
    func removeCell(at index: Int, state: SwitcherState) -> IconCellView {
        self.state = state
        let cell = cells.remove(at: index) as! IconCellView

        cell.onClick = { _ in }
        for later in cells[index...] { later.index -= 1 }
        for remaining in cells {
            remaining.card.showSelected(remaining.index == state.list.selectedIndex)
        }
        nameLabel.stringValue = state.list.selectedApp.name
        hintBand.setHints(buildShortcutHints(), width: layout.contentSize.width)

        return cell
    }

    /// Inside the panel's animation group: fades and shrinks the removed cell out while the rest slide into place.
    func animateRemoval(of cell: IconCellView) {
        let layout = layout

        cell.animator().alphaValue = 0
        cell.icon.animator().frame = cell.icon.frame.insetBy(dx: leavingIconShrink, dy: leavingIconShrink)
        highlight.animator().frame = layout.getHighlightFrame(index: state.list.selectedIndex)
        nameLabel.animator().frame = getNameFrame(layout: layout)
        hintBand.animator().frame = layout.hintBandFrame

        for (index, cell) in cells.enumerated() {
            cell.animator().frame = layout.cellFrames[index]
        }
    }

    /// Re-wraps the cells to the state's row width without animation, so they follow the edge drag live.
    func relayout(state: SwitcherState) {
        self.state = state
        let layout = layout

        for (cell, frame) in zip(cells, layout.cellFrames) {
            cell.frame = frame
        }
        highlight.frame = layout.getHighlightFrame(index: state.list.selectedIndex)
        if !state.list.isListingWindows {
            nameLabel.frame = getNameFrame(layout: layout)
        }
        hintBand.frame = layout.hintBandFrame
        hintBand.setHints(buildShortcutHints(), width: layout.contentSize.width)
    }

    /// The layout grows by the band; the panel grows along.
    func showHintBand() {
        isShowingHintBand = true
    }

    func showHints() {
        hintBand.showHints()
    }

    func showFeedback(_ feedback: SwitcherFeedback) {
        hintBand.showFeedback(feedback, width: layout.contentSize.width)
    }

    /// Takes the band away and clears it, for the next opening.
    func hideHintBand() {
        isShowingHintBand = false
        hintBand.clear()
    }

    private func buildContent(glassDarkness: CGFloat) {
        let layout = layout
        let container = SwitcherContentView(frame: NSRect(origin: .zero, size: layout.contentSize))

        // Icons draw as aqua like my-dock's tiles, so system images keep their light variants on the dark glass.
        container.appearance = NSAppearance(named: .aqua)
        highlight = buildHighlight()
        cells = buildCells(layout: layout)

        container.addSubview(highlight)
        if state.list.items.isWhitelistOnly {
            container.addSubview(buildWhitelistBadge(size: layout.contentSize))
        }
        for cell in cells {
            container.addSubview(cell)
        }
        if !state.list.isListingWindows {
            nameLabel = buildNameLabel(text: state.list.selectedApp.name)
            nameLabel.frame = getNameFrame(layout: layout)
            container.addSubview(nameLabel)
        }
        hintBand.frame = layout.hintBandFrame
        hintBand.setHints(buildShortcutHints(), width: layout.contentSize.width)
        container.addSubview(hintBand)
        for handle in buildResizeHandles(size: layout.contentSize) {
            container.addSubview(handle)
        }

        highlight.frame = layout.getHighlightFrame(index: state.list.selectedIndex)

        glass = buildGlassView(size: layout.contentSize, darkness: glassDarkness)
        glass.contentView = container
    }

    private func buildCells(layout: SwitcherLayout) -> [SwitcherCellView] {
        var cells: [SwitcherCellView] = []

        switch state.list.items {
        case .apps(let apps, _):
            for (index, app) in apps.enumerated() {
                cells.append(buildIconCell(app: app, index: index))
            }
        case .windows(let windows):
            for (index, window) in windows.enumerated() {
                cells.append(buildWindowCell(window: window, index: index))
            }
        }

        for (index, cell) in cells.enumerated() {
            cell.index = index
            cell.frame = layout.cellFrames[index]
            cell.onClick = { [unowned self] index in self.onCellClicked(index) }
        }

        return cells
    }

    private func buildIconCell(app: SwitcherApp, index: Int) -> SwitcherCellView {
        let cell = IconCellView(app: app, cardGlass: state.cardGlass)

        cell.showStatus(app: app, whitelisted: isWhitelisted(app), isFiltered: state.list.items.isWhitelistOnly, dimHiddenApps: state.dimHiddenApps)
        cell.card.showSelected(index == state.list.selectedIndex)

        return cell
    }

    private func buildWindowCell(window: SwitcherWindow, index: Int) -> SwitcherCellView {
        let cell = WindowCellView(window: window, cardGlass: state.cardGlass)

        cell.card.showSelected(index == state.list.selectedIndex)
        if let thumbnail = state.thumbnails[window.windowID] {
            cell.showThumbnail(thumbnail)
        }

        return cell
    }

    /// Dims the hidden apps, marks the whitelisted ones and names the selected one.
    private func showAppStatus(_ apps: [SwitcherApp], layout: SwitcherLayout) {
        for (index, app) in apps.enumerated() {
            let cell = cells[index] as! IconCellView
            cell.showStatus(app: app, whitelisted: isWhitelisted(app), isFiltered: state.list.items.isWhitelistOnly, dimHiddenApps: state.dimHiddenApps)
            cell.card.showSelected(index == state.list.selectedIndex)
        }

        nameLabel.stringValue = state.list.selectedApp.name
        nameLabel.frame = getNameFrame(layout: layout)
    }

    /// Rings the selected window's card and swaps in the thumbnails captured since the cells were built.
    private func showWindowStatus(_ windows: [SwitcherWindow]) {
        for (index, window) in windows.enumerated() {
            let cell = cells[index] as! WindowCellView

            cell.card.showSelected(index == state.list.selectedIndex)
            if let thumbnail = state.thumbnails[window.windowID] {
                cell.showThumbnail(thumbnail)
            }
        }
    }

    /// A drag asks for the width that keeps the panel centered with the dragged edge under the mouse: twice the mouse's distance from the
    /// middle, negative once it crosses over.
    private func buildResizeHandles(size: NSSize) -> [ResizeHandleView] {
        let left = ResizeHandleView()
        let right = ResizeHandleView()

        left.frame = NSRect(x: 0, y: 0, width: resizeHandleWidth, height: size.height)
        left.autoresizingMask = [.maxXMargin, .height]
        left.onDragged = { [unowned self, unowned left] mouseX in self.onWidthDragged(2 * (left.window!.frame.midX - mouseX)) }

        right.frame = NSRect(x: size.width - resizeHandleWidth, y: 0, width: resizeHandleWidth, height: size.height)
        right.autoresizingMask = [.minXMargin, .height]
        right.onDragged = { [unowned self, unowned right] mouseX in self.onWidthDragged(2 * (mouseX - right.window!.frame.midX)) }

        return [left, right]
    }

    /// What can be done now: for apps worded for the selected app and the filter, for windows only moving the selection and cancelling.
    private func buildShortcutHints() -> [ShortcutHint] {
        if state.list.isListingWindows { return buildWindowShortcutHints() }
        return buildAppShortcutHints()
    }

    /// The band drops them from the end as the panel narrows. Hide is left out for a hidden app, where it does nothing.
    private func buildAppShortcutHints() -> [ShortcutHint] {
        let app = state.list.selectedApp
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
        let arrowKeys = state.list.count > state.list.cellsPerRow ? "← → ↑ ↓" : "← →"

        return [
            ShortcutHint(keys: arrowKeys, action: "Select"),
            ShortcutHint(keys: "esc", action: "Cancel"),
        ]
    }

    private func isWhitelisted(_ app: SwitcherApp) -> Bool {
        return state.whitelisted.contains(app.bundleIdentifier)
    }

    /// Centered under the selected icon and no wider than twice the run to the nearer panel edge, so it truncates instead of crossing it.
    private func getNameFrame(layout: SwitcherLayout) -> NSRect {
        let iconFrame = layout.getIconFrame(index: state.list.selectedIndex)
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
        let isListingWindows = state.list.isListingWindows

        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = isListingWindows ? highlightCornerRadius : iconCardCornerRadius
        highlight.layer?.cornerCurve = isListingWindows ? .circular : .continuous
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
