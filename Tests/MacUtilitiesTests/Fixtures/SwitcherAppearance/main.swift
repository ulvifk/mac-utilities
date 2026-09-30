import AppKit

func buildState(listingWindows: Bool, cardGlass: GlassStore?, selectedIndex: Int = 0) -> SwitcherState {
    return SwitcherState(
        apps: listingWindows ? [] : [NSRunningApplication(), NSRunningApplication()],
        windows: listingWindows ? [AppWindow(windowID: 1), AppWindow(windowID: 2)] : [],
        thumbnails: [:],
        isListingWindows: listingWindows,
        cardGlass: cardGlass,
        cellsPerRow: 2,
        selectedIndex: selectedIndex,
        isFiltered: false,
        isFilterEnabled: false,
        whitelisted: []
    )
}

func getCells(in container: NSView) -> [SwitcherCellView] {
    return container.subviews.compactMap { $0 as? SwitcherCellView }
}

func expectSameViews(panel: SwitcherPanel, container: NSView, cells: [SwitcherCellView]) {
    precondition((panel.contentView as! NSGlassEffectView).contentView === container, "Appearance change rebuilt content")
    let currentCells = getCells(in: container)
    precondition(currentCells.count == cells.count, "Appearance change changed the cells")
    for (current, original) in zip(currentCells, cells) {
        precondition(current === original, "Appearance change replaced a cell")
    }
}

for listingWindows in [false, true] {
    let panel = SwitcherPanel()
    let panelGlass = GlassStore()
    let cardGlass = GlassStore()
    let state = buildState(listingWindows: listingWindows, cardGlass: cardGlass)
    panel.show(state: state, glassStore: panelGlass)
    let glass = panel.contentView as! NSGlassEffectView
    let container = glass.contentView!
    let cells = getCells(in: container)
    precondition(cells.count == 2, "Panel did not build the initial cells")

    for step in 0..<20 {
        panelGlass.darkness = CGFloat(step) / 40
        panel.updateGlass(state: state, glassStore: panelGlass)

        precondition(panel.contentView === glass, "Darkness change replaced the glass")
        precondition(glass.tintColor!.alphaComponent == panelGlass.darkness, "Darkness change was not applied")
        expectSameViews(panel: panel, container: container, cells: cells)
    }
    print("PASS \(listingWindows ? "windows" : "apps")/darkness-reuses-all-views")

    for frosted in [true, false, true] {
        let previousGlass = panel.contentView!
        panelGlass.isFrosted = frosted
        panel.updateGlass(state: state, glassStore: panelGlass)

        precondition(panel.contentView !== previousGlass, "Frosted change did not refresh the effect wrapper")
        precondition(panel._hasActiveAppearance() == !frosted, "Frosted appearance did not change")
        precondition((panel.contentView as! NSGlassEffectView).tintColor!.alphaComponent == panelGlass.darkness, "Frosted change lost the tint")
        expectSameViews(panel: panel, container: container, cells: cells)
    }
    print("PASS \(listingWindows ? "windows" : "apps")/frosted-reuses-content-and-cells")
    panel.hide()
}

for listingWindows in [false, true] {
    let mode = listingWindows ? "windows" : "apps"
    let panel = SwitcherPanel()
    let panelGlass = GlassStore()
    let cardGlass = GlassStore()
    let state = buildState(listingWindows: listingWindows, cardGlass: cardGlass)
    panel.show(state: state, glassStore: panelGlass)
    let glass = panel.contentView!
    let container = (glass as! NSGlassEffectView).contentView!
    let cells = getCells(in: container)
    let cell = cells[0]
    let card = cell.card
    let blur = card.subviews[0] as! NSVisualEffectView
    let tint = card.subviews[1]
    let border = card.subviews[2]
    let imageView = cell.subviews[1] as! NSImageView
    let image = NSImage(size: NSSize(width: 32, height: 32))
    imageView.image = image
    precondition(card.frame == alignToPixels(listingWindows ? windowCardFrameInCell : iconCardFrameInCell), "Card does not frame its content")
    precondition(border.frame == card.bounds, "Card border did not resize with the card")

    for step in 0..<20 {
        cardGlass.darkness = CGFloat(step) / 40
        panel.updateGlass(state: state, glassStore: panelGlass)

        precondition(panel.contentView === glass, "Card darkness replaced panel glass")
        expectSameViews(panel: panel, container: container, cells: cells)
        precondition(cell.subviews[0] === card, "Card darkness replaced the card")
        precondition(card.subviews[1] === tint, "Card darkness replaced the tint")
        precondition(NSColor(cgColor: tint.layer!.backgroundColor!)!.alphaComponent == cardGlass.darkness, "Card darkness was not applied")
        precondition(imageView.image === image, "Card darkness lost the image")
        precondition(border.layer!.borderWidth == selectedCardBorderWidth, "Card darkness lost the selection")
    }
    print("PASS \(mode)/card-darkness-reuses-card-and-image")

    for frosted in [true, false, true] {
        cardGlass.isFrosted = frosted
        panel.updateGlass(state: state, glassStore: panelGlass)

        precondition(card.subviews[0] === blur, "Card look replaced the blur")
        precondition(blur.isHidden == !frosted, "Card look did not update the blur")
        precondition(blur.state == .active, "Card blur lost its active state")
        precondition(imageView.image === image, "Card look lost the image")
        expectSameViews(panel: panel, container: container, cells: cells)
    }
    print("PASS \(mode)/card-look-reuses-card-and-image")

    panel.updateGlass(state: buildState(listingWindows: listingWindows, cardGlass: nil), glassStore: panelGlass)
    precondition(card.isHidden, "Cards-off left the card visible")
    precondition(imageView.image === image, "Cards-off lost the image")
    panel.updateGlass(state: state, glassStore: panelGlass)
    precondition(!card.isHidden, "Cards-on did not show the card")
    precondition(imageView.image === image, "Cards-on lost the image")
    precondition(border.layer!.borderWidth == selectedCardBorderWidth, "Cards-on lost the selection")
    expectSameViews(panel: panel, container: container, cells: cells)
    print("PASS \(mode)/cards-toggle-reuses-cell-and-image")

    panel.update(state: buildState(listingWindows: listingWindows, cardGlass: cardGlass, selectedIndex: 1))
    precondition(border.layer!.borderWidth == cardBorderWidth, "Previous card kept the selected border")
    precondition(cells[1].card.subviews[2].layer!.borderWidth == selectedCardBorderWidth, "New selection did not get its border")
    print("PASS \(mode)/selection-moves-between-cards")
    panel.hide()
}

let panel = SwitcherPanel()
let panelGlass = GlassStore()
panel.show(state: buildState(listingWindows: true, cardGlass: nil), glassStore: panelGlass)
let container = (panel.contentView as! NSGlassEffectView).contentView!
panel.hide()
panel.show(state: buildState(listingWindows: false, cardGlass: nil), glassStore: panelGlass)
let appContainer = (panel.contentView as! NSGlassEffectView).contentView!
precondition(appContainer !== container, "New opening reused the old mode's content")
precondition(getCells(in: appContainer).allSatisfy { $0 is IconCellView }, "New opening kept window cells")
print("PASS new-opening/builds-new-mode-content")
panel.hide()
