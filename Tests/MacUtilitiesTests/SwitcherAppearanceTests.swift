import AppKit
import Testing
@testable import MacUtilities

/// The panel's real views, drawn into SwitcherPanelContent without a window: look changes reuse the content, cells and images, and the preview
/// is placed beside the settings window at its final size. No window is ordered onto the screen.
@MainActor @Suite(.serialized)
final class SwitcherAppearanceTests {
    struct PlacementScenario: CustomTestStringConvertible, Sendable {
        let name: String
        let settingsFrame: NSRect
        let screenFrame: NSRect
        let expectedOrigin: NSPoint

        var testDescription: String { name }
    }

    nonisolated static let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    nonisolated static let placementScenarios = [
        PlacementScenario(name: "right", settingsFrame: NSRect(x: 360, y: 180, width: 720, height: 540),
                          screenFrame: screenFrame, expectedOrigin: NSPoint(x: 1092, y: 400)),
        PlacementScenario(name: "left", settingsFrame: NSRect(x: 1000, y: 180, width: 400, height: 540),
                          screenFrame: screenFrame, expectedOrigin: NSPoint(x: 788, y: 400)),
        PlacementScenario(name: "below", settingsFrame: NSRect(x: 100, y: 500, width: 1240, height: 300),
                          screenFrame: screenFrame, expectedOrigin: NSPoint(x: 620, y: 388)),
        PlacementScenario(name: "above", settingsFrame: NSRect(x: 100, y: 100, width: 1240, height: 400),
                          screenFrame: screenFrame, expectedOrigin: NSPoint(x: 620, y: 512)),
        PlacementScenario(name: "clamp-vertical", settingsFrame: NSRect(x: 360, y: 850, width: 720, height: 300),
                          screenFrame: screenFrame, expectedOrigin: NSPoint(x: 1092, y: 800)),
        PlacementScenario(name: "clamp-horizontal", settingsFrame: NSRect(x: -3000, y: 500, width: 4440, height: 300),
                          screenFrame: screenFrame, expectedOrigin: NSPoint(x: 0, y: 388)),
        PlacementScenario(name: "nonzero-screen-origin", settingsFrame: NSRect(x: -1240, y: 380, width: 720, height: 540),
                          screenFrame: NSRect(x: -1600, y: 200, width: 1440, height: 900), expectedOrigin: NSPoint(x: -508, y: 600)),
        PlacementScenario(name: "no-exterior-space", settingsFrame: screenFrame,
                          screenFrame: screenFrame, expectedOrigin: screenFrame.origin),
    ]

    private let defaults = TestDefaults()
    private let workspace = SwitcherFakeWorkspace(itemCount: 0)
    private let panelGlass: GlassStore
    private let cardGlass: GlassStore

    init() {
        _ = NSApplication.shared.setActivationPolicy(.prohibited)
        panelGlass = GlassStore(keyPrefix: "panelGlass", defaultDarkness: defaultGlassDarkness, defaults: defaults.buildUserDefaults())
        cardGlass = GlassStore(keyPrefix: "cardGlass", defaultDarkness: defaultCardDarkness, defaults: defaults.buildUserDefaults())
    }

    deinit {
        defaults.remove()
    }

    // MARK: glass

    @Test(arguments: [false, true])
    func darknessReusesAllViews(listingWindows: Bool) {
        let content = SwitcherPanelContent()
        let state = buildState(listingWindows: listingWindows, cardGlass: cardGlass)
        content.rebuild(state: state, glassStore: panelGlass, showsHintsAtOnce: false)
        let glass = content.glass!
        let container = glass.contentView!
        let cells = getCells(in: container)
        #expect(cells.count == 2, "Panel did not build the initial cells")

        for step in 0..<20 {
            panelGlass.setDarkness(CGFloat(step) / 40)
            content.updateGlass(state: state, glassStore: panelGlass)

            #expect(content.glass === glass, "Darkness change replaced the glass")
            #expect(glass.tintColor!.alphaComponent == panelGlass.darkness, "Darkness change was not applied")
            expectSameViews(content: content, container: container, cells: cells)
        }
    }

    /// The panel answers _hasActiveAppearance with the content's isFrosted negated.
    @Test(arguments: [false, true])
    func frostedReusesContentAndCells(listingWindows: Bool) {
        let content = SwitcherPanelContent()
        let state = buildState(listingWindows: listingWindows, cardGlass: cardGlass)
        content.rebuild(state: state, glassStore: panelGlass, showsHintsAtOnce: false)
        let container = content.glass.contentView!
        let cells = getCells(in: container)

        for frosted in [true, false, true] {
            let previousGlass = content.glass!
            panelGlass.setFrosted(frosted)
            content.updateGlass(state: state, glassStore: panelGlass)

            #expect(content.glass !== previousGlass, "Frosted change did not refresh the effect wrapper")
            #expect(content.isFrosted == frosted, "Frosted appearance did not change")
            #expect(content.glass.tintColor!.alphaComponent == panelGlass.darkness, "Frosted change lost the tint")
            expectSameViews(content: content, container: container, cells: cells)
        }
    }

