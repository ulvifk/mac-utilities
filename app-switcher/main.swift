import AppKit
import ApplicationServices
import CoreGraphics
import QuartzCore

let tabKeyCode: Int64 = 48
let wKeyCode: Int64 = 13
let fKeyCode: Int64 = 3
let qKeyCode: Int64 = 12
let hKeyCode: Int64 = 4
let escapeKeyCode: Int64 = 53
let leftArrowKeyCode: Int64 = 123
let rightArrowKeyCode: Int64 = 124
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

/// A clickable icon cell. hitTest keeps the icon image view from swallowing the click.
final class IconCellView: NSView {
    var index = 0
    var onClick: (Int) -> Void = { _ in }

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
    let selectedIndex: Int
    let filterEnabled: Bool
    let whitelisted: Set<String>
}

final class SwitcherPanel: NSPanel {
    var onCellClicked: (Int) -> Void = { _ in }

    private var highlight = NSView()
    private var iconViews: [NSImageView] = []
    private var whitelistDots: [NSView] = []

    private var nameLabel = NSTextField(labelWithString: "")
    private var nameConstraints: [NSLayoutConstraint] = []

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
        let wasVisible = isVisible

        buildContent(state: state)
        center()
        applySelection(state: state, animated: false)

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
        nameLabel.stringValue = state.apps[state.selectedIndex].localizedName ?? ""

        for (index, dot) in whitelistDots.enumerated() {
            dot.isHidden = !state.whitelisted.contains(state.apps[index].bundleIdentifier ?? "")
        }

