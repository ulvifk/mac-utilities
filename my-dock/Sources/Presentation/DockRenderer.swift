import AppKit

final class DockRenderer {
    private let icons: DockIconCache

    init(icons: DockIconCache) {
        self.icons = icons
    }

    func draw(layout: DockLayout, hoveredIndex: Int?, draggedAppID: String?, preview: DockDropPreview?) {
        let bounds = NSRect(origin: .zero, size: layout.size)
        NSGraphicsContext.current!.imageInterpolation = .high
        drawBackground(bounds)
        for (index, cell) in layout.cells.enumerated() {
            NSGraphicsContext.saveGraphicsState()
            if let draggedAppID {
                if cell.item.app?.id == draggedAppID { NSGraphicsContext.current!.cgContext.setAlpha(0.3) }
            }
            drawItem(cell.item, cell: cell.frame, hovered: index == hoveredIndex)
            NSGraphicsContext.restoreGraphicsState()
        }
        if let preview { drawDropMarker(preview.marker) }
    }

    private func drawBackground(_ bounds: NSRect) {
        stripDimmingColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: stripCornerRadius - 1, yRadius: stripCornerRadius - 1).fill()
        NSColor.white.withAlphaComponent(0.24).setStroke()
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: stripCornerRadius, yRadius: stripCornerRadius)
        outline.lineWidth = 1
        outline.stroke()
    }

    private func drawItem(_ item: DockItem, cell: NSRect, hovered: Bool) {
        switch item {
        case .toggle(let slot): drawToggle(slot, cell: cell, hovered: hovered)
        case .separator: drawDividerLine(x: round(cell.midX), from: separatorVerticalInset, to: stripHeight - separatorVerticalInset)
        case .emptyGroup: drawEmptyGroup(cell)
        case .application(let tile):
            let rect = getIconFrame(cell)
            icons.getIcon(tile.app).draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            if let badge = tile.badge { drawBadge(badge, iconRect: rect) }
            if tile.isRunning { drawRunningDot(centerX: cell.midX) }
        case .trash:
            NSImage(named: NSImage.trashEmptyName)!.draw(in: getIconFrame(cell), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }

    private func getIconFrame(_ cell: NSRect) -> NSRect {
        return NSRect(x: cell.midX - iconSize / 2, y: iconTopInset, width: iconSize, height: iconSize)
    }

    private func drawDropMarker(_ marker: DropMarker) {
        switch marker {
        case .insertionLine(let x):
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: x - 1.5, y: 9, width: 3, height: 42), xRadius: 1.5, yRadius: 1.5).fill()
        case .groupHighlight(let rect):
            NSColor.controlAccentColor.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 5), xRadius: 8, yRadius: 8).fill()
        }
    }

    private func drawEmptyGroup(_ cell: NSRect) {
        let rect = cell.insetBy(dx: 6, dy: 10)
        NSColor.white.withAlphaComponent(0.3).setStroke()
        let outline = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        outline.setLineDash([3, 3], count: 2, phase: 0)
        outline.stroke()
        let plus = NSBezierPath()
        plus.move(to: NSPoint(x: cell.midX - 5, y: cell.midY))
        plus.line(to: NSPoint(x: cell.midX + 5, y: cell.midY))
        plus.move(to: NSPoint(x: cell.midX, y: cell.midY - 5))
        plus.line(to: NSPoint(x: cell.midX, y: cell.midY + 5))
        plus.stroke()
    }

    /// Red count on the icon's top-right corner like Apple's: a circle for short counts, a pill for longer ones.
    private func drawBadge(_ badge: String, iconRect: NSRect) {
        let textSize = (badge as NSString).size(withAttributes: badgeTextAttributes)
        let width = max(badgeHeight, ceil(textSize.width) + 2 * badgeHorizontalPadding)
        let rect = NSRect(x: iconRect.maxX - badgeInsetFromIconRight - width, y: iconRect.minY, width: width, height: badgeHeight)

        badgeColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2).fill()
        (badge as NSString).draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2), withAttributes: badgeTextAttributes)
    }

    /// Apple's Dock snaps the dot to whole pixels; a fractional center would smear a 4px circle over 5 columns.
    private func drawRunningDot(centerX: CGFloat) {
        let rect = NSRect(
            x: round(centerX) - runningDotDiameter / 2,
            y: stripHeight - runningDotCenterFromBottom - runningDotDiameter / 2,
            width: runningDotDiameter,
            height: runningDotDiameter
        )

        runningDotColor.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    /// Snapped to a whole column, so a fractional center does not smear the line over two columns.
    private func drawDividerLine(x: CGFloat, from top: CGFloat, to bottom: CGFloat) {
        separatorColor.setFill()
        NSRect(x: x, y: top, width: 1, height: bottom - top).fill()
    }

    /// Divider with the chevron in its gap; collapsed it also shows the hidden count and a dot when a hidden app has a badge.
    private func drawToggle(_ slot: ToggleSlot, cell: NSRect, hovered: Bool) {
        let lineX = round(cell.minX + toggleSlotWidth / 2)
        let centerY = iconTopInset + iconSize / 2

        if hovered { drawToggleHover(cell) }
        drawDividerLine(x: lineX, from: separatorVerticalInset, to: centerY - toggleGapHalfHeight)
        drawDividerLine(x: lineX, from: centerY + toggleGapHalfHeight, to: stripHeight - separatorVerticalInset)
        drawChevron(pointingRight: slot.isCollapsed, center: NSPoint(x: lineX + 0.5, y: centerY))
        if slot.isCollapsed { drawToggleCount(slot, x: lineX + 0.5 + chevronWidth / 2 + toggleCountGap, centerY: centerY) }
        if slot.hasBadge { drawToggleBadgeDot(cell) }
    }

    private func drawToggleHover(_ cell: NSRect) {
        let rect = cell.insetBy(dx: 1, dy: toggleHoverVerticalInset)

        toggleHoverColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: toggleHoverCornerRadius, yRadius: toggleHoverCornerRadius).fill()
    }

    private func drawChevron(pointingRight: Bool, center: NSPoint) {
        let direction: CGFloat = pointingRight ? 1 : -1
        let tipX = center.x + direction * chevronWidth / 2
        let baseX = center.x - direction * chevronWidth / 2

        let path = NSBezierPath()
        path.move(to: NSPoint(x: baseX, y: center.y - chevronHeight / 2))
        path.line(to: NSPoint(x: tipX, y: center.y))
        path.line(to: NSPoint(x: baseX, y: center.y + chevronHeight / 2))
        path.lineWidth = chevronLineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        chevronColor.setStroke()
        path.stroke()
    }

    private func drawToggleCount(_ slot: ToggleSlot, x: CGFloat, centerY: CGFloat) {
        let size = getToggleCountSize(slot)
        ("\(slot.hiddenCount)" as NSString).draw(at: NSPoint(x: x, y: centerY - size.height / 2), withAttributes: toggleCountAttributes)
    }

    private func drawToggleBadgeDot(_ cell: NSRect) {
        let rect = NSRect(x: cell.maxX - 3 - toggleBadgeDotDiameter, y: separatorVerticalInset, width: toggleBadgeDotDiameter, height: toggleBadgeDotDiameter)

        badgeColor.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

}