    // MARK: cards

    @Test(arguments: [false, true])
    func cardDarknessReusesCardAndImage(listingWindows: Bool) {
        let cardViews = buildCardViews(listingWindows: listingWindows)
        let content = cardViews.content

        for step in 0..<20 {
            cardGlass.setDarkness(CGFloat(step) / 40)
            content.updateGlass(state: cardViews.state, glassStore: panelGlass)

            #expect(content.glass === cardViews.glass, "Card darkness replaced panel glass")
            expectSameViews(content: content, container: cardViews.container, cells: cardViews.cells)
            #expect(cardViews.cell.subviews[0] === cardViews.card, "Card darkness replaced the card")
            #expect(cardViews.card.subviews[1] === cardViews.tint, "Card darkness replaced the tint")
            #expect(NSColor(cgColor: cardViews.tint.layer!.backgroundColor!)!.alphaComponent == cardGlass.darkness, "Card darkness was not applied")
            #expect(cardViews.imageView.image === cardViews.image, "Card darkness lost the image")
            #expect(cardViews.border.layer!.borderWidth == selectedCardBorderWidth, "Card darkness lost the selection")
        }
    }

    @Test(arguments: [false, true])
    func cardLookReusesCardAndImage(listingWindows: Bool) {
        let cardViews = buildCardViews(listingWindows: listingWindows)

        for frosted in [true, false, true] {
            cardGlass.setFrosted(frosted)
            cardViews.content.updateGlass(state: cardViews.state, glassStore: panelGlass)

            #expect(cardViews.card.subviews[0] === cardViews.blur, "Card look replaced the blur")
            #expect(cardViews.blur.isHidden == !frosted, "Card look did not update the blur")
            #expect(cardViews.blur.state == .active, "Card blur lost its active state")
            #expect(cardViews.imageView.image === cardViews.image, "Card look lost the image")
            expectSameViews(content: cardViews.content, container: cardViews.container, cells: cardViews.cells)
        }
    }

    @Test(arguments: [false, true])
    func cardsToggleReusesCellAndImage(listingWindows: Bool) {
        let cardViews = buildCardViews(listingWindows: listingWindows)
        let content = cardViews.content

        content.updateGlass(state: buildState(listingWindows: listingWindows, cardGlass: nil), glassStore: panelGlass)
        #expect(cardViews.card.isHidden, "Cards-off left the card visible")
        #expect(cardViews.imageView.image === cardViews.image, "Cards-off lost the image")

        content.updateGlass(state: cardViews.state, glassStore: panelGlass)
        #expect(!cardViews.card.isHidden, "Cards-on did not show the card")
        #expect(cardViews.imageView.image === cardViews.image, "Cards-on lost the image")
        #expect(cardViews.border.layer!.borderWidth == selectedCardBorderWidth, "Cards-on lost the selection")
        expectSameViews(content: content, container: cardViews.container, cells: cardViews.cells)
    }

    @Test(arguments: [false, true])
    func selectionMovesBetweenCards(listingWindows: Bool) {
        let cardViews = buildCardViews(listingWindows: listingWindows)

        cardViews.content.update(state: buildState(listingWindows: listingWindows, cardGlass: cardGlass, selectedIndex: 1))

        #expect(cardViews.border.layer!.borderWidth == cardBorderWidth, "Previous card kept the selected border")
        #expect(cardViews.cells[1].card.subviews[2].layer!.borderWidth == selectedCardBorderWidth, "New selection did not get its border")
    }

    // MARK: openings

    @Test
    func newOpeningBuildsNewModeContent() {
        let content = SwitcherPanelContent()

        content.rebuild(state: buildState(listingWindows: true, cardGlass: nil), glassStore: panelGlass, showsHintsAtOnce: false)
        let windowContainer = content.glass.contentView!
        content.hideHintBand()
        content.rebuild(state: buildState(listingWindows: false, cardGlass: nil), glassStore: panelGlass, showsHintsAtOnce: false)
        let appContainer = content.glass.contentView!

        #expect(appContainer !== windowContainer, "New opening reused the old mode's content")
        #expect(getCells(in: appContainer).allSatisfy { $0 is IconCellView }, "New opening kept window cells")
    }

