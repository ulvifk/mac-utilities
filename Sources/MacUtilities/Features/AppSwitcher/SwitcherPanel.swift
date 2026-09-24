import AppKit
import QuartzCore

final class SwitcherPanel: NSPanel {
    var onCellClicked: (Int) -> Void = { _ in }

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
            cell.icon.alphaValue = getIconAlpha(app: app)
            cell.dot.isHidden = !state.whitelisted.contains(app.bundleIdentifier ?? "")
        }

        nameLabel.stringValue = getSelectedName()
        nameLabel.frame = getNameFrame(layout: layout)
        highlight.layer?.backgroundColor = getHighlightColor().cgColor

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
            animator().setFrame(getFrameKeepingCenter(contentSize: layout.contentSize), display: true)
            highlight.animator().frame = layout.getHighlightFrame(index: state.selectedIndex)
            nameLabel.animator().frame = getNameFrame(layout: layout)

            for (index, cell) in cells.enumerated() {
                cell.animator().frame = layout.cellFrames[index]
            }
        }, completionHandler: {
            cell.removeFromSuperview()
        })
    }

    func hide() {
        orderOut(nil)
    }

    private func buildContent() {
        let layout = buildLayout()
        let container = NSView(frame: NSRect(origin: .zero, size: layout.contentSize))
        let rim = RimView(frame: container.bounds)

        // Icons draw as aqua like my-dock's tiles, so system images keep their light variants on the dark glass.
        container.appearance = NSAppearance(named: .aqua)
        rim.autoresizingMask = [.width, .height]
        highlight = buildHighlight()
        nameLabel = buildNameLabel(text: getSelectedName())
        cells = buildCells(layout: layout)

        container.addSubview(buildDimmingView(size: layout.contentSize))
        container.addSubview(rim)
        container.addSubview(highlight)
        for cell in cells {
            container.addSubview(cell)
        }
        container.addSubview(nameLabel)

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
            let cell = IconCellView(app: app, whitelisted: state.whitelisted.contains(app.bundleIdentifier ?? ""))

            cell.index = index
            cell.frame = layout.cellFrames[index]
            cell.onClick = { [unowned self] index in self.onCellClicked(index) }
            cells.append(cell)
        }

        return cells
    }

    private func buildLayout() -> SwitcherLayout {
        return SwitcherLayout(appCount: state.apps.count, iconsPerRow: state.iconsPerRow)
    }

    private func getSelectedName() -> String {
        return state.apps[state.selectedIndex].localizedName ?? ""
    }

    /// The panel shrinks around its middle, so the icons on both sides of the gap close it together.
    private func getFrameKeepingCenter(contentSize: NSSize) -> NSRect {
        return alignToPixels(NSRect(
            x: frame.midX - contentSize.width / 2,
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
        highlight.layer?.backgroundColor = getHighlightColor().cgColor

        return highlight
    }

    private func buildGlassView(size: NSSize) -> NSGlassEffectView {
        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))

        glass.style = .clear
        glass.cornerRadius = panelCornerRadius

        return glass
    }

    private func buildDimmingView(size: NSSize) -> NSView {
        let dimming = NSView(frame: NSRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1))

        dimming.wantsLayer = true
        dimming.layer?.cornerRadius = panelCornerRadius - 1
        dimming.layer?.backgroundColor = panelDimmingColor.cgColor
        dimming.autoresizingMask = [.width, .height]

        return dimming
    }

    private func getHighlightColor() -> NSColor {
        if state.filterEnabled { return filteredHighlightColor }
        return highlightColor
    }
}
