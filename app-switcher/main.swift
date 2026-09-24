import AppKit
import ApplicationServices
import CoreGraphics
import QuartzCore

let tabKeyCode: Int64 = 48
let wKeyCode: Int64 = 13
let fKeyCode: Int64 = 3
let qKeyCode: Int64 = 12
let hKeyCode: Int64 = 4
let xKeyCode: Int64 = 7
let escapeKeyCode: Int64 = 53
let leftArrowKeyCode: Int64 = 123
let rightArrowKeyCode: Int64 = 124
let downArrowKeyCode: Int64 = 125
let upArrowKeyCode: Int64 = 126
let filterEnabledKey = "filterEnabled"
let whitelistKey = "whitelist"

/// The icon image; Tahoe icons fill ~80.5% of their canvas, so the visible squircle is ~55 wide. The cell is as wide as the image.
let iconSize: CGFloat = 68
let itemSpacing: CGFloat = 5
let horizontalPadding: CGFloat = 22
/// The widest the panel gets, as a share of the screen, before the icons wrap to the next row.
let maxPanelWidthFraction: CGFloat = 0.7
let verticalPadding: CGFloat = 7.5
let dotSize: CGFloat = 5

/// The 13pt name label's height. The whitelist dot gets a band of the same height above the icon, so the two mirror each other.
let nameBandHeight: CGFloat = 16
let nameTopSpacing: CGFloat = 0
/// Rows overlap their bands: the name below one row's icons ends 3pt above the whitelist dots of the next.
let rowSpacing: CGFloat = -8
/// Below the band's centre, so the dot reads as attached to the icon rather than floating.
let dotCenterFromCellTop: CGFloat = nameBandHeight / 2 + 3
/// Mirrored bands above and below, so the icon lands exactly in the middle of the cell.
let cellHeight: CGFloat = iconSize + 2 * (nameBandHeight + nameTopSpacing)
let iconFrameInCell = NSRect(x: 0, y: nameBandHeight + nameTopSpacing, width: iconSize, height: iconSize)
let dotFrameInCell = NSRect(x: (iconSize - dotSize) / 2, y: cellHeight - dotCenterFromCellTop - dotSize / 2, width: dotSize, height: dotSize)
let panelCornerRadius: CGFloat = 28
/// Clear glass keeps the backdrop's colour where regular glass washes it out; this pulls it down to the native
/// switcher's body, roughly 0.63 * backdrop + 19 per channel. The 1pt rim is left undimmed.
let panelDimmingColor = NSColor.black.withAlphaComponent(0.14)
/// Measured off the native switcher, one row at a time from the edge inward. [row from the edge] -> white alpha
let topRimAlphas: [CGFloat] = [0.34, 0.07, 0.03, 0.015]
let bottomRimAlphas: [CGFloat] = [0.35, 0.09, 0.055, 0.045, 0.035, 0.03, 0.02]
/// The native highlight hugs the icon's squircle with a 3pt margin and has no stroke.
let highlightColor = NSColor.white.withAlphaComponent(0.30)
let filteredHighlightColor = NSColor.systemGreen.withAlphaComponent(0.45)
let highlightCornerRadius: CGFloat = 15.5
/// The 68pt image has a ~6.5pt transparent margin around the squircle, and the highlight sits 3pt outside it.
let highlightIconInset: CGFloat = 3.5
/// Hidden apps stay listed, dimmed like in the native switcher, so they can be brought back.
let hiddenIconAlpha: CGFloat = 0.4
/// After Cmd+Q the icon fades and shrinks out while the rest slide into place, over this long.
let removalDuration: TimeInterval = 0.15
/// How far the leaving icon's edges pull in while it fades: to half its size.
let leavingIconShrink: CGFloat = iconSize / 4
let smokeCapturePath = "/tmp/app-switcher-smoke.png"

/// Screen-region capture of our own windows. CGWindowListCreateImage is gone from the SDK but still in the dylib.
typealias CreateWindowImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