    @Test
    func dimmingRefreshesExistingIcons() {
        let apps = [workspace.buildApp(index: 0), workspace.buildApp(index: 1)]
        apps[0].isHidden = true
        let content = SwitcherPanelContent()
        content.rebuild(state: buildState(apps: apps, dimHiddenApps: true, whitelisted: []), glassStore: panelGlass, showsHintsAtOnce: false)
        let container = content.glass.contentView!
        let cells = getCells(in: container)
        let hiddenCell = cells[0] as! IconCellView
        let visibleCell = cells[1] as! IconCellView
        #expect(hiddenCell.icon.alphaValue == 0.4, "Hidden icon did not start dimmed")

        for dimHiddenApps in [false, true, false] {
            let state = buildState(apps: apps, dimHiddenApps: dimHiddenApps, whitelisted: Set(apps.map { $0.bundleIdentifier }))
            content.updateGlass(state: state, glassStore: panelGlass)

            #expect(hiddenCell.icon.alphaValue == (dimHiddenApps ? 0.4 : 1), "Appearance change did not refresh hidden icon opacity")
            #expect(visibleCell.icon.alphaValue == 1, "Appearance change dimmed a visible app")
            #expect(!hiddenCell.dot.isHidden, "Appearance change lost the whitelist marker")
            expectSameViews(content: content, container: container, cells: cells)
        }
    }

    // MARK: preview placement

    @Test(arguments: placementScenarios)
    func previewPlacement(_ scenario: PlacementScenario) {
        let frame = getPreviewFrame(contentSize: NSSize(width: 200, height: 100), settingsFrame: scenario.settingsFrame, screenFrame: scenario.screenFrame)

        #expect(frame.origin == scenario.expectedOrigin, "Wrong preview position")
        #expect(scenario.screenFrame.contains(frame), "Preview escaped the visible screen")
        if scenario.name != "no-exterior-space" {
            #expect(!frame.intersects(scenario.settingsFrame), "Preview covered settings")
        }
    }

    /// The panel sized to the content as showPreview sizes it, never ordered in; positioning only sets the panel's frame, so the content's
    /// views are left as they are.
    @Test(arguments: [false, true])
    func previewPanelFollowsSettings(listingWindows: Bool) {
        let settingsWindow = buildSettingsWindow()
        let content = SwitcherPanelContent()
        content.rebuild(state: buildState(listingWindows: listingWindows, cardGlass: cardGlass, itemCount: listingWindows ? 1 : 2), glassStore: panelGlass,
                        showsHintsAtOnce: true)
        let previewPanel = GlassSwitcherPanel()
        previewPanel.setContentSize(content.layout.contentSize)

        previewPanel.positionPreview(beside: settingsWindow)
        #expect(!previewPanel.frame.intersects(settingsWindow.frame), "Native preview covered settings controls")
        let originalSize = previewPanel.frame.size

        settingsWindow.setFrameOrigin(NSPoint(x: 600, y: 100))
        previewPanel.positionPreview(beside: settingsWindow)
        let expectedFrame = getPreviewFrame(contentSize: originalSize, settingsFrame: settingsWindow.frame, screenFrame: settingsWindow.screen!.visibleFrame)
        let pixel = 1 / settingsWindow.screen!.backingScaleFactor

        #expect(abs(previewPanel.frame.minX - expectedFrame.minX) <= pixel, "Native preview did not follow settings horizontally")
        #expect(abs(previewPanel.frame.minY - expectedFrame.minY) <= pixel, "Native preview did not follow settings vertically")
        #expect(!previewPanel.frame.intersects(settingsWindow.frame), "Moved native preview covered settings controls")
        #expect(previewPanel.frame.size == originalSize, "Repositioning changed preview size")
        #expect(!previewPanel.isVisible, "Placement tests presented the preview")
        #expect(!settingsWindow.isVisible, "Placement tests presented a settings window")
    }

