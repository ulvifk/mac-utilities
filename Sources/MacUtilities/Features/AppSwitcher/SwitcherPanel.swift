import AppKit
import QuartzCore

final class SwitcherPanel: NSPanel {
    var onCellClicked: (Int) -> Void = { _ in }
    /// The width the edge drag asks for, before clamping.
    var onWidthDragged: (CGFloat) -> Void = { _ in }

    /// The last state shown.
    private var state: SwitcherState!
    private var cells: [IconCellView] = []
    private var highlight = NSGlassEffectView()
    private var nameCapsule = NSGlassEffectView()
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
        contentView!.layer!.add(buildOpeningAnimation(), forKey: nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            animator().alphaValue = 1
        }
    }

    func update(state: SwitcherState) {
        let previousIndex = self.state.selectedIndex
        self.state = state
        let layout = buildLayout()

        for (cell, app) in zip(cells, state.apps) {
            cell.showStatus(app: app, whitelisted: isWhitelisted(app), isFiltered: state.isFiltered)
        }

        nameLabel.stringValue = getSelectedName()
        placeName(capsuleFrame: getNameCapsuleFrame(layout: layout))

        NSAnimationContext.runAnimationGroup { context in
            context.duration = highlightSettleDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)

            for (index, cell) in cells.enumerated() {
                cell.icon.animator().frame = getIconFrameInCell(index: index)
            }
        }
        moveHighlight(from: layout.getHighlightFrame(index: previousIndex), to: layout.getHighlightFrame(index: state.selectedIndex))
    }

    /// Fades and shrinks the leaving icon out while the rest slide into place and the panel shrinks around them.
    func removeApp(at index: Int, state: SwitcherState) {
        self.state = state
        let layout = buildLayout()
        let cell = cells.remove(at: index)

        cell.onClick = { _ in }
        for later in cells[index...] { later.index -= 1 }
        nameLabel.stringValue = getSelectedName()

        let nameCapsuleFrame = getNameCapsuleFrame(layout: layout)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = removalDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            cell.animator().alphaValue = 0
            cell.icon.animator().frame = cell.icon.frame.insetBy(dx: leavingIconShrink, dy: leavingIconShrink)
            animator().setFrame(getFrame(centeredOnX: frame.midX, contentSize: layout.contentSize), display: true)
            highlight.animator().frame = layout.getHighlightFrame(index: state.selectedIndex)
            nameCapsule.animator().frame = nameCapsuleFrame

            for (index, cell) in cells.enumerated() {
                cell.animator().frame = layout.cellFrames[index]
                cell.icon.animator().frame = getIconFrameInCell(index: index)
            }
        }, completionHandler: {
            cell.removeFromSuperview()
        })
        nameLabel.frame = getNameLabelFrame(capsuleFrame: nameCapsuleFrame)
    }

    /// Re-wraps the icons to the state's row width without animation, so they follow the edge drag live; the panel stays centered.
    func resize(state: SwitcherState) {
        self.state = state
        let layout = buildLayout()

        for (cell, frame) in zip(cells, layout.cellFrames) {
            cell.frame = frame
        }
        highlight.frame = layout.getHighlightFrame(index: state.selectedIndex)
        placeName(capsuleFrame: getNameCapsuleFrame(layout: layout))
        setFrame(getFrame(centeredOnX: screen!.visibleFrame.midX, contentSize: layout.contentSize), display: true)
    }

    func hide() {
        orderOut(nil)
    }

    /// The glass sits inside a window larger by the shadow margin on every side, over the shadow it casts.
    private func buildContent() {
        let layout = buildLayout()
        let windowSize = getWindowSize(contentSize: layout.contentSize)
        let glassFrame = NSRect(origin: NSPoint(x: shadowMargin, y: shadowMargin), size: layout.contentSize)
        let container = NSView(frame: NSRect(origin: .zero, size: layout.contentSize))
        let glass = buildGlassView(frame: glassFrame)
        let shadow = PanelShadowView()
        let root = NSView(frame: NSRect(origin: .zero, size: windowSize))

        // Icons draw as aqua like my-dock's tiles, so system images keep their light variants on the dark glass.
        container.appearance = NSAppearance(named: .aqua)
        highlight = buildHighlight()
        nameLabel = buildNameLabel(text: getSelectedName())
        nameCapsule = buildNameCapsule(label: nameLabel)
        cells = buildCells(layout: layout)

        container.addSubview(highlight)
        if state.isFiltered {
            container.addSubview(buildWhitelistBadge(size: layout.contentSize))
        }
        for cell in cells {
            container.addSubview(cell)
        }
        container.addSubview(nameCapsule)
        for handle in buildResizeHandles(size: layout.contentSize) {
            container.addSubview(handle)
        }

        highlight.frame = layout.getHighlightFrame(index: state.selectedIndex)
        placeName(capsuleFrame: getNameCapsuleFrame(layout: layout))

        glass.contentView = container
        shadow.frame = glassFrame
        shadow.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.addSubview(shadow)
        root.addSubview(glass)

        contentView = root
        setContentSize(windowSize)
    }

    private func buildCells(layout: SwitcherLayout) -> [IconCellView] {
        var cells: [IconCellView] = []

        for (index, app) in state.apps.enumerated() {
            let cell = IconCellView(app: app)

            cell.showStatus(app: app, whitelisted: isWhitelisted(app), isFiltered: state.isFiltered)
            cell.icon.frame = getIconFrameInCell(index: index)
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

    /// To a neighbouring icon the highlight stretches over both first and then lets go of the old one, like a drop of liquid; further away it
    /// just slides.
    private func moveHighlight(from previousFrame: NSRect, to frame: NSRect) {
        if !areNeighbours(previousFrame, frame) {
            slideHighlight(to: frame)
            return
        }

        let stretchedFrame = previousFrame.union(frame)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = highlightStretchDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            highlight.animator().frame = stretchedFrame
        }, completionHandler: {
            // A later move, removal or resize has taken the highlight elsewhere meanwhile.
            if self.highlight.frame != stretchedFrame { return }

            self.slideHighlight(to: frame)
        })
    }

    private func slideHighlight(to frame: NSRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = highlightSettleDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            highlight.animator().frame = frame
        }
    }

    /// At most one icon apart sideways and one row up or down; the half step of slack absorbs the pixel rounding and the half-column shift
    /// of a shorter last row.
    private func areNeighbours(_ frame: NSRect, _ otherFrame: NSRect) -> Bool {
        if abs(frame.midX - otherFrame.midX) > 1.5 * (iconSize + itemSpacing) { return false }
        if abs(frame.midY - otherFrame.midY) > 1.5 * (cellHeight + rowSpacing) { return false }
        return true
    }

    /// From slightly smaller around the middle up to full size, springing a little past it.
    private func buildOpeningAnimation() -> CASpringAnimation {
        let layer = contentView!.layer!
        let center = CGPoint(x: layer.bounds.width * (0.5 - layer.anchorPoint.x), y: layer.bounds.height * (0.5 - layer.anchorPoint.y))
        let shrink = CATransform3DScale(
            CATransform3DMakeTranslation(center.x * (1 - openingScale), center.y * (1 - openingScale), 0),
            openingScale,
            openingScale,
            1
        )
        let animation = CASpringAnimation(perceptualDuration: openingDuration, bounce: openingBounce)

        animation.keyPath = "transform"
        animation.fromValue = shrink
        animation.toValue = CATransform3DIdentity
        animation.duration = animation.settlingDuration

        return animation
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

    private func getIconFrameInCell(index: Int) -> NSRect {
        if index == state.selectedIndex { return alignToPixels(selectedIconFrameInCell) }
        return alignToPixels(iconFrameInCell)
    }

    /// At the panel's current height. Removal shrinks around the panel's own middle; a resize centers on the screen instead, because keeping the
    /// current center would drift half a pixel every other snap as the widths alternate between odd and even.
    private func getFrame(centeredOnX centerX: CGFloat, contentSize: NSSize) -> NSRect {
        let windowSize = getWindowSize(contentSize: contentSize)

        return alignToPixels(NSRect(
            x: centerX - windowSize.width / 2,
            y: frame.midY - windowSize.height / 2,
            width: windowSize.width,
            height: windowSize.height
        ))
    }

    /// The glass plus room for its shadow on every side.
    private func getWindowSize(contentSize: NSSize) -> NSSize {
        return NSSize(width: contentSize.width + 2 * shadowMargin, height: contentSize.height + 2 * shadowMargin)
    }

    /// Hugs the name centered under the selected icon, no wider than twice the run to the nearer panel edge, so the name truncates instead
    /// of crossing it.
    private func getNameCapsuleFrame(layout: SwitcherLayout) -> NSRect {
        let iconFrame = layout.getIconFrame(index: state.selectedIndex)
        let maxWidth = 2 * min(iconFrame.midX - horizontalPadding, layout.contentSize.width - horizontalPadding - iconFrame.midX)
        let nameSize = nameLabel.fittingSize
        let width = min(nameSize.width + 2 * nameCapsuleHorizontalPadding, maxWidth)

        return alignToPixels(NSRect(
            x: iconFrame.midX - width / 2,
            y: iconFrame.minY - nameTopSpacing - nameSize.height - nameCapsuleVerticalPadding,
            width: width,
            height: nameSize.height + 2 * nameCapsuleVerticalPadding
        ))
    }

    private func getNameLabelFrame(capsuleFrame: NSRect) -> NSRect {
        return NSRect(origin: .zero, size: capsuleFrame.size).insetBy(dx: nameCapsuleHorizontalPadding, dy: nameCapsuleVerticalPadding)
    }

    private func placeName(capsuleFrame: NSRect) {
        nameCapsule.frame = capsuleFrame
        nameLabel.frame = getNameLabelFrame(capsuleFrame: capsuleFrame)
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

    private func buildNameCapsule(label: NSTextField) -> NSGlassEffectView {
        let capsule = NSGlassEffectView()
        let content = NSView()

        content.addSubview(label)
        capsule.contentView = content
        capsule.appearance = NSAppearance(named: .darkAqua)
        capsule.cornerRadius = nameBandHeight / 2 + nameCapsuleVerticalPadding
        capsule.tintColor = nameCapsuleTintColor

        return capsule
    }

    private func buildHighlight() -> NSGlassEffectView {
        let highlight = NSGlassEffectView()

        highlight.style = .clear
        highlight.cornerRadius = highlightCornerRadius
        highlight.tintColor = highlightColor

        return highlight
    }

    private func buildGlassView(frame: NSRect) -> NSGlassEffectView {
        let glass = NSGlassEffectView(frame: frame)

        glass.style = .clear
        glass.cornerRadius = panelCornerRadius
        glass.tintColor = panelTintColor
        glass.autoresizingMask = [.width, .height]

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
