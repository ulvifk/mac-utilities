import AppKit
import ApplicationServices
import CoreGraphics

let tabKeyCode: Int64 = 48
let wKeyCode: Int64 = 13
let fKeyCode: Int64 = 3
let leftArrowKeyCode: Int64 = 123
let rightArrowKeyCode: Int64 = 124
let filterEnabledKey = "filterEnabled"
let whitelistKey = "whitelist"

let iconSize: CGFloat = 64
let itemWidth: CGFloat = 104
let itemSpacing: CGFloat = 4
let panelPadding: CGFloat = 20
let badgeSize: CGFloat = 16

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

final class SwitcherPanel: NSPanel {
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

    func show(apps: [NSRunningApplication], selectedIndex: Int, filterEnabled: Bool, whitelistMatched: Bool, whitelisted: Set<String>) {
        let stack = buildStack(apps: apps, selectedIndex: selectedIndex, filterEnabled: filterEnabled, whitelistMatched: whitelistMatched, whitelisted: whitelisted)
        let stackSize = stack.fittingSize
        let contentSize = NSSize(width: stackSize.width + panelPadding * 2, height: stackSize.height + panelPadding * 2)
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentSize))

        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 20
        background.layer?.masksToBounds = true
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.1).cgColor
        background.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: background.centerYAnchor)
        ])

        contentView = background
        setContentSize(contentSize)
        center()
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    private func buildStack(apps: [NSRunningApplication], selectedIndex: Int, filterEnabled: Bool, whitelistMatched: Bool, whitelisted: Set<String>) -> NSStackView {
        let row = NSStackView()

        row.orientation = .horizontal
        row.spacing = itemSpacing

        for (index, app) in apps.enumerated() {
            let isWhitelisted = whitelisted.contains(app.bundleIdentifier ?? "")
            row.addArrangedSubview(buildItemView(app: app, selected: index == selectedIndex, whitelisted: isWhitelisted))
        }

        let stack = NSStackView(views: [buildHeaderPill(filterEnabled: filterEnabled, whitelistMatched: whitelistMatched), row])

        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }

    private func buildHeaderPill(filterEnabled: Bool, whitelistMatched: Bool) -> NSView {
        let label = NSTextField(labelWithString: getHeaderText(filterEnabled: filterEnabled, whitelistMatched: whitelistMatched))
        let pill = NSView()

        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = filterEnabled ? .systemGreen : .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        pill.wantsLayer = true
        pill.layer?.cornerRadius = 10
        pill.layer?.backgroundColor = getPillColor(filterEnabled: filterEnabled).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor)
        ])

        return pill
    }

    private func getPillColor(filterEnabled: Bool) -> NSColor {
        if filterEnabled { return NSColor.systemGreen.withAlphaComponent(0.18) }
        return NSColor.labelColor.withAlphaComponent(0.08)
    }

    private func getHeaderText(filterEnabled: Bool, whitelistMatched: Bool) -> String {
        if !filterEnabled { return "Filter OFF" }
        if !whitelistMatched { return "Filter ON (no whitelisted apps running)" }
        return "Filter ON"
    }

    private func buildItemView(app: NSRunningApplication, selected: Bool, whitelisted: Bool) -> NSView {
        let icon = NSImageView(image: app.icon ?? NSImage())
        let label = NSTextField(labelWithString: app.localizedName ?? "")
        let item = NSStackView(views: [icon, label])

        icon.image?.size = NSSize(width: iconSize, height: iconSize)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: iconSize),
            icon.heightAnchor.constraint(equalToConstant: iconSize)
        ])

        if whitelisted {
            addWhitelistBadge(to: icon)
        }

        label.alignment = .center
        label.font = .systemFont(ofSize: 11)
        label.textColor = selected ? .labelColor : .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1

        item.orientation = .vertical
        item.alignment = .centerX
        item.spacing = 8
        item.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        item.translatesAutoresizingMaskIntoConstraints = false
        item.widthAnchor.constraint(equalToConstant: itemWidth).isActive = true

        if selected {
            item.wantsLayer = true
            item.layer?.cornerRadius = 12
            item.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
        }

        return item
    }

    private func addWhitelistBadge(to icon: NSImageView) {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [.white, .systemGreen])
            .applying(NSImage.SymbolConfiguration(pointSize: badgeSize, weight: .bold))
        let symbol = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Whitelisted")!
        let badge = NSImageView(image: symbol.withSymbolConfiguration(configuration)!)
        let ringSize = badgeSize + 4

        badge.imageScaling = .scaleProportionallyDown
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.white.cgColor
        badge.layer?.cornerRadius = ringSize / 2
        badge.translatesAutoresizingMaskIntoConstraints = false
        icon.addSubview(badge)

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: ringSize),
            badge.heightAnchor.constraint(equalToConstant: ringSize),
            badge.trailingAnchor.constraint(equalTo: icon.trailingAnchor, constant: -2),
            badge.topAnchor.constraint(equalTo: icon.topAnchor, constant: 2)
        ])
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
        renderPanel()
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
            renderPanel()
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
        renderPanel()
    }

    private func toggleFilterAndRefreshCandidates() {
        let selectedIdentifier = candidates[selectedIndex].bundleIdentifier

        toggleFilter()
        candidates = getCandidates()

        selectedIndex = candidates.firstIndex { $0.bundleIdentifier == selectedIdentifier } ?? 0
        renderPanel()
    }

    private func renderPanel() {
        panel.show(apps: candidates, selectedIndex: selectedIndex, filterEnabled: isFilterEnabled, whitelistMatched: hasWhitelistedAppRunning(), whitelisted: getWhitelist())
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