    /// Fullscreen settings or settings filling the lower part of the screen; either way the preview's hint band is in it when it is placed.
    @Test(arguments: [false, true], ["fullscreen", "above"])
    func previewIncludesHints(listingWindows: Bool, placement: String) {
        let settingsWindow = buildSettingsWindow()
        let visibleFrame = settingsWindow.screen!.visibleFrame
        let settingsFrame = placement == "fullscreen" ? visibleFrame : NSRect(
            x: visibleFrame.minX, y: visibleFrame.minY + 100,
            width: visibleFrame.width, height: visibleFrame.height / 3
        )
        let content = SwitcherPanelContent()

        content.rebuild(state: buildState(listingWindows: listingWindows, cardGlass: nil, itemCount: 2), glassStore: panelGlass, showsHintsAtOnce: true)
        let contentSize = content.layout.contentSize
        let frame = getPreviewFrame(contentSize: contentSize, settingsFrame: settingsFrame, screenFrame: visibleFrame)
        let container = content.glass.contentView!
        let hintBand = container.subviews.first { $0 is HintBandView }!
        #expect(container.bounds.contains(hintBand.frame), "Preview did not reserve the hint band before placement")

        content.showHintBand()
        #expect(content.layout.contentSize == contentSize, "Preview grew after being positioned")
        #expect(visibleFrame.contains(frame), "Preview hints extended below the visible screen")
        if placement == "above" {
            #expect(!frame.intersects(settingsFrame), "Preview hints overlapped settings")
        }
    }

    // MARK: helpers

    /// Two cells, the first selected: apps test.app.0 and test.app.1, or windows 1 and 2.
    private func buildState(listingWindows: Bool, cardGlass: GlassStore?, selectedIndex: Int = 0, itemCount: Int = 2) -> SwitcherState {
        let items = listingWindows
            ? SwitcherItems.windows((0..<itemCount).map { workspace.buildWindow(windowID: CGWindowID($0 + 1)) })
            : .apps((0..<itemCount).map { workspace.buildApp(index: $0) }, whitelistOnly: false)

        return SwitcherState(
            list: SwitcherList(items: items, cellsPerRow: itemCount, selectedIndex: selectedIndex),
            thumbnails: [:],
            cardGlass: cardGlass,
            isFilterEnabled: false,
            dimHiddenApps: true,
            whitelisted: []
        )
    }

    private func buildState(apps: [SwitcherFakeApp], dimHiddenApps: Bool, whitelisted: Set<String>) -> SwitcherState {
        return SwitcherState(
            list: SwitcherList(items: .apps(apps, whitelistOnly: false), cellsPerRow: apps.count),
            thumbnails: [:],
            cardGlass: nil,
            isFilterEnabled: false,
            dimHiddenApps: dimHiddenApps,
            whitelisted: whitelisted
        )
    }

    private func buildSettingsWindow() -> NSWindow {
        return NSWindow(contentRect: NSRect(x: 360, y: 180, width: 720, height: 540), styleMask: .titled, backing: .buffered, defer: false)
    }

    private func getCells(in container: NSView) -> [SwitcherCellView] {
        return container.subviews.compactMap { $0 as? SwitcherCellView }
    }

    private func expectSameViews(content: SwitcherPanelContent, container: NSView, cells: [SwitcherCellView],
                                 sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(content.glass.contentView === container, "Appearance change rebuilt content", sourceLocation: sourceLocation)
        let currentCells = getCells(in: container)
        #expect(currentCells.count == cells.count, "Appearance change changed the cells", sourceLocation: sourceLocation)
        for (current, original) in zip(currentCells, cells) {
            #expect(current === original, "Appearance change replaced a cell", sourceLocation: sourceLocation)
        }
    }

    /// The first cell's card and its parts, with a known image in the cell's image view.
    private func buildCardViews(listingWindows: Bool) -> SwitcherCardViews {
        let content = SwitcherPanelContent()
        let state = buildState(listingWindows: listingWindows, cardGlass: cardGlass)
        content.rebuild(state: state, glassStore: panelGlass, showsHintsAtOnce: false)
        let glass = content.glass!
        let container = glass.contentView!
        let cells = getCells(in: container)
        let cell = cells[0]
        let card = cell.card
        let imageView = cell.subviews[1] as! NSImageView
        let image = NSImage(size: NSSize(width: 32, height: 32))
        imageView.image = image

        #expect(card.frame == alignToPixels(listingWindows ? windowCardFrameInCell : iconCardFrameInCell), "Card does not frame its content")
        #expect(card.subviews[2].frame == card.bounds, "Card border did not resize with the card")

        return SwitcherCardViews(
            content: content, state: state, glass: glass, container: container, cells: cells, cell: cell, card: card,
            blur: card.subviews[0] as! NSVisualEffectView, tint: card.subviews[1], border: card.subviews[2], imageView: imageView, image: image
        )
    }
}

struct SwitcherCardViews {
    let content: SwitcherPanelContent
    let state: SwitcherState
    let glass: NSGlassEffectView
    let container: NSView
    let cells: [SwitcherCellView]
    let cell: SwitcherCellView
    let card: SwitcherCardView
    let blur: NSVisualEffectView
    let tint: NSView
    let border: NSView
    let imageView: NSImageView
    let image: NSImage
}
