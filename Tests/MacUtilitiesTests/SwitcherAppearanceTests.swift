import AppKit
import Testing
@testable import MacUtilities

/// The panel's real views: look changes reuse the content, cells and images, and the preview is placed beside the settings window at its
/// final size. The real panel runs as SwitcherTestGlassPanel and the rest draws into SwitcherPanelContent, so no window is ordered onto the
/// screen.
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

    /// On the panel, as the preview shows it: only the preview's look changes while it is shown.
    @Test(arguments: [false, true])
    func darknessReusesAllViews(listingWindows: Bool) throws {
        let panel = SwitcherTestGlassPanel()
        let state = buildState(listingWindows: listingWindows, cardGlass: cardGlass)
        panel.showPreview(state: state, glassStore: panelGlass, beside: buildSettingsWindow())
        let glass = try getGlass(of: panel)
        let container = try #require(glass.contentView)
        let cells = getCells(in: container)
        #expect(cells.count == 2, "Panel did not build the initial cells")

        for step in 0..<20 {
            panelGlass.setDarkness(CGFloat(step) / 40)
            panel.updateGlass(state: state, glassStore: panelGlass)

            #expect(panel.contentView === glass, "Darkness change replaced the glass")
            #expect(try #require(glass.tintColor).alphaComponent == panelGlass.darkness, "Darkness change was not applied")
            expectSameViews(glass: glass, container: container, cells: cells)
        }
    }

    /// The panel shows the new glass the content moved into, and tells AppKit it has the active appearance only while Clear.
    @Test(arguments: [false, true])
    func frostedReusesContentAndCells(listingWindows: Bool) throws {
        let panel = SwitcherTestGlassPanel()
        let state = buildState(listingWindows: listingWindows, cardGlass: cardGlass)
        panel.showPreview(state: state, glassStore: panelGlass, beside: buildSettingsWindow())
        let container = try #require(getGlass(of: panel).contentView)
        let cells = getCells(in: container)
        #expect(panel._hasActiveAppearance(), "Clear panel did not ask for the active appearance")

        for frosted in [true, false, true] {
            let previousGlass = try #require(panel.contentView)
            panelGlass.setFrosted(frosted)
            panel.updateGlass(state: state, glassStore: panelGlass)
            let glass = try getGlass(of: panel)

            #expect(glass !== previousGlass, "Frosted change did not show a new effect wrapper")
            #expect(panel._hasActiveAppearance() == !frosted, "Frosted appearance did not change")
            #expect(try #require(glass.tintColor).alphaComponent == panelGlass.darkness, "Frosted change lost the tint")
            expectSameViews(glass: glass, container: container, cells: cells)
        }
    }

    // MARK: cards

    @Test(arguments: [false, true])
    func cardDarknessReusesCardAndImage(listingWindows: Bool) throws {
        let cardViews = try buildCardViews(listingWindows: listingWindows)
        let content = cardViews.content

        for step in 0..<20 {
            cardGlass.setDarkness(CGFloat(step) / 40)
            content.updateGlass(state: cardViews.state, glassStore: panelGlass)

            #expect(content.glass === cardViews.glass, "Card darkness replaced panel glass")
            expectSameViews(glass: content.glass, container: cardViews.container, cells: cardViews.cells)
            #expect(try getElement(cardViews.cell.subviews, at: 0) === cardViews.card, "Card darkness replaced the card")
            #expect(try getElement(cardViews.card.subviews, at: 1) === cardViews.tint, "Card darkness replaced the tint")
            let tintColor = try #require(cardViews.tint.layer?.backgroundColor.flatMap { NSColor(cgColor: $0) }, "The card tint has no color")
            #expect(tintColor.alphaComponent == cardGlass.darkness, "Card darkness was not applied")
            #expect(cardViews.imageView.image === cardViews.image, "Card darkness lost the image")
            #expect(try #require(cardViews.border.layer).borderWidth == selectedCardBorderWidth, "Card darkness lost the selection")
        }
    }

    @Test(arguments: [false, true])
    func cardLookReusesCardAndImage(listingWindows: Bool) throws {
        let cardViews = try buildCardViews(listingWindows: listingWindows)

        for frosted in [true, false, true] {
            cardGlass.setFrosted(frosted)
            cardViews.content.updateGlass(state: cardViews.state, glassStore: panelGlass)

            #expect(try getElement(cardViews.card.subviews, at: 0) === cardViews.blur, "Card look replaced the blur")
            #expect(cardViews.blur.isHidden == !frosted, "Card look did not update the blur")
            #expect(cardViews.blur.state == .active, "Card blur lost its active state")
            #expect(cardViews.imageView.image === cardViews.image, "Card look lost the image")
            expectSameViews(glass: cardViews.content.glass, container: cardViews.container, cells: cardViews.cells)
        }
    }

    @Test(arguments: [false, true])
    func cardsToggleReusesCellAndImage(listingWindows: Bool) throws {
        let cardViews = try buildCardViews(listingWindows: listingWindows)
        let content = cardViews.content

        content.updateGlass(state: buildState(listingWindows: listingWindows, cardGlass: nil), glassStore: panelGlass)
        #expect(cardViews.card.isHidden, "Cards-off left the card visible")
        #expect(cardViews.imageView.image === cardViews.image, "Cards-off lost the image")

        content.updateGlass(state: cardViews.state, glassStore: panelGlass)
        #expect(!cardViews.card.isHidden, "Cards-on did not show the card")
        #expect(cardViews.imageView.image === cardViews.image, "Cards-on lost the image")
        #expect(try #require(cardViews.border.layer).borderWidth == selectedCardBorderWidth, "Cards-on lost the selection")
        expectSameViews(glass: content.glass, container: cardViews.container, cells: cardViews.cells)
    }

    @Test(arguments: [false, true])
    func selectionMovesBetweenCards(listingWindows: Bool) throws {
        let cardViews = try buildCardViews(listingWindows: listingWindows)

        cardViews.content.update(state: buildState(listingWindows: listingWindows, cardGlass: cardGlass, selectedIndex: 1))

        #expect(try #require(cardViews.border.layer).borderWidth == cardBorderWidth, "Previous card kept the selected border")
        let selectedBorder = try getElement(getElement(cardViews.cells, at: 1).card.subviews, at: 2)
        #expect(try #require(selectedBorder.layer).borderWidth == selectedCardBorderWidth, "New selection did not get its border")
    }

    // MARK: openings

    @Test
    func newOpeningBuildsNewModeContent() throws {
        let content = SwitcherPanelContent()

        content.rebuild(state: buildState(listingWindows: true, cardGlass: nil), glassStore: panelGlass, showsHintsAtOnce: false)
        let windowContainer = try #require(content.glass?.contentView)
        content.hideHintBand()
        content.rebuild(state: buildState(listingWindows: false, cardGlass: nil), glassStore: panelGlass, showsHintsAtOnce: false)
        let appContainer = try #require(content.glass?.contentView)

        #expect(appContainer !== windowContainer, "New opening reused the old mode's content")
        #expect(getCells(in: appContainer).allSatisfy { $0 is IconCellView }, "New opening kept window cells")
    }

    @Test
    func dimmingRefreshesExistingIcons() throws {
        let apps = [workspace.buildApp(index: 0), workspace.buildApp(index: 1)]
        apps[0].isHidden = true
        let content = SwitcherPanelContent()
        content.rebuild(state: buildState(apps: apps, dimHiddenApps: true, whitelisted: []), glassStore: panelGlass, showsHintsAtOnce: false)
        let container = try #require(content.glass?.contentView)
        let cells = getCells(in: container)
        let hiddenCell = try #require(getElement(cells, at: 0) as? IconCellView)
        let visibleCell = try #require(getElement(cells, at: 1) as? IconCellView)
        #expect(hiddenCell.icon.alphaValue == 0.4, "Hidden icon did not start dimmed")

        for dimHiddenApps in [false, true, false] {
            let state = buildState(apps: apps, dimHiddenApps: dimHiddenApps, whitelisted: Set(apps.map { $0.bundleIdentifier }))
            content.updateGlass(state: state, glassStore: panelGlass)

            #expect(hiddenCell.icon.alphaValue == (dimHiddenApps ? 0.4 : 1), "Appearance change did not refresh hidden icon opacity")
            #expect(visibleCell.icon.alphaValue == 1, "Appearance change dimmed a visible app")
            #expect(!hiddenCell.dot.isHidden, "Appearance change lost the whitelist marker")
            expectSameViews(glass: content.glass, container: container, cells: cells)
        }
    }

    // MARK: Dock badges

    /// In the plain and the card layout, with the whitelist filter on and off: a badged app's cell has the capsule with the Dock's text at its
    /// icon's top right, clear of the whitelist dot and the name band; an app without a badge has none.
    @Test(arguments: [false, true], [false, true])
    func badgedAppsShowTheirDockBadge(showsCards: Bool, whitelistOnly: Bool) throws {
        let apps = (0..<3).map { workspace.buildApp(index: $0) }
        let content = SwitcherPanelContent()
        let state = buildState(apps: apps, appBadges: [0: "•", 2: "12"], cardGlass: showsCards ? cardGlass : nil, whitelistOnly: whitelistOnly)
        content.rebuild(state: state, glassStore: panelGlass, showsHintsAtOnce: false)

        let circleCell = try getIconCell(in: content, at: 0)
        let unbadgedCell = try getIconCell(in: content, at: 1)
        let capsuleCell = try getIconCell(in: content, at: 2)
        let circle = try getDockBadge(in: circleCell)
        let capsule = try getDockBadge(in: capsuleCell)

        #expect(try getText(of: circle) == "•", "Wrong badge text")
        #expect(try getText(of: capsule) == "12", "Wrong badge text")
        #expect(unbadgedCell.subviews.allSatisfy { !($0 is DockBadgeView) }, "An app without a badge shows one")
        #expect(circle.frame.width == circle.frame.height, "One character is not a circle")
        #expect(capsule.frame.width > capsule.frame.height, "Two characters did not widen the badge")
        for badge in [circle, capsule] {
            #expect(!badge.isHidden && badge.alphaValue == 1, "Badge is not visible")
            #expect(circleCell.bounds.contains(badge.frame), "Badge leaves its cell")
            #expect(badge.frame.maxX == iconCardFrameInCell.maxX && badge.frame.maxY == iconCardFrameInCell.maxY, "Badge is not at the icon's top right")
            #expect(!badge.frame.intersects(circleCell.dot.frame), "Badge covers the whitelist dot")
            #expect(badge.frame.minY > nameBandHeight, "Badge reaches into the name band")
        }
    }

    @Test
    func longBadgeTextIsTruncated() throws {
        let app = workspace.buildApp(index: 0)
        let content = SwitcherPanelContent()
        content.rebuild(state: buildState(apps: [app], appBadges: [0: "1234567890"], cardGlass: nil, whitelistOnly: false), glassStore: panelGlass,
                        showsHintsAtOnce: false)
        let cell = try getIconCell(in: content, at: 0)
        let badge = try getDockBadge(in: cell)
        let label = try #require(badge.subviews.first as? NSTextField)

        #expect(badge.frame.width == dockBadgeMaxWidth, "Long text widened the badge past its maximum")
        #expect(label.fittingSize.width > label.frame.width, "Long text fits, so nothing is truncated")
        #expect(label.lineBreakMode == .byTruncatingTail, "Long text is cut off without an ellipsis")
    }

    /// The badge dims with its hidden app's icon, and comes back with it.
    @Test
    func badgeDimsWithItsHiddenApp() throws {
        let app = workspace.buildApp(index: 0)
        app.isHidden = true
        let content = SwitcherPanelContent()
        content.rebuild(state: buildState(apps: [app], appBadges: [0: "3"], cardGlass: nil, whitelistOnly: false), glassStore: panelGlass,
                        showsHintsAtOnce: false)
        let cell = try getIconCell(in: content, at: 0)
        let badge = try getDockBadge(in: cell)
        #expect(badge.alphaValue == hiddenIconAlpha, "Badge of a hidden app is not dimmed")

        app.isHidden = false
        content.update(state: buildState(apps: [app], appBadges: [0: "3"], cardGlass: nil, whitelistOnly: false))

        #expect(badge.alphaValue == 1, "Badge stayed dimmed after its app was shown")
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

    /// Shown beside the settings window at the size of its content, then following the window with the same views.
    @Test(arguments: [false, true])
    func previewPanelFollowsSettings(listingWindows: Bool) throws {
        let settingsWindow = buildSettingsWindow()
        let screenFrame = settingsWindow.screen!.visibleFrame
        let previewPanel = SwitcherTestGlassPanel()
        previewPanel.showPreview(state: buildState(listingWindows: listingWindows, cardGlass: cardGlass, itemCount: listingWindows ? 1 : 2),
                                 glassStore: panelGlass, beside: settingsWindow)
        let glass = try getGlass(of: previewPanel)
        let container = try #require(glass.contentView)
        let cells = getCells(in: container)
        let originalSize = previewPanel.frame.size

        #expect(previewPanel.isVisible, "Preview was not ordered in")
        #expect(originalSize == container.frame.size, "Preview was not sized to its content")
        expectFrame(previewPanel.frame, near: getPreviewFrame(contentSize: originalSize, settingsFrame: settingsWindow.frame, screenFrame: screenFrame),
                    "Preview was placed before it had its content's size")
        #expect(!previewPanel.frame.intersects(settingsWindow.frame), "Native preview covered settings controls")

        settingsWindow.setFrameOrigin(NSPoint(x: 600, y: 100))
        previewPanel.positionPreview(beside: settingsWindow)

        expectFrame(previewPanel.frame, near: getPreviewFrame(contentSize: originalSize, settingsFrame: settingsWindow.frame, screenFrame: screenFrame),
                    "Native preview did not follow settings")
        #expect(!previewPanel.frame.intersects(settingsWindow.frame), "Moved native preview covered settings controls")
        #expect(previewPanel.frame.size == originalSize, "Repositioning changed preview size")
        #expect(previewPanel.contentView === glass, "Repositioning replaced the glass")
        expectSameViews(glass: glass, container: container, cells: cells)
        #expect(!settingsWindow.isVisible, "Placement tests presented a settings window")
        previewPanel.hide()
    }

    /// Fullscreen settings or settings filling the lower part of the screen; either way the preview's hint band is in it when it is placed,
    /// and it does not grow once the switcher's hints would have come in. All four previews wait out the hints together.
    @Test
    func previewIncludesHints() async throws {
        var shownPreviews: [(panel: SwitcherTestGlassPanel, settingsWindow: NSWindow, frame: NSRect, placement: String)] = []
        for listingWindows in [false, true] {
            for placement in ["fullscreen", "above"] {
                let settingsWindow = buildSettingsWindow()
                let visibleFrame = settingsWindow.screen!.visibleFrame
                settingsWindow.setFrame(placement == "fullscreen" ? visibleFrame : NSRect(
                    x: visibleFrame.minX, y: visibleFrame.minY + 100,
                    width: visibleFrame.width, height: visibleFrame.height / 3
                ), display: false)
                let previewPanel = SwitcherTestGlassPanel()

                previewPanel.showPreview(state: buildState(listingWindows: listingWindows, cardGlass: nil, itemCount: 2), glassStore: panelGlass,
                                         beside: settingsWindow)
                let container = try #require(getGlass(of: previewPanel).contentView)
                let hintBand = try #require(container.subviews.first { $0 is HintBandView }, "Preview built no hint band")
                #expect(container.bounds.contains(hintBand.frame), "Preview did not reserve the hint band before placement")
                shownPreviews.append((previewPanel, settingsWindow, previewPanel.frame, placement))
            }
        }

        try await Task.sleep(for: .seconds(hintDelay + hintFadeDuration + 0.1))

        for preview in shownPreviews {
            #expect(preview.panel.frame == preview.frame, "Preview grew after being positioned")
            #expect(preview.settingsWindow.screen!.visibleFrame.contains(preview.panel.frame), "Preview hints extended below the visible screen")
            if preview.placement == "above" {
                #expect(!preview.panel.frame.intersects(preview.settingsWindow.frame), "Preview hints overlapped settings")
            }
            preview.panel.hide()
        }
    }

    // MARK: helpers

    /// Two cells, the first selected: apps test.app.0 and test.app.1, or windows 1 and 2.
    private func buildState(listingWindows: Bool, cardGlass: GlassStore?, selectedIndex: Int = 0, itemCount: Int = 2) -> SwitcherState {
        let items = listingWindows
            ? SwitcherItems.windows((0..<itemCount).map { workspace.buildWindow(windowID: CGWindowID($0 + 1)) }, of: workspace.buildApp(index: 0))
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

    private func buildState(apps: [SwitcherFakeApp], appBadges: [pid_t: String], cardGlass: GlassStore?, whitelistOnly: Bool) -> SwitcherState {
        return SwitcherState(
            list: SwitcherList(items: .apps(apps, whitelistOnly: whitelistOnly), cellsPerRow: apps.count, appBadges: appBadges),
            thumbnails: [:],
            cardGlass: cardGlass,
            isFilterEnabled: whitelistOnly,
            dimHiddenApps: true,
            whitelisted: Set(apps.map { $0.bundleIdentifier })
        )
    }

    private func getIconCell(in content: SwitcherPanelContent, at index: Int, sourceLocation: SourceLocation = #_sourceLocation) throws -> IconCellView {
        let container = try #require(content.glass?.contentView, "The content has no container", sourceLocation: sourceLocation)
        let cell = try getElement(getCells(in: container), at: index, sourceLocation: sourceLocation)
        return try #require(cell as? IconCellView, "Not an app cell", sourceLocation: sourceLocation)
    }

    private func getDockBadge(in cell: IconCellView, sourceLocation: SourceLocation = #_sourceLocation) throws -> DockBadgeView {
        let badges = cell.subviews.compactMap { $0 as? DockBadgeView }
        try #require(badges.count == 1, "The cell does not have one Dock badge", sourceLocation: sourceLocation)
        return badges[0]
    }

    private func getText(of badge: DockBadgeView, sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        return try #require(badge.subviews.first as? NSTextField, "The badge has no text", sourceLocation: sourceLocation).stringValue
    }

    private func buildSettingsWindow() -> NSWindow {
        return NSWindow(contentRect: NSRect(x: 360, y: 180, width: 720, height: 540), styleMask: .titled, backing: .buffered, defer: false)
    }

    private func getGlass(of panel: NSWindow, sourceLocation: SourceLocation = #_sourceLocation) throws -> NSGlassEffectView {
        return try #require(panel.contentView as? NSGlassEffectView, "The panel does not show the glass", sourceLocation: sourceLocation)
    }

    /// The element at that index of views the content built.
    private func getElement<Element>(_ elements: [Element], at index: Int, sourceLocation: SourceLocation = #_sourceLocation) throws -> Element {
        try #require(index < elements.count, "The content built fewer views", sourceLocation: sourceLocation)
        return elements[index]
    }

    private func getCells(in container: NSView) -> [SwitcherCellView] {
        return container.subviews.compactMap { $0 as? SwitcherCellView }
    }

    private func expectSameViews(glass: NSGlassEffectView, container: NSView, cells: [SwitcherCellView],
                                 sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(glass.contentView === container, "Appearance change rebuilt content", sourceLocation: sourceLocation)
        let currentCells = getCells(in: container)
        #expect(currentCells.count == cells.count, "Appearance change changed the cells", sourceLocation: sourceLocation)
        for (current, original) in zip(currentCells, cells) {
            #expect(current === original, "Appearance change replaced a cell", sourceLocation: sourceLocation)
        }
    }

    /// Within a pixel, as the window server places windows on whole pixels.
    private func expectFrame(_ frame: NSRect, near expectedFrame: NSRect, _ comment: Comment, sourceLocation: SourceLocation = #_sourceLocation) {
        let pixel = 1 / NSScreen.main!.backingScaleFactor

        #expect(abs(frame.minX - expectedFrame.minX) <= pixel, comment, sourceLocation: sourceLocation)
        #expect(abs(frame.minY - expectedFrame.minY) <= pixel, comment, sourceLocation: sourceLocation)
        #expect(frame.size == expectedFrame.size, comment, sourceLocation: sourceLocation)
    }

    /// The first cell's card and its parts, with a known image in the cell's image view.
    private func buildCardViews(listingWindows: Bool) throws -> SwitcherCardViews {
        let content = SwitcherPanelContent()
        let state = buildState(listingWindows: listingWindows, cardGlass: cardGlass)
        content.rebuild(state: state, glassStore: panelGlass, showsHintsAtOnce: false)
        let glass = try #require(content.glass)
        let container = try #require(glass.contentView)
        let cells = getCells(in: container)
        let cell = try getElement(cells, at: 0)
        let card = cell.card
        let imageView = try #require(getElement(cell.subviews, at: 1) as? NSImageView)
        let image = NSImage(size: NSSize(width: 32, height: 32))
        imageView.image = image

        #expect(card.frame == alignToPixels(listingWindows ? windowCardFrameInCell : iconCardFrameInCell), "Card does not frame its content")
        let border = try getElement(card.subviews, at: 2)
        #expect(border.frame == card.bounds, "Card border did not resize with the card")

        let blur = try #require(getElement(card.subviews, at: 0) as? NSVisualEffectView)
        let tint = try getElement(card.subviews, at: 1)

        return SwitcherCardViews(
            content: content, state: state, glass: glass, container: container, cells: cells, cell: cell, card: card,
            blur: blur, tint: tint, border: border, imageView: imageView, image: image
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
