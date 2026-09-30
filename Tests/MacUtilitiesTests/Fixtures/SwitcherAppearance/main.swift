import AppKit

_ = NSApplication.shared.setActivationPolicy(.prohibited)

func buildState(listingWindows: Bool, cardGlass: GlassStore?, selectedIndex: Int = 0, itemCount: Int = 2) -> SwitcherState {
    return SwitcherState(
        apps: listingWindows ? [] : (0..<itemCount).map { _ in NSRunningApplication() },
        windows: listingWindows ? (0..<itemCount).map { AppWindow(windowID: CGWindowID($0 + 1)) } : [],
        thumbnails: [:],
        isListingWindows: listingWindows,
        cardGlass: cardGlass,
        cellsPerRow: itemCount,
        selectedIndex: selectedIndex,
        isFiltered: false,
        isFilterEnabled: false,
        dimHiddenApps: true,
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

var dimmingState = buildState(listingWindows: false, cardGlass: nil)
dimmingState.apps[0].isHidden = true
panel.show(state: dimmingState, glassStore: panelGlass)
let dimmingContainer = (panel.contentView as! NSGlassEffectView).contentView!
let dimmingCells = getCells(in: dimmingContainer)
let hiddenCell = dimmingCells[0] as! IconCellView
let visibleCell = dimmingCells[1] as! IconCellView
precondition(hiddenCell.icon.alphaValue == 0.4, "Hidden icon did not start dimmed")

for dimHiddenApps in [false, true, false] {
    dimmingState = SwitcherState(apps: dimmingState.apps, windows: [], thumbnails: [:], isListingWindows: false,
                                cardGlass: nil, cellsPerRow: 2, selectedIndex: 0, isFiltered: false,
                                isFilterEnabled: false, dimHiddenApps: dimHiddenApps, whitelisted: ["test.app"])
    panel.updateGlass(state: dimmingState, glassStore: panelGlass)
    precondition(hiddenCell.icon.alphaValue == (dimHiddenApps ? 0.4 : 1), "Appearance change did not refresh hidden icon opacity")
    precondition(visibleCell.icon.alphaValue == 1, "Appearance change dimmed a visible app")
    precondition(!hiddenCell.dot.isHidden, "Appearance change lost the whitelist marker")
    expectSameViews(panel: panel, container: dimmingContainer, cells: dimmingCells)
}
panel.hide()
print("PASS appearance/dimming-refreshes-existing-icons")

struct PreviewPlacementScenario {
    let name: String
    let settingsFrame: NSRect
    let screenFrame: NSRect
    let expectedOrigin: NSPoint
}

let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
let placementScenarios = [
    PreviewPlacementScenario(name: "right", settingsFrame: NSRect(x: 360, y: 180, width: 720, height: 540),
                             screenFrame: screenFrame, expectedOrigin: NSPoint(x: 1092, y: 400)),
    PreviewPlacementScenario(name: "left", settingsFrame: NSRect(x: 1000, y: 180, width: 400, height: 540),
                             screenFrame: screenFrame, expectedOrigin: NSPoint(x: 788, y: 400)),
    PreviewPlacementScenario(name: "below", settingsFrame: NSRect(x: 100, y: 500, width: 1240, height: 300),
                             screenFrame: screenFrame, expectedOrigin: NSPoint(x: 620, y: 388)),
    PreviewPlacementScenario(name: "above", settingsFrame: NSRect(x: 100, y: 100, width: 1240, height: 400),
                             screenFrame: screenFrame, expectedOrigin: NSPoint(x: 620, y: 512)),
    PreviewPlacementScenario(name: "clamp-vertical", settingsFrame: NSRect(x: 360, y: 850, width: 720, height: 300),
                             screenFrame: screenFrame, expectedOrigin: NSPoint(x: 1092, y: 800)),
    PreviewPlacementScenario(name: "clamp-horizontal", settingsFrame: NSRect(x: -3000, y: 500, width: 4440, height: 300),
                             screenFrame: screenFrame, expectedOrigin: NSPoint(x: 0, y: 388)),
    PreviewPlacementScenario(name: "nonzero-screen-origin", settingsFrame: NSRect(x: -1240, y: 380, width: 720, height: 540),
                             screenFrame: NSRect(x: -1600, y: 200, width: 1440, height: 900), expectedOrigin: NSPoint(x: -508, y: 600)),
    PreviewPlacementScenario(name: "no-exterior-space", settingsFrame: screenFrame,
                             screenFrame: screenFrame, expectedOrigin: screenFrame.origin),
]

for scenario in placementScenarios {
    let frame = getPreviewFrame(contentSize: NSSize(width: 200, height: 100), settingsFrame: scenario.settingsFrame,
                                screenFrame: scenario.screenFrame)
    precondition(frame.origin == scenario.expectedOrigin, "Wrong preview position for \(scenario.name): \(frame)")
    precondition(scenario.screenFrame.contains(frame), "Preview escaped the visible screen for \(scenario.name)")
    if scenario.name != "no-exterior-space" {
        precondition(!frame.intersects(scenario.settingsFrame), "Preview covered settings for \(scenario.name)")
    }
    print("PASS preview-placement/\(scenario.name)")
}

let settingsWindow = NSWindow(contentRect: NSRect(x: 360, y: 180, width: 720, height: 540),
                              styleMask: .titled, backing: .buffered, defer: false)
for listingWindows in [false, true] {
    let previewPanel = SwitcherPanel()
    let state = buildState(listingWindows: listingWindows, cardGlass: GlassStore(), itemCount: listingWindows ? 1 : 2)
    previewPanel.show(state: state, glassStore: GlassStore(), beside: settingsWindow)
    precondition(!previewPanel.frame.intersects(settingsWindow.frame), "Native preview covered settings controls")
    let previewContainer = (previewPanel.contentView as! NSGlassEffectView).contentView!
    let cells = getCells(in: previewContainer)
    let originalSize = previewPanel.frame.size

    settingsWindow.setFrameOrigin(NSPoint(x: 600, y: 100))
    previewPanel.positionPreview(beside: settingsWindow)
    let expectedFrame = getPreviewFrame(contentSize: originalSize, settingsFrame: settingsWindow.frame,
                                        screenFrame: settingsWindow.screen!.visibleFrame)
    let pixel = 1 / settingsWindow.screen!.backingScaleFactor
    precondition(abs(previewPanel.frame.minX - expectedFrame.minX) <= pixel, "Native preview did not follow settings horizontally")
    precondition(abs(previewPanel.frame.minY - expectedFrame.minY) <= pixel, "Native preview did not follow settings vertically")
    precondition(!previewPanel.frame.intersects(settingsWindow.frame), "Moved native preview covered settings controls")
    precondition(previewPanel.frame.size == originalSize, "Repositioning changed preview size")
    expectSameViews(panel: previewPanel, container: previewContainer, cells: cells)
    precondition(!settingsWindow.isVisible, "Placement tests presented a settings window")
    previewPanel.hide()
    print("PASS preview-placement/native-\(listingWindows ? "windows" : "apps")-reuses-views")
}

let visibleFrame = settingsWindow.screen!.visibleFrame
for listingWindows in [false, true] {
    for placement in ["fullscreen", "above"] {
        let settingsFrame = placement == "fullscreen" ? visibleFrame : NSRect(
            x: visibleFrame.minX, y: visibleFrame.minY + 100,
            width: visibleFrame.width, height: visibleFrame.height / 3
        )
        settingsWindow.setFrame(settingsFrame, display: false)
        let previewPanel = SwitcherPanel()
        previewPanel.show(state: buildState(listingWindows: listingWindows, cardGlass: nil, itemCount: 2),
                          glassStore: GlassStore(), beside: settingsWindow)
        let frame = previewPanel.frame
        let container = (previewPanel.contentView as! NSGlassEffectView).contentView!
        let hintBand = container.subviews.first { $0 is HintBandView }!
        precondition(container.bounds.contains(hintBand.frame), "Preview did not reserve the hint band before placement")

        RunLoop.current.run(until: Date(timeIntervalSinceNow: hintDelay + hintFadeDuration + 0.1))
        precondition(previewPanel.frame == frame, "Preview grew after being positioned")
        precondition(visibleFrame.contains(previewPanel.frame), "Preview hints extended below the visible screen")
        if placement == "above" {
            precondition(!previewPanel.frame.intersects(settingsWindow.frame), "Preview hints overlapped settings")
        }
        previewPanel.hide()
        print("PASS preview-placement/\(listingWindows ? "windows" : "apps")-\(placement)-includes-hints")
    }
}
