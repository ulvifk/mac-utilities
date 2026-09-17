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
let panelPadding: CGFloat = 20
let dotSize: CGFloat = 5
let dotSpacing: CGFloat = 6
let keycapSize: CGFloat = 18
let selectedIconScale: CGFloat = 1.12

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
    private var iconCells: [NSView] = []
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    func show(state: SwitcherState) {
        let wasVisible = isVisible

        buildContent(state: state)
        center()
        centerIconAnchorPoints()
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
        let hintRow = buildHintRow()

        nameLabel = NSTextField(labelWithString: state.apps[state.selectedIndex].localizedName ?? "")
        nameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center

        statusLabel = NSTextField(labelWithString: getStatusText(state: state))
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center

        let stack = NSStackView(views: [iconRow, nameLabel, statusLabel, hintRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(2, after: nameLabel)
        stack.setCustomSpacing(14, after: statusLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        highlight = NSView()
        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = 18

        let container = NSView()
        container.addSubview(highlight)
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: panelPadding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -panelPadding),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: panelPadding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -panelPadding)
        ])

        let stackSize = stack.fittingSize
        let contentSize = NSSize(width: stackSize.width + panelPadding * 2, height: stackSize.height + panelPadding * 2)
        container.frame = NSRect(origin: .zero, size: contentSize)

        let glass = NSGlassEffectView(frame: container.frame)
        glass.style = .regular
        glass.cornerRadius = 28
        glass.contentView = container

        contentView = glass
        setContentSize(contentSize)
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

        iconCells = []
        iconViews = []
        whitelistDots = []

        for app in state.apps {
            let cell = buildCell(app: app, whitelisted: state.whitelisted.contains(app.bundleIdentifier ?? ""))
            iconCells.append(cell)
            row.addArrangedSubview(cell)
        }

        return row
    }

    private func buildCell(app: NSRunningApplication, whitelisted: Bool) -> NSView {
        let icon = NSImageView(image: app.icon ?? NSImage())
        let dot = buildWhitelistDot()
        let cell = NSView()
        let topInset = (cellSize - (iconSize + dotSpacing + dotSize)) / 2

        icon.image?.size = NSSize(width: iconSize, height: iconSize)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
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
            icon.topAnchor.constraint(equalTo: cell.topAnchor, constant: topInset),
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

    private func buildHintRow() -> NSStackView {
        let row = NSStackView(views: [buildKeycap(letter: "W", label: "Whitelist"), buildKeycap(letter: "F", label: "Filter")])

        row.orientation = .horizontal
        row.spacing = 16

        return row
    }

    private func buildKeycap(letter: String, label: String) -> NSView {
        let letterLabel = NSTextField(labelWithString: letter)
        let key = NSView()
        let text = NSTextField(labelWithString: label)

        letterLabel.font = .systemFont(ofSize: 10, weight: .medium)
        letterLabel.textColor = .secondaryLabelColor
        letterLabel.alignment = .center
        letterLabel.translatesAutoresizingMaskIntoConstraints = false

        key.wantsLayer = true
        key.layer?.cornerRadius = 4
        key.layer?.borderWidth = 1
        key.layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.25).cgColor
        key.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
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

    private func centerIconAnchorPoints() {
        contentView?.layoutSubtreeIfNeeded()

        for icon in iconViews {
            let center = CGPoint(x: icon.frame.midX, y: icon.frame.midY)
            icon.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            icon.layer?.position = center
        }
    }

    private func applySelection(state: SwitcherState, animated: Bool) {
        contentView?.layoutSubtreeIfNeeded()

        let cell = iconCells[state.selectedIndex]
        let frame = cell.superview!.convert(cell.frame, to: highlight.superview!)
        highlight.layer?.backgroundColor = getHighlightColor(filterEnabled: state.filterEnabled).cgColor

        if !animated {
            highlight.frame = frame
            scaleIcons(selectedIndex: state.selectedIndex)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            highlight.animator().frame = frame
            scaleIcons(selectedIndex: state.selectedIndex)
        }
    }

    private func scaleIcons(selectedIndex: Int) {
        for (index, icon) in iconViews.enumerated() {
            let scale: CGFloat = index == selectedIndex ? selectedIconScale : 1
            icon.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
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
        guard ProcessInfo.processInfo.environment["APP_SWITCHER_SMOKE_TEST"] != nil else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.candidates = self.getCandidates()
            self.selectedIndex = 0
            self.panel.show(state: self.buildState())
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("smoke: frame=\(self.panel.frame) visible=\(self.panel.isVisible) alpha=\(self.panel.alphaValue)")
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