func writeCapture(around window: NSWindow, path: String) {
    let margin: CGFloat = 40
    let frame = window.frame.insetBy(dx: -margin, dy: -margin)
    let flipped = CGRect(
        x: frame.minX,
        y: NSScreen.screens[0].frame.height - frame.maxY,
        width: frame.width,
        height: frame.height
    )

    let onScreenOnly: UInt32 = 1 << 0
    let everyWindow: UInt32 = 0
    let bestResolution: UInt32 = 1 << 3

    let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage")!
    let createImage = unsafeBitCast(symbol, to: CreateWindowImage.self)
    let image = createImage(flipped, onScreenOnly, everyWindow, bestResolution)!.takeRetainedValue()
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!

    try! png.write(to: URL(fileURLWithPath: path))
    print("smoke: capture \(image.width)x\(image.height) -> \(path)")
}

/// Colorful window behind the panel, so the capture shows what the glass is blurring. APP_SWITCHER_SMOKE_DARK=1 makes it a dark gray-blue instead.
var captureBackdrop: NSWindow?

func getCaptureBackdropColors() -> [CGColor] {
    if ProcessInfo.processInfo.environment["APP_SWITCHER_SMOKE_DARK"] == "1" {
        return [NSColor(srgbRed: 0x1b / 255, green: 0x1d / 255, blue: 0x24 / 255, alpha: 1).cgColor, NSColor(srgbRed: 0x2a / 255, green: 0x2f / 255, blue: 0x3a / 255, alpha: 1).cgColor]
    }

    return [NSColor.systemPink.cgColor, NSColor.systemOrange.cgColor, NSColor.white.cgColor, NSColor.systemTeal.cgColor, NSColor.systemIndigo.cgColor]
}

func showCaptureBackdrop(behind window: NSWindow) {
    let backdrop = NSWindow(contentRect: window.frame.insetBy(dx: -80, dy: -80), styleMask: .borderless, backing: .buffered, defer: false)
    let gradient = CAGradientLayer()

    gradient.frame = NSRect(origin: .zero, size: backdrop.frame.size)
    gradient.colors = getCaptureBackdropColors()
    gradient.startPoint = CGPoint(x: 0, y: 1)
    gradient.endPoint = CGPoint(x: 1, y: 0)

    backdrop.contentView!.wantsLayer = true
    backdrop.contentView!.layer!.addSublayer(gradient)
    backdrop.level = .normal
    backdrop.orderFrontRegardless()
    captureBackdrop = backdrop
}

func getRegularRunningApps() -> [NSRunningApplication] {
    return NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
}

/// One AX round trip costs 10-20ms, so ask every app at once. Each iteration writes its own index, so no lock is needed.
func getAppsWithWindows(_ apps: [NSRunningApplication]) -> [NSRunningApplication] {
    var windowed = [Bool](repeating: false, count: apps.count)

    windowed.withUnsafeMutableBufferPointer { answers in
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            answers[index] = hasWindows(apps[index])
        }
    }

    return zip(apps, windowed).filter { $0.1 }.map { $0.0 }
}

/// Minimized windows count. The short messaging timeout keeps a hung app from stalling the event tap.
func hasWindows(_ app: NSRunningApplication) -> Bool {
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.1)

    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) != .success { return false }

    guard let windows = value as? [AXUIElement] else { return false }

    return !windows.isEmpty
}

/// Most-recently-activated bundle identifiers, front of the array is the most recent.
final class RecentAppsTracker {
    private(set) var bundleIdentifiers: [String] = []

    init() {
        bundleIdentifiers = getRegularRunningApps().compactMap { $0.bundleIdentifier }

        if let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            moveToFront(frontmost)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let bundleIdentifier = app?.bundleIdentifier else { return }
            self.moveToFront(bundleIdentifier)
        }
    }

    func moveToFront(_ bundleIdentifier: String) {
        bundleIdentifiers.removeAll { $0 == bundleIdentifier }
        bundleIdentifiers.insert(bundleIdentifier, at: 0)
    }
}

/// A clickable icon cell: the whitelist dot above the icon, room for the selected app name below it, the icon centered between them.
final class IconCellView: NSView {
    let icon = NSImageView()
    let dot = NSView()
    var index = 0
    var onClick: (Int) -> Void = { _ in }

    convenience init(app: NSRunningApplication, whitelisted: Bool) {
        self.init(frame: .zero)

        icon.image = app.icon ?? NSImage()
        icon.image?.size = NSSize(width: iconSize, height: iconSize)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.alphaValue = getIconAlpha(app: app)
        icon.frame = alignToPixels(iconFrameInCell)

        dot.wantsLayer = true
        dot.layer?.cornerRadius = dotSize / 2
        dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dot.frame = alignToPixels(dotFrameInCell)
        dot.isHidden = !whitelisted

        addSubview(icon)
        addSubview(dot)
    }

