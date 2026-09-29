import AppKit

func buildState(listingWindows: Bool, cardGlass: GlassStore?) -> SwitcherState {
    return SwitcherState(
        apps: listingWindows ? [] : [NSRunningApplication(), NSRunningApplication()],
        windows: listingWindows ? [AppWindow(windowID: 1), AppWindow(windowID: 2)] : [],
        thumbnails: [:],
        isListingWindows: listingWindows,
        windowCardGlass: cardGlass,
        cellsPerRow: 2,
        selectedIndex: 0,
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

let panel = SwitcherPanel()
let panelGlass = GlassStore()
let cardGlass = GlassStore()
let state = buildState(listingWindows: true, cardGlass: cardGlass)
panel.show(state: state, glassStore: panelGlass)
let glass = panel.contentView!
let container = (glass as! NSGlassEffectView).contentView!
let cells = getCells(in: container)
let cell = cells[0] as! WindowCellView
let card = cell.subviews[0]
let border = cell.subviews[1]
let thumbnail = cell.subviews[2] as! NSImageView
let blur = card.subviews[0] as! NSVisualEffectView
let tint = card.subviews[1]
let image = NSImage(size: NSSize(width: 32, height: 32))
cell.showThumbnail(image)

for step in 0..<20 {
    cardGlass.darkness = CGFloat(step) / 40
    panel.updateGlass(state: state, glassStore: panelGlass)

    precondition(panel.contentView === glass, "Card darkness replaced panel glass")
    expectSameViews(panel: panel, container: container, cells: cells)
    precondition(cell.subviews[0] === card, "Card darkness replaced the card")
    precondition(card.subviews[1] === tint, "Card darkness replaced the tint")
    precondition(NSColor(cgColor: tint.layer!.backgroundColor!)!.alphaComponent == cardGlass.darkness, "Card darkness was not applied")
    precondition(thumbnail.image === image, "Card darkness lost the captured thumbnail")
    precondition(border.layer!.borderWidth == selectedWindowCardBorderWidth, "Card darkness lost the selection")
}
print("PASS windows/card-darkness-reuses-card-and-thumbnail")

for frosted in [true, false, true] {
    cardGlass.isFrosted = frosted
    panel.updateGlass(state: state, glassStore: panelGlass)

    precondition(card.subviews[0] === blur, "Card look replaced the blur")
    precondition(blur.isHidden == !frosted, "Card look did not update the blur")
    precondition(blur.state == .active, "Card blur lost its active state")
    precondition(thumbnail.image === image, "Card look lost the thumbnail")
    expectSameViews(panel: panel, container: container, cells: cells)
}
print("PASS windows/card-look-reuses-card-and-thumbnail")

panel.updateGlass(state: buildState(listingWindows: true, cardGlass: nil), glassStore: panelGlass)
precondition(card.isHidden, "Cards-off left the fill visible")
precondition(border.isHidden, "Cards-off left the border visible")
precondition(thumbnail.image === image, "Cards-off lost the thumbnail")
panel.updateGlass(state: state, glassStore: panelGlass)
precondition(!card.isHidden, "Cards-on did not show the fill")
precondition(!border.isHidden, "Cards-on did not show the border")
precondition(thumbnail.image === image, "Cards-on lost the thumbnail")
precondition(border.layer!.borderWidth == selectedWindowCardBorderWidth, "Cards-on lost the selection")
expectSameViews(panel: panel, container: container, cells: cells)
print("PASS windows/cards-toggle-reuses-cell-and-thumbnail")

panel.hide()
panel.show(state: buildState(listingWindows: false, cardGlass: nil), glassStore: panelGlass)
let appContainer = (panel.contentView as! NSGlassEffectView).contentView!
precondition(appContainer !== container, "New opening reused the old mode's content")
precondition(getCells(in: appContainer).allSatisfy { $0 is IconCellView }, "New opening kept window cells")
print("PASS new-opening/builds-new-mode-content")
panel.hide()
