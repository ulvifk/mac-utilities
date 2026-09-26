import AppKit
import QuartzCore

final class SwitcherPanel: NSPanel {
    var onCellClicked: (Int) -> Void = { _ in }
    /// The width the edge drag asks for, before clamping.
    var onWidthDragged: (CGFloat) -> Void = { _ in }

    /// The last state shown.
    private var state: SwitcherState!
    private var cells: [IconCellView] = []
    private var highlight = NSView()
    private var nameLabel = NSTextField(labelWithString: "")

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

    func show(state: SwitcherState) {
        self.state = state
        let wasVisible = isVisible

        buildContent()
        center()

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

    func update(state: SwitcherState) {
        self.state = state
        let layout = buildLayout()

        for (cell, app) in zip(cells, state.apps) {
            cell.showStatus(app: app, whitelisted: isWhitelisted(app), isFiltered: state.isFiltered)
        }

        nameLabel.stringValue = getSelectedName()
        nameLabel.frame = getNameFrame(layout: layout)

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
        let cell = cells.remove(at: index)

        cell.onClick = { _ in }
        for later in cells[index...] { later.index -= 1 }
        nameLabel.stringValue = getSelectedName()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = removalDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            cell.animator().alphaValue = 0
            cell.icon.animator().frame = cell.icon.frame.insetBy(dx: leavingIconShrink, dy: leavingIconShrink)
            animator().setFrame(getFrame(centeredOnX: frame.midX, contentSize: layout.contentSize), display: true)
            highlight.animator().frame = layout.getHighlightFrame(index: state.selectedIndex)
            nameLabel.animator().frame = getNameFrame(layout: layout)

            for (index, cell) in cells.enumerated() {
                cell.animator().frame = layout.cellFrames[index]
            }
        }, completionHandler: {
            cell.removeFromSuperview()
        })
    }

    /// Re-wraps the icons to the state's row width without animation, so they follow the edge drag live; the panel stays centered.
    func resize(state: SwitcherState) {
        self.state = state
        let layout = buildLayout()

        for (cell, frame) in zip(cells, layout.cellFrames) {
            cell.frame = frame
        }
        highlight.frame = layout.getHighlightFrame(index: state.selectedIndex)
        nameLabel.frame = getNameFrame(layout: layout)
        setFrame(getFrame(centeredOnX: screen!.visibleFrame.midX, contentSize: layout.contentSize), display: true)
    }

    func hide() {
        orderOut(nil)
    }

    private func buildContent() {
        let layout = buildLayout()
        let container = NSView(frame: NSRect(origin: .zero, size: layout.contentSize))

        // Icons draw as aqua like my-dock's tiles, so system images keep their light variants on the dark glass.
        container.appearance = NSAppearance(named: .aqua)
        highlight = buildHighlight()
        nameLabel = buildNameLabel(text: getSelectedName())
        cells = buildCells(layout: layout)

        container.addSubview(highlight)
        if state.isFiltered {
            container.addSubview(buildWhitelistBadge(size: layout.contentSize))
        }
        for cell in cells {
            container.addSubview(cell)
        }
        container.addSubview(nameLabel)
        for handle in buildResizeHandles(size: layout.contentSize) {
            container.addSubview(handle)
        }

        highlight.frame = layout.getHighlightFrame(index: state.selectedIndex)
        nameLabel.frame = getNameFrame(layout: layout)

        let glass = buildGlassView(size: layout.contentSize)
        glass.contentView = container

        contentView = glass
        setContentSize(layout.contentSize)
    }

    private func buildCells(layout: SwitcherLayout) -> [IconCellView] {
        var cells: [IconCellView] = []

        for (index, app) in state.apps.enumerated() {
            let cell = IconCellView(app: app)

            cell.showStatus(app: app, whitelisted: isWhitelisted(app), isFiltered: state.isFiltered)
            cell.index = index
            cell.frame = layout.cellFrames[index]
            cell.onClick = { [unowned self] index in self.onCellClicked(index) }
            cells.append(cell)
        }

        return cells
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
        return SwitcherLayout(appCount: state.apps.count, iconsPerRow: state.iconsPerRow)
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

        return alignToPixels(NSRect(x: iconFrame.midX - width / 2, y: iconFrame.minY - nameTopSpacing - nameSize.height, width: width, height: nameSize.height))
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
        highlight.layer?.cornerRadius = highlightCornerRadius
        highlight.layer?.backgroundColor = highlightColor.cgColor

        return highlight
    }

    private func buildGlassView(size: NSSize) -> NSGlassEffectView {
        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))

        glass.style = .clear
        glass.cornerRadius = panelCornerRadius
        glass.tintColor = panelTintColor

        return glass
    }

    /// Centered in the band above the top row's icons, following the top edge as the panel resizes.
    private func buildWhitelistBadge(size: NSSize) -> WhitelistBadgeView {
        let badge = WhitelistBadgeView()
        let badgeSize = badge.frame.size

        badge.frame = alignToPixels(NSRect(
            x: (size.width - badgeSize.width) / 2,
            y: size.height - verticalPadding - nameBandHeight / 2 - badgeSize.height / 2,
            width: badgeSize.width,
            height: badgeSize.height
        ))
        badge.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]

        return badge
    }
}