    /// Keeps the icon image view from swallowing the click.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        if !bounds.contains(localPoint) { return nil }

        return self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        onClick(index)
    }
}

func getIconAlpha(app: NSRunningApplication) -> CGFloat {
    if app.isHidden { return hiddenIconAlpha }
    return 1
}

/// Top and bottom edges only, along the straight run between the corner arcs; lets clicks through to the cells beneath.
final class RimView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let straight = NSRect(x: panelCornerRadius, y: 0, width: bounds.width - 2 * panelCornerRadius, height: 1)

        for (row, alpha) in topRimAlphas.enumerated() {
            NSColor.white.withAlphaComponent(alpha).setFill()
            straight.offsetBy(dx: 0, dy: bounds.height - 1 - CGFloat(row)).fill()
        }

        for (row, alpha) in bottomRimAlphas.enumerated() {
            NSColor.white.withAlphaComponent(alpha).setFill()
            straight.offsetBy(dx: 0, dy: CGFloat(row)).fill()
        }
    }
}

struct SwitcherState {
    let apps: [NSRunningApplication]
    let iconsPerRow: Int
    let selectedIndex: Int
    let filterEnabled: Bool
    let whitelisted: Set<String>
}

func getRowWidth(iconCount: Int) -> CGFloat {
    return CGFloat(iconCount) * iconSize + CGFloat(iconCount - 1) * itemSpacing
}

/// Whole pixels of the main screen, as Auto Layout gave the old constraints: on a 1x screen the half-point constants would otherwise blur.
func alignToPixels(_ rect: NSRect) -> NSRect {
    return NSScreen.main!.backingAlignedRect(rect, options: .alignAllEdgesNearest)
}

/// Where the cells sit for an app count: full rows from the top down, centered on each other, the last one possibly shorter.
struct SwitcherLayout {
    let contentSize: NSSize
    /// [index] -> the cell's frame in the content
    let cellFrames: [NSRect]

    init(appCount: Int, iconsPerRow: Int) {
        let rowCount = (appCount + iconsPerRow - 1) / iconsPerRow
        let width = getRowWidth(iconCount: min(appCount, iconsPerRow)) + 2 * horizontalPadding
        let height = CGFloat(rowCount) * cellHeight + CGFloat(rowCount - 1) * rowSpacing + 2 * verticalPadding

        var frames: [NSRect] = []
        for index in 0..<appCount {
            let row = index / iconsPerRow
            let column = index % iconsPerRow
            let rowWidth = getRowWidth(iconCount: min(iconsPerRow, appCount - row * iconsPerRow))
            let x = (width - rowWidth) / 2 + CGFloat(column) * (iconSize + itemSpacing)
            let y = height - verticalPadding - cellHeight - CGFloat(row) * (cellHeight + rowSpacing)

            frames.append(alignToPixels(NSRect(x: x, y: y, width: iconSize, height: cellHeight)))
        }

        contentSize = NSSize(width: width, height: height)
        cellFrames = frames
    }

    func getIconFrame(index: Int) -> NSRect {
        return iconFrameInCell.offsetBy(dx: cellFrames[index].minX, dy: cellFrames[index].minY)
    }

    /// Hugs the selected icon's squircle rather than boxing the whole cell; the name sits below it, outside.
    func getHighlightFrame(index: Int) -> NSRect {
        return alignToPixels(getIconFrame(index: index).insetBy(dx: highlightIconInset, dy: highlightIconInset))
    }
}

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