        applySelection(state: state, animated: true)
    }

    func hide() {
        orderOut(nil)
    }

    private func buildContent(state: SwitcherState) {
        let iconRows = buildIconRows(state: state)
        iconRows.translatesAutoresizingMaskIntoConstraints = false

        nameLabel = buildNameLabel(text: state.apps[state.selectedIndex].localizedName ?? "")

        highlight = NSView()
        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = highlightCornerRadius

        let container = NSView()
        container.addSubview(highlight)
        container.addSubview(iconRows)
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            iconRows.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalPadding),
            iconRows.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalPadding),
            iconRows.topAnchor.constraint(equalTo: container.topAnchor, constant: verticalPadding),
            iconRows.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -verticalPadding)
        ])

        let rowSize = iconRows.fittingSize
        let contentSize = NSSize(width: rowSize.width + horizontalPadding * 2, height: rowSize.height + verticalPadding * 2)
        container.frame = NSRect(origin: .zero, size: contentSize)
        container.addSubview(buildDimmingView(size: contentSize), positioned: .below, relativeTo: highlight)
        container.addSubview(RimView(frame: container.bounds), positioned: .below, relativeTo: highlight)

        let glass = buildGlassView(size: contentSize)
        glass.contentView = container

        contentView = glass
        setContentSize(contentSize)
    }

    /// Truncates rather than widening the panel: the width comes from the icon row alone.
    private func buildNameLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.setContentCompressionResistancePriority(.init(260), for: .horizontal)
        label.setContentHuggingPriority(.init(1), for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
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

        return dimming
    }

    /// Icons draw as aqua like my-dock's tiles, so system images keep their light variants on the dark glass.
    private func buildIconRows(state: SwitcherState) -> NSStackView {
        let rows = NSStackView()

        rows.orientation = .vertical
        rows.spacing = rowSpacing
        rows.alignment = .centerX
        rows.appearance = NSAppearance(named: .aqua)

        iconViews = []
        whitelistDots = []

        let iconsPerRow = getIconsPerRow()

        for rowStart in stride(from: 0, to: state.apps.count, by: iconsPerRow) {
            let row = NSStackView()

            row.orientation = .horizontal
            row.spacing = itemSpacing

            for index in rowStart..<min(rowStart + iconsPerRow, state.apps.count) {
                let app = state.apps[index]

                row.addArrangedSubview(buildCell(app: app, whitelisted: state.whitelisted.contains(app.bundleIdentifier ?? "")))
            }

            rows.addArrangedSubview(row)
        }

        return rows
    }

    /// Whitelist dot above the icon, room for the selected app name below it, icon centered between them.
    private func buildCell(app: NSRunningApplication, whitelisted: Bool) -> NSView {
        let icon = NSImageView(image: app.icon ?? NSImage())
        let dot = buildWhitelistDot()
        let cell = IconCellView()

        cell.index = iconViews.count
        cell.onClick = { [unowned self] index in self.onCellClicked(index) }

        icon.image?.size = NSSize(width: iconSize, height: iconSize)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        dot.isHidden = !whitelisted

        iconViews.append(icon)
        whitelistDots.append(dot)

        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)
        cell.addSubview(dot)

        NSLayoutConstraint.activate([
            cell.widthAnchor.constraint(equalToConstant: iconSize),
            cell.heightAnchor.constraint(equalToConstant: cellHeight),
            icon.widthAnchor.constraint(equalToConstant: iconSize),
            icon.heightAnchor.constraint(equalToConstant: iconSize),
            icon.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            dot.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: cell.topAnchor, constant: dotCenterFromCellTop)
        ])

        return cell
    }

    private func buildWhitelistDot() -> NSView {
        let dot = NSView()

        dot.wantsLayer = true
        dot.layer?.cornerRadius = dotSize / 2
        dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: dotSize),
            dot.heightAnchor.constraint(equalToConstant: dotSize)
        ])

        return dot
    }

    private func applySelection(state: SwitcherState, animated: Bool) {
        contentView?.layoutSubtreeIfNeeded()
        placeNameUnderSelectedIcon(selectedIndex: state.selectedIndex)
        contentView?.layoutSubtreeIfNeeded()

        let frame = getHighlightFrame(selectedIndex: state.selectedIndex)
        highlight.layer?.backgroundColor = getHighlightColor(filterEnabled: state.filterEnabled).cgColor

        if !animated {
            highlight.frame = frame
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            highlight.animator().frame = frame
        }
    }

    private func placeNameUnderSelectedIcon(selectedIndex: Int) {
        NSLayoutConstraint.deactivate(nameConstraints)

        let icon = iconViews[selectedIndex]

        nameConstraints = [
            nameLabel.centerXAnchor.constraint(equalTo: icon.centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: nameTopSpacing),
            nameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: getNameMaxWidth(selectedIndex: selectedIndex))
        ]
        NSLayoutConstraint.activate(nameConstraints)
    }

    /// The widest a name centered on this icon can be without crossing either panel edge, so it truncates instead of sliding.
    private func getNameMaxWidth(selectedIndex: Int) -> CGFloat {
        let icon = iconViews[selectedIndex]
        let iconFrame = icon.superview!.convert(icon.frame, to: highlight.superview!)
        let iconCenterX = iconFrame.midX
        let containerWidth = highlight.superview!.bounds.width

        return 2 * min(iconCenterX - horizontalPadding, containerWidth - horizontalPadding - iconCenterX)
    }

    /// Hugs the selected icon's squircle rather than boxing the whole cell; the name sits below it, outside.
    private func getHighlightFrame(selectedIndex: Int) -> NSRect {
        let icon = iconViews[selectedIndex]
        let frame = icon.superview!.convert(icon.frame, to: highlight.superview!)

        return frame.insetBy(dx: highlightIconInset, dy: highlightIconInset)
    }

    private func getIconsPerRow() -> Int {
        let availableWidth = NSScreen.main!.visibleFrame.width * maxPanelWidthFraction - 2 * horizontalPadding

        return max(1, Int((availableWidth + itemSpacing) / (iconSize + itemSpacing)))
    }

    private func getHighlightColor(filterEnabled: Bool) -> NSColor {
        if filterEnabled { return filteredHighlightColor }
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
    private var selectedIndex = 0

    private var isOpening = false
    private var commandReleasedWhileOpening = false
    private var pendingAdvance = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        wirePanelClicks()
        observeAppTermination()
        requestAccessibilityTrust()
        startEventTap()
        runSmokeTestIfRequested()
    }

    private func runSmokeTestIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["APP_SWITCHER_SMOKE_TEST"] != nil else { return }

        UserDefaults.standard.set(environment["APP_SWITCHER_SMOKE_FILTER"] == "1", forKey: filterEnabledKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.candidates = self.getCandidates()
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

    private func buildMenu() {
        let menu = NSMenu()

        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "App Switcher")

        filterMenuItem.target = self
        filterMenuItem.state = isFilterEnabled ? .on : .off
        menu.addItem(filterMenuItem)
        menu.addItem(buildHintItem(title: "While switching: W toggles whitelist"))
        menu.addItem(buildHintItem(title: "While switching: F toggles filter"))
        menu.addItem(buildHintItem(title: "While switching: Q quits app"))
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
        candidates = getCandidates()
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

        if isHideShortcut(event) {
            candidates[selectedIndex].hide()
            removeCandidate(at: selectedIndex)
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

    private func isWhitelistToggleShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: wKeyCode)
    }

    private func isFilterToggleShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: fKeyCode)
    }

    private func isQuitShortcut(_ event: CGEvent) -> Bool {
        return isCommandShortcut(event, keyCode: qKeyCode)
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

    private func removeCandidate(at index: Int) {
        candidates.remove(at: index)
        if candidates.isEmpty {
            panel.hide()
            return
        }

        selectedIndex = min(selectedIndex, candidates.count - 1)
        panel.show(state: buildState())
    }

    private func toggleFilterAndRefreshCandidates() {
        let selectedIdentifier = candidates[selectedIndex].bundleIdentifier

        toggleFilter()
        candidates = getCandidates()
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
