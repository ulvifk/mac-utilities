import AppKit
import ApplicationServices
import CoreGraphics
import QuartzCore

let tabKeyCode: Int64 = 48
let wKeyCode: Int64 = 13
let fKeyCode: Int64 = 3
let leftArrowKeyCode: Int64 = 123
let rightArrowKeyCode: Int64 = 124
let filterEnabledKey = "filterEnabled"
let whitelistKey = "whitelist"

let iconSize: CGFloat = 64
let cellSize: CGFloat = 84
let itemSpacing: CGFloat = 4
let horizontalPadding: CGFloat = 14
let verticalPadding: CGFloat = 12
let dotSize: CGFloat = 5
let dotSpacing: CGFloat = 4
let keycapSize: CGFloat = 16
let panelCornerRadius: CGFloat = 28
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

/// Colorful window behind the panel, so the capture shows what the glass is blurring.
var captureBackdrop: NSWindow?

func showCaptureBackdrop(behind window: NSWindow) {
    let backdrop = NSWindow(contentRect: window.frame.insetBy(dx: -80, dy: -80), styleMask: .borderless, backing: .buffered, defer: false)
    let gradient = CAGradientLayer()

    gradient.frame = NSRect(origin: .zero, size: backdrop.frame.size)
    gradient.colors = [NSColor.systemPink.cgColor, NSColor.systemOrange.cgColor, NSColor.white.cgColor, NSColor.systemTeal.cgColor, NSColor.systemIndigo.cgColor]
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

struct SwitcherState {
    let apps: [NSRunningApplication]
    let selectedIndex: Int
    let filterEnabled: Bool
    let whitelistMatched: Bool
    let whitelisted: Set<String>
}

final class SwitcherPanel: NSPanel {
    private var highlight = NSView()
    private var iconViews: [NSImageView] = []
    private var whitelistDots: [NSView] = []

    private var nameLabel = NSTextField(labelWithString: "")
    private var statusLabel = NSTextField(labelWithString: "")

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
        hasShadow = true
        hidesOnDeactivate = false
        appearance = NSAppearance(named: .darkAqua)
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
        statusLabel.stringValue = getStatusText(state: state)

        for (index, dot) in whitelistDots.enumerated() {
            dot.isHidden = !state.whitelisted.contains(state.apps[index].bundleIdentifier ?? "")
        }

        applySelection(state: state, animated: true)
    }

    func hide() {
        orderOut(nil)
    }

    private func buildContent(state: SwitcherState) {
        let iconRow = buildIconRow(state: state)
        let footerRow = buildFooterRow(state: state)

        nameLabel = NSTextField(labelWithString: state.apps[state.selectedIndex].localizedName ?? "")
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center

        let stack = NSStackView(views: [iconRow, nameLabel, footerRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.setCustomSpacing(3, after: nameLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        highlight = NSView()
        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = 18

        let container = NSView()
        container.addSubview(highlight)
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalPadding),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: verticalPadding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -verticalPadding)
        ])

        let stackSize = stack.fittingSize
        let contentSize = NSSize(width: stackSize.width + horizontalPadding * 2, height: stackSize.height + verticalPadding * 2)
        container.frame = NSRect(origin: .zero, size: contentSize)

        container.wantsLayer = true
        container.layer?.cornerRadius = panelCornerRadius
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor

        let glass = buildGlassView(size: contentSize)
        glass.contentView = container

        contentView = glass
        setContentSize(contentSize)
    }

    private func buildGlassView(size: NSSize) -> NSGlassEffectView {
        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))

        glass.style = .regular
        glass.cornerRadius = panelCornerRadius
        glass.tintColor = NSColor.black.withAlphaComponent(0.28)

        return glass
    }

    private func getStatusText(state: SwitcherState) -> String {
        if !state.filterEnabled { return "All apps" }
        if !state.whitelistMatched { return "No whitelisted apps running, showing all" }
        return "Whitelisted apps"
    }

    private func buildIconRow(state: SwitcherState) -> NSStackView {
        let row = NSStackView()

        row.orientation = .horizontal
        row.spacing = itemSpacing

        iconViews = []
        whitelistDots = []

        for app in state.apps {
            row.addArrangedSubview(buildCell(app: app, whitelisted: state.whitelisted.contains(app.bundleIdentifier ?? "")))
        }

        return row
    }

    /// A square cell with the icon centered in it, so the selection highlight is centered on the icon.
    private func buildCell(app: NSRunningApplication, whitelisted: Bool) -> NSView {
        let icon = NSImageView(image: app.icon ?? NSImage())
        let dot = buildWhitelistDot()
        let cell = NSView()

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
            cell.widthAnchor.constraint(equalToConstant: cellSize),
            cell.heightAnchor.constraint(equalToConstant: cellSize),
            icon.widthAnchor.constraint(equalToConstant: iconSize),
            icon.heightAnchor.constraint(equalToConstant: iconSize),
            icon.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            dot.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            dot.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: dotSpacing)
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

    /// Status text and the keycap hints on one line.
    private func buildFooterRow(state: SwitcherState) -> NSStackView {
        statusLabel = NSTextField(labelWithString: getStatusText(state: state))
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        let row = NSStackView(views: [statusLabel, buildKeycap(letter: "W", label: "Whitelist"), buildKeycap(letter: "F", label: "Filter")])

        row.orientation = .horizontal
        row.spacing = 14

        return row
    }

    private func buildKeycap(letter: String, label: String) -> NSView {
        let letterLabel = NSTextField(labelWithString: letter)
        let key = NSView()
        let text = NSTextField(labelWithString: label)

        letterLabel.font = .systemFont(ofSize: 9, weight: .medium)
        letterLabel.textColor = .labelColor
        letterLabel.alignment = .center
        letterLabel.translatesAutoresizingMaskIntoConstraints = false

        key.wantsLayer = true
        key.layer?.cornerRadius = 4
        key.layer?.borderWidth = 1
        key.layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.35).cgColor
        key.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
        key.translatesAutoresizingMaskIntoConstraints = false
        key.addSubview(letterLabel)

        NSLayoutConstraint.activate([
            key.widthAnchor.constraint(equalToConstant: keycapSize),
            key.heightAnchor.constraint(equalToConstant: keycapSize),
            letterLabel.centerXAnchor.constraint(equalTo: key.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: key.centerYAnchor)
        ])

        text.font = .systemFont(ofSize: 11)
        text.textColor = .tertiaryLabelColor

        let hint = NSStackView(views: [key, text])
        hint.orientation = .horizontal
        hint.spacing = 6

        return hint
    }

    private func applySelection(state: SwitcherState, animated: Bool) {
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

    /// A cell-sized square centered on the selected icon, so the highlight is centered whatever the row layout does.
    private func getHighlightFrame(selectedIndex: Int) -> NSRect {
        let icon = iconViews[selectedIndex]
        let center = icon.superview!.convert(CGPoint(x: icon.frame.midX, y: icon.frame.midY), to: highlight.superview!)

        return NSRect(x: center.x - cellSize / 2, y: center.y - cellSize / 2, width: cellSize, height: cellSize)
    }

    private func getHighlightColor(filterEnabled: Bool) -> NSColor {
        if filterEnabled { return NSColor.systemGreen.withAlphaComponent(0.22) }
        return NSColor.labelColor.withAlphaComponent(0.12)
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
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
            writeCapture(around: self.panel, path: smokeCapturePath)
            exit(0)
        }
    }

    // MARK: menu

    private func buildMenu() {
        let menu = NSMenu()

        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "App Switcher")

        filterMenuItem.target = self
        filterMenuItem.state = isFilterEnabled ? .on : .off
        menu.addItem(filterMenuItem)
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
        if type == .tapDisabledByTimeout {
            CGEvent.tapEnable(tap: eventTap!, enable: true)
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

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if panel.isVisible {
            return handleKeyDownWhileVisible(event)
        }

        if !isSwitcherShortcut(event) {
            return Unmanaged.passUnretained(event)
        }

        candidates = getCandidates()
        selectedIndex = candidates.count > 1 ? 1 : 0
        panel.show(state: buildState())
        return nil
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
            toggleFilterAndRefreshCandidates()
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if !panel.isVisible {
            return Unmanaged.passUnretained(event)
        }

        if event.flags.contains(.maskCommand) {
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

        return recentApps
    }

    private func hasWhitelistedAppRunning() -> Bool {
        let whitelist = getWhitelist()
        return getRegularRunningApps().contains { whitelist.contains($0.bundleIdentifier ?? "") }
    }

    private func advanceSelection(backward: Bool) {
        let step = backward ? -1 : 1
        selectedIndex = (selectedIndex + step + candidates.count) % candidates.count
        panel.update(state: buildState())
    }

    private func toggleFilterAndRefreshCandidates() {
        let selectedIdentifier = candidates[selectedIndex].bundleIdentifier

        toggleFilter()
        candidates = getCandidates()

        selectedIndex = candidates.firstIndex { $0.bundleIdentifier == selectedIdentifier } ?? 0
        panel.show(state: buildState())
    }

    private func buildState() -> SwitcherState {
        return SwitcherState(
            apps: candidates,
            selectedIndex: selectedIndex,
            filterEnabled: isFilterEnabled,
            whitelistMatched: hasWhitelistedAppRunning(),
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