final class AppSwitcherController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let filterMenuItem = NSMenuItem(title: "Filter enabled", action: #selector(toggleFilter), keyEquivalent: "")
    private let whitelistMenu = NSMenu(title: "Whitelist")

    private let panel = SwitcherPanel()
    private let tracker = RecentAppsTracker()

    private var eventTap: CFMachPort?
    private var candidates: [NSRunningApplication] = []
    private var iconsPerRow = 1
    private var selectedIndex = 0

    private var isOpening = false
    private var commandReleasedWhileOpening = false
    private var pendingAdvance = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        wirePanelClicks()
        observeAppTermination()
        observeAppHiding()
        requestAccessibilityTrust()
        startEventTap()
        runSmokeTestIfRequested()
    }

    private func runSmokeTestIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["APP_SWITCHER_SMOKE_TEST"] != nil else { return }

        UserDefaults.standard.set(environment["APP_SWITCHER_SMOKE_FILTER"] == "1", forKey: filterEnabledKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadCandidates()
            self.selectedIndex = Int(environment["APP_SWITCHER_SMOKE_INDEX"] ?? "1")!
            self.panel.show(state: self.buildState())
            showCaptureBackdrop(behind: self.panel)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            print("smoke: frame=\(self.panel.frame) visible=\(self.panel.isVisible) alpha=\(self.panel.alphaValue) apps=\(self.candidates.count) selected=\(self.selectedIndex)")
            print("smoke: candidates=\(self.candidates.compactMap { $0.localizedName })")
            writeCapture(around: self.panel, path: smokeCapturePath)
            exit(0)
        }
    }

    // MARK: menu

    private func wirePanelClicks() {
        panel.onCellClicked = { index in
            self.selectedIndex = index
            self.activateSelectedApp()
        }
    }

    private func observeAppTermination() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            if !self.panel.isVisible { return }

            let app = notification.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
            guard let index = self.candidates.firstIndex(where: { $0.processIdentifier == app.processIdentifier }) else { return }

            self.removeCandidate(at: index)
        }
    }

    /// Redraws the dimming once the app is really hidden or shown, whether it was our Cmd+H or done elsewhere.
    private func observeAppHiding() {
        for name in [NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                if !self.panel.isVisible { return }

                self.panel.update(state: self.buildState())
            }
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "App Switcher")

        filterMenuItem.target = self
        filterMenuItem.state = isFilterEnabled ? .on : .off
        menu.addItem(filterMenuItem)
        let quitOthersItem = NSMenuItem(title: "Quit apps not in the whitelist", action: #selector(quitAppsNotInWhitelist), keyEquivalent: "")
        quitOthersItem.target = self
        menu.addItem(quitOthersItem)
        menu.addItem(buildHintItem(title: "While switching: Up/Down move between rows"))
        menu.addItem(buildHintItem(title: "While switching: W toggles whitelist"))
        menu.addItem(buildHintItem(title: "While switching: F toggles filter"))
        menu.addItem(buildHintItem(title: "While switching: Q quits app"))
        menu.addItem(buildHintItem(title: "While switching: X quits every app not in the whitelist"))
        menu.addItem(buildHintItem(title: "While switching: H hides app"))
        menu.addItem(buildHintItem(title: "While switching: Esc cancels"))
        menu.addItem(.separator())

        whitelistMenu.delegate = self
        let whitelistItem = NSMenuItem(title: "Whitelist", action: nil, keyEquivalent: "")
        whitelistItem.submenu = whitelistMenu
        menu.addItem(whitelistItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func buildHintItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")

        item.isEnabled = false

        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let whitelist = getWhitelist()
        for app in getRegularRunningApps() {
            guard let bundleIdentifier = app.bundleIdentifier else { continue }
            let item = NSMenuItem(title: app.localizedName ?? bundleIdentifier, action: #selector(toggleWhitelistEntry), keyEquivalent: "")
            item.target = self
            item.representedObject = bundleIdentifier
            item.state = whitelist.contains(bundleIdentifier) ? .on : .off
            menu.addItem(item)
        }
    }

    @objc private func toggleFilter() {
        UserDefaults.standard.set(!isFilterEnabled, forKey: filterEnabledKey)
        filterMenuItem.state = isFilterEnabled ? .on : .off
    }

    @objc private func toggleWhitelistEntry(_ sender: NSMenuItem) {
        toggleWhitelist(bundleIdentifier: sender.representedObject as! String)
    }

    func toggleWhitelist(bundleIdentifier: String) {
        var whitelist = getWhitelist()

        if whitelist.contains(bundleIdentifier) {
            whitelist.remove(bundleIdentifier)
        } else {
            whitelist.insert(bundleIdentifier)
        }

        UserDefaults.standard.set(Array(whitelist), forKey: whitelistKey)
    }

    /// A normal quit, so an app with unsaved changes shows its dialog and stays running. The switcher itself is an accessory app, never a regular one.
    @objc private func quitAppsNotInWhitelist() {
        let whitelist = getWhitelist()

        for app in getRegularRunningApps() {
            guard let bundleIdentifier = app.bundleIdentifier else { continue }
            if whitelist.contains(bundleIdentifier) { continue }
            app.terminate()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: preferences

    private var isFilterEnabled: Bool {
        return UserDefaults.standard.bool(forKey: filterEnabledKey)
    }

    private func getWhitelist() -> Set<String> {
        return Set(UserDefaults.standard.stringArray(forKey: whitelistKey) ?? [])
    }

    // MARK: event tap

    private func requestAccessibilityTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) { return }

        print("Accessibility permission not granted: grant it in System Settings > Privacy & Security > Accessibility, then relaunch.")
    }

    private func startEventTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: handleTappedEvent,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            print("Could not create the event tap: Cmd+Tab filtering is off until Accessibility permission is granted.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if isTapDisabled(type) {
            CGEvent.tapEnable(tap: eventTap!, enable: true)
            print("event tap re-enabled after \(type)")
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            return handleKeyDown(event)
        }

        if type == .flagsChanged {
            return handleFlagsChanged(event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func isTapDisabled(_ type: CGEventType) -> Bool {
        if type == .tapDisabledByTimeout { return true }
        if type == .tapDisabledByUserInput { return true }

        return false
    }

    /// Never does real work: macOS disables a tap whose callback is slow, and the keystroke then falls through to the Dock.
    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if panel.isVisible {
            return handleKeyDownWhileVisible(event)
        }

        if !isSwitcherShortcut(event) {
            return Unmanaged.passUnretained(event)
        }

        if isOpening {
            pendingAdvance += 1
            return nil
        }

        isOpening = true
        commandReleasedWhileOpening = false
        pendingAdvance = 0
        DispatchQueue.main.async { self.openSwitcher() }
        return nil
    }

    private func openSwitcher() {
        loadCandidates()
        isOpening = false

        if candidates.isEmpty { return }

        selectedIndex = (candidates.count > 1 ? 1 : 0) + pendingAdvance
        selectedIndex %= candidates.count

        if commandReleasedWhileOpening {
            activateSelectedApp()
            return
        }

        panel.show(state: buildState())
    }

    private func handleKeyDownWhileVisible(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if isSwitcherShortcut(event) {
            advanceSelection(backward: event.flags.contains(.maskShift))
            return nil
        }

        if isForwardShortcut(event) {
            advanceSelection(backward: false)
            return nil
        }

        if isBackwardShortcut(event) {
            advanceSelection(backward: true)
            return nil
        }

        if isRowUpShortcut(event) {
            moveSelectionBetweenRows(up: true)
            return nil
        }

        if isRowDownShortcut(event) {
            moveSelectionBetweenRows(up: false)
            return nil
        }

        if isWhitelistToggleShortcut(event) {
            toggleWhitelist(bundleIdentifier: candidates[selectedIndex].bundleIdentifier!)
            panel.update(state: buildState())
            return nil
        }

        if isFilterToggleShortcut(event) {
            DispatchQueue.main.async { self.toggleFilterAndRefreshCandidates() }
            return nil
        }

        if isQuitShortcut(event) {
            candidates[selectedIndex].terminate()
            return nil
        }

        if isQuitOthersShortcut(event) {
            DispatchQueue.main.async { self.quitAppsNotInWhitelist() }
            return nil
        }

        if isHideShortcut(event) {
            candidates[selectedIndex].hide()
            return nil
        }

        if isCancelShortcut(event) {
            panel.hide()
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.flags.contains(.maskCommand) {
            return Unmanaged.passUnretained(event)
        }

        if isOpening {
            commandReleasedWhileOpening = true
            return Unmanaged.passUnretained(event)
        }

        if !panel.isVisible {
            return Unmanaged.passUnretained(event)
        }

        activateSelectedApp()
        return Unmanaged.passUnretained(event)
    }

    private func isSwitcherShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: tabKeyCode)
    }

    private func isForwardShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: rightArrowKeyCode)
    }

    private func isBackwardShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: leftArrowKeyCode)
    }

    private func isRowUpShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: upArrowKeyCode)
    }

    private func isRowDownShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: downArrowKeyCode)
    }

    private func isWhitelistToggleShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: wKeyCode)
    }

    private func isFilterToggleShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: fKeyCode)
    }

    private func isQuitShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: qKeyCode)
    }

    private func isQuitOthersShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: xKeyCode)
    }

    private func isHideShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: hKeyCode)
    }

    private func isCancelShortcut(_ event: CGEvent) -> Bool {
        return event.getIntegerValueField(.keyboardEventKeycode) == escapeKeyCode
    }

    private func isCommandShortcut(_ event: CGEvent, keyCode: Int64) -> Bool {
        if event.getIntegerValueField(.keyboardEventKeycode) != keyCode { return false }
        if !event.flags.contains(.maskCommand) { return false }
        return true
    }

    // MARK: switching

    /// The row width is fixed here, so the panel's layout and the row navigation agree even if the main screen changes later.
    private func loadCandidates() {
        candidates = getCandidates()
        iconsPerRow = getIconsPerRow()
    }

    private func getIconsPerRow() -> Int {
        let availableWidth = NSScreen.main!.visibleFrame.width * maxPanelWidthFraction - 2 * horizontalPadding

        return max(1, Int((availableWidth + itemSpacing) / (iconSize + itemSpacing)))
    }

    private func getCandidates() -> [NSRunningApplication] {
        let recentApps = getRecentRunningApps()
        if !isFilterEnabled {
            return recentApps
        }

        let whitelist = getWhitelist()
        let whitelistedApps = recentApps.filter { whitelist.contains($0.bundleIdentifier!) }
        if whitelistedApps.isEmpty {
            return recentApps
        }

        return whitelistedApps
    }

    /// Regular running apps, most recently activated first.
    private func getRecentRunningApps() -> [NSRunningApplication] {
        var appsByIdentifier: [String: NSRunningApplication] = [:]

        for app in getRegularRunningApps() {
            guard let bundleIdentifier = app.bundleIdentifier else { continue }
            appsByIdentifier[bundleIdentifier] = app
        }

        var recentApps: [NSRunningApplication] = []
        for bundleIdentifier in tracker.bundleIdentifiers {
            guard let app = appsByIdentifier[bundleIdentifier] else { continue }
            recentApps.append(app)
        }

        return getAppsWithWindows(recentApps)
    }

    private func advanceSelection(backward: Bool) {
        let step = backward ? -1 : 1
        selectedIndex = (selectedIndex + step + candidates.count) % candidates.count
        panel.update(state: buildState())
    }

    /// Same column one row up or down, wrapping at the top and bottom; a shorter last row clamps to its last icon.
    private func moveSelectionBetweenRows(up: Bool) {
        let rowCount = (candidates.count + iconsPerRow - 1) / iconsPerRow
        let column = selectedIndex % iconsPerRow
        let step = up ? -1 : 1
        let targetRow = (selectedIndex / iconsPerRow + step + rowCount) % rowCount

        selectedIndex = min(targetRow * iconsPerRow + column, candidates.count - 1)
        panel.update(state: buildState())
    }

    /// The selection stays on its app; when that is the one gone, it moves to the neighbour.
    private func removeCandidate(at index: Int) {
        candidates.remove(at: index)
        if candidates.isEmpty {
            panel.hide()
            return
        }

        if index < selectedIndex { selectedIndex -= 1 }
        selectedIndex = min(selectedIndex, candidates.count - 1)
        panel.removeApp(at: index, state: buildState())
    }

    private func toggleFilterAndRefreshCandidates() {
        let selectedIdentifier = candidates[selectedIndex].bundleIdentifier

        toggleFilter()
        loadCandidates()
        if candidates.isEmpty {
            panel.hide()
            return
        }

        selectedIndex = candidates.firstIndex { $0.bundleIdentifier == selectedIdentifier } ?? 0
        panel.show(state: buildState())
    }

    private func buildState() -> SwitcherState {
        return SwitcherState(
            apps: candidates,
            iconsPerRow: iconsPerRow,
            selectedIndex: selectedIndex,
            filterEnabled: isFilterEnabled,
            whitelisted: getWhitelist()
        )
    }

    private func activateSelectedApp() {
        panel.hide()
        candidates[selectedIndex].activate(options: [.activateAllWindows])
    }
}

func handleTappedEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let controller = Unmanaged<AppSwitcherController>.fromOpaque(userInfo!).takeUnretainedValue()
    return controller.handleEvent(type: type, event: event)
}

let application = NSApplication.shared
let controller = AppSwitcherController()

application.setActivationPolicy(.accessory)
application.delegate = controller
application.run()
