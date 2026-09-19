import AppKit
import ApplicationServices
import UniformTypeIdentifiers

let stripHeight: CGFloat = 60
let stripEndPadding: CGFloat = 3.2
let stripCornerRadius: CGFloat = 24
let stripDimmingColor = NSColor.black.withAlphaComponent(0.3)
let stripBottomMargin: CGFloat = 5

let iconSize: CGFloat = 46
let iconTopInset: CGFloat = 7
let runningDotDiameter: CGFloat = 4
let runningDotCenterFromBottom: CGFloat = 6
let runningDotColor = NSColor.white.withAlphaComponent(0.58)
let separatorVerticalInset: CGFloat = 8
let separatorColor = NSColor.white.withAlphaComponent(0.3)
let chevronWidth: CGFloat = 5
let chevronHeight: CGFloat = 9
let chevronLineWidth: CGFloat = 1.5
let chevronColor = NSColor.white.withAlphaComponent(0.55)
let badgeHeight: CGFloat = 18
let badgeHorizontalPadding: CGFloat = 1.5
let badgeInsetFromIconRight: CGFloat = 1
let badgeColor = NSColor.systemRed
let badgeTextAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: NSColor.white]

/// Transparent band above the strip that the hover tooltip is drawn in; clicks fall through its clear pixels.
let tooltipZoneHeight: CGFloat = 44
let tooltipPillHeight: CGFloat = 26
let tooltipHorizontalPadding: CGFloat = 13.5
let tooltipCaretWidth: CGFloat = 14
let tooltipCaretHeight: CGFloat = 8
let tooltipGapAboveStrip: CGFloat = 1
let tooltipTextAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white]
/// tintColor lifts the glass toward Apple's tooltip tone; the caret is solid in that same tone.
let tooltipTintColor = NSColor.white.withAlphaComponent(0.3)
let tooltipCaretColor = NSColor(white: 0.3, alpha: 0.85)

let hideUnpinnedKey = "hideUnpinned"
/// Apple's Dock settings as they were before we hid it, restored on quit.
let restoreAutohideKey = "restoreAutohide"
let restoreAutohideDelayKey = "restoreAutohideDelay"
let hiddenDockAutohideDelay = 1000.0
let finderPath = "/System/Library/CoreServices/Finder.app"
let dockDefaults = UserDefaults(suiteName: "com.apple.dock")!
/// Pinning happens by drag and drop in Apple's Dock, which fires no workspace notification.
let refreshInterval: TimeInterval = 2
let smokeCapturePath = "/tmp/my-dock-smoke.png"

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

enum DockItemKind {
    case app
    case separator
    case trash
}

enum ToggleHandle {
    case collapse
    case expand
}

struct DockItem {
    let kind: DockItemKind
    let name: String
    let url: URL?
    let isRunning: Bool
    let badge: String?
    let width: CGFloat

    /// Set on the separator that draws the chevron instead of a line.
    var toggleHandle: ToggleHandle? = nil
}

/// Apple's Dock item list through Accessibility. The frame is in top-left screen coordinates.
/// Nil while the Dock is absent or still starting: we restart it ourselves with killall, so that state is expected for a second.
func readDockItems() -> (frame: CGRect, items: [DockItem])? {
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
    let application = AXUIElementCreateApplication(dock.processIdentifier)
    guard let children = getAttribute(application, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
    let list = children.first { getAttribute($0, kAXRoleAttribute) as? String == "AXList" }!
    let items = (getAttribute(list, kAXChildrenAttribute) as! [AXUIElement]).map(buildDockItem)

    return (getFrame(list), items)
}

func buildDockItem(_ element: AXUIElement) -> DockItem {
    let subrole = getAttribute(element, kAXSubroleAttribute) as! String

    return DockItem(
        kind: getDockItemKind(subrole: subrole),
        name: getAttribute(element, kAXTitleAttribute) as? String ?? "",
        url: getAttribute(element, kAXURLAttribute) as? URL,
        isRunning: getAttribute(element, "AXIsApplicationRunning") as? Bool ?? false,
        badge: getBadge(element, subrole: subrole),
        width: getFrame(element).width
    )
}

/// Only application items carry a count here; Handoff items put their device id in the same attribute.
func getBadge(_ element: AXUIElement, subrole: String) -> String? {
    if subrole != "AXApplicationDockItem" { return nil }
    return getAttribute(element, "AXStatusLabel") as? String
}

func getDockItemKind(subrole: String) -> DockItemKind {
    if subrole == "AXSeparatorDockItem" { return .separator }
    if subrole == "AXTrashDockItem" { return .trash }
    return .app
}

func getAttribute(_ element: AXUIElement, _ name: String) -> Any? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

func getFrame(_ element: AXUIElement) -> CGRect {
    var frame = CGRect.zero
    AXValueGetValue(getAttribute(element, "AXFrame") as! AXValue, .cgRect, &frame)
    return frame
}

/// Handoff items (an iPhone app advertised through Handoff) carry no URL and get the generic application icon.
/// Finder plus the standardized bundle paths of the Dock's persistent-apps tiles.
func readPinnedPaths() -> Set<String> {
    let tiles = dockDefaults.array(forKey: "persistent-apps") as! [[String: Any]]
    let paths = tiles.map { tile -> String in
        let fileData = (tile["tile-data"] as! [String: Any])["file-data"] as! [String: Any]
        return URL(string: fileData["_CFURLString"] as! String)!.standardizedFileURL.path
    }

    return Set(paths + [finderPath])
}

/// Copies the Dock's own separator (the one before the Trash) in front of the first unpinned app. Handoff items count as unpinned.
func insertGroupSeparator(into items: [DockItem], pinned: Set<String>) -> [DockItem] {
    guard let firstUnpinned = items.firstIndex(where: { isUnpinnedApp($0, pinned: pinned) }) else { return items }
    if items[firstUnpinned - 1].kind == .separator { return items }

    var grouped = items
    grouped.insert(items.first { $0.kind == .separator }!, at: firstUnpinned)
    return grouped
}

/// Drops the unpinned apps and the separator in front of them; the Trash keeps its own separator.
func filterHiddenItems(_ items: [DockItem], pinned: Set<String>) -> [DockItem] {
    guard let firstUnpinned = items.firstIndex(where: { isUnpinnedApp($0, pinned: pinned) }) else { return items }

    let pinnedGroup = items[..<(firstUnpinned - 1)]
    let trashGroup = items[firstUnpinned...].filter { !isUnpinnedApp($0, pinned: pinned) }
    return Array(pinnedGroup) + trashGroup
}

/// Marks the separator at the pinned/unpinned boundary: before the first unpinned app, or before the Trash once those are hidden.
func markToggleHandle(_ items: [DockItem], pinned: Set<String>, handle: ToggleHandle) -> [DockItem] {
    let firstUnpinned = items.firstIndex { isUnpinnedApp($0, pinned: pinned) }
    let boundary = firstUnpinned ?? items.firstIndex { $0.kind == .trash }!

    var marked = items
    marked[boundary - 1].toggleHandle = handle
    return marked
}

func isUnpinnedApp(_ item: DockItem, pinned: Set<String>) -> Bool {
    if item.kind != .app { return false }
    return !isPinned(item, pinned: pinned)
}

func isPinned(_ item: DockItem, pinned: Set<String>) -> Bool {
    guard let url = item.url else { return false }
    return pinned.contains(url.standardizedFileURL.path)
}

func getRunningApplication(at url: URL) -> NSRunningApplication {
    let path = url.standardizedFileURL.path
    return NSWorkspace.shared.runningApplications.first { $0.bundleURL?.standardizedFileURL.path == path }!
}

/// Activation alone leaves a fully minimized app in the Dock's minimized state; restoring one window brings it back like Apple's Dock.
func restoreWindowIfAllMinimized(of app: NSRunningApplication) {
    let windows = getAttribute(AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute) as? [AXUIElement] ?? []
    guard let first = windows.first else { return }
    if !windows.allSatisfy(isMinimized) { return }

    AXUIElementSetAttributeValue(first, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
}

func isMinimized(_ window: AXUIElement) -> Bool {
    return getAttribute(window, kAXMinimizedAttribute) as? Bool ?? false
}

/// Trash opens in Finder; a stopped app launches; a running one comes to the front. Handoff items (no URL) do nothing.
func open(_ item: DockItem) {
    if item.kind == .trash {
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
        return
    }

    guard let url = item.url else { return }
    if !item.isRunning {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        return
    }

    let app = getRunningApplication(at: url)
    app.activate(options: [.activateAllWindows])
    restoreWindowIfAllMinimized(of: app)
}

func getIcon(_ item: DockItem) -> NSImage {
    if item.kind == .trash { return NSImage(named: isTrashFull() ? NSImage.trashFullName : NSImage.trashEmptyName)! }
    guard let url = item.url else { return NSWorkspace.shared.icon(for: .applicationBundle) }

    return NSWorkspace.shared.icon(forFile: url.path)
}

/// ~/.Trash cannot be listed without Full Disk Access, but APFS reports a directory's link count as entries + 2.
func isTrashFull() -> Bool {
    let attributes = try! FileManager.default.attributesOfItem(atPath: NSHomeDirectory() + "/.Trash")
    return attributes[.referenceCount] as! Int > 2
}

/// Draws the tiles left to right in top-left coordinates, so every inset reads as a distance from the strip's top.
final class DockStripView: NSView {
    var onSeparatorClicked: () -> Void = {}
    var onTileClicked: (DockItem) -> Void = { _ in }
    var onTileHovered: (DockItem, CGFloat) -> Void = { _, _ in }
    var onHoverEnded: () -> Void = {}

    var items: [DockItem] = [] {
        didSet { needsDisplay = true }
    }

    private var hoveredTileIndex: Int?

    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        drawDimming()

        for (item, cell) in zip(items, getCellFrames()) {
            drawItem(item, cell: cell)
        }
    }

    /// Regular glass renders lighter than the backdrop and tintColor only brightens it further; the 1pt rim is left undimmed.
    private func drawDimming() {
        let inset = bounds.insetBy(dx: 1, dy: 1)

        stripDimmingColor.setFill()
        NSBezierPath(roundedRect: inset, xRadius: stripCornerRadius - 1, yRadius: stripCornerRadius - 1).fill()
    }

    private func drawItem(_ item: DockItem, cell: NSRect) {
        if let handle = item.toggleHandle {
            drawChevron(handle, centerX: cell.midX)
            return
        }

        if item.kind == .separator {
            drawSeparator(centerX: cell.midX)
            return
        }

        let iconRect = NSRect(x: cell.midX - iconSize / 2, y: iconTopInset, width: iconSize, height: iconSize)
        getIcon(item).draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        if let badge = item.badge { drawBadge(badge, iconRect: iconRect) }
        if item.isRunning { drawRunningDot(centerX: cell.midX) }
    }

    /// Red count on the icon's top-right corner like Apple's: a circle for short counts, a pill for longer ones.
    private func drawBadge(_ badge: String, iconRect: NSRect) {
        let textSize = (badge as NSString).size(withAttributes: badgeTextAttributes)
        let width = max(badgeHeight, ceil(textSize.width) + 2 * badgeHorizontalPadding)
        let rect = NSRect(x: iconRect.maxX - badgeInsetFromIconRight - width, y: iconRect.minY, width: width, height: badgeHeight)

        badgeColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2).fill()
        (badge as NSString).draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2), withAttributes: badgeTextAttributes)
    }

    /// Apple's Dock snaps the dot to whole pixels; a fractional center would smear a 4px circle over 5 columns.
    private func drawRunningDot(centerX: CGFloat) {
        let rect = NSRect(
            x: round(centerX) - runningDotDiameter / 2,
            y: stripHeight - runningDotCenterFromBottom - runningDotDiameter / 2,
            width: runningDotDiameter,
            height: runningDotDiameter
        )

        runningDotColor.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    /// Snapped like the dot: the second separator lands on a fractional center, which would smear the line over two columns.
    private func drawSeparator(centerX: CGFloat) {
        let rect = NSRect(x: round(centerX), y: separatorVerticalInset, width: 1, height: stripHeight - 2 * separatorVerticalInset)

        separatorColor.setFill()
        rect.fill()
    }

    /// Replaces the separator line with a chevron on the same pixel column and center: "<" collapses the unpinned group, ">" expands it.
    private func drawChevron(_ handle: ToggleHandle, centerX: CGFloat) {
        let direction: CGFloat = handle == .collapse ? -1 : 1
        let center = NSPoint(x: round(centerX) + 0.5, y: stripHeight / 2)
        let tipX = center.x + direction * chevronWidth / 2
        let baseX = center.x - direction * chevronWidth / 2

        let path = NSBezierPath()
        path.move(to: NSPoint(x: baseX, y: center.y - chevronHeight / 2))
        path.line(to: NSPoint(x: tipX, y: center.y))
        path.line(to: NSPoint(x: baseX, y: center.y + chevronHeight / 2))
        path.lineWidth = chevronLineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        chevronColor.setStroke()
        path.stroke()
    }

    // MARK: mouse

    /// The panel never becomes key, so the first click must reach the view directly.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        guard let item = getItem(at: convert(event.locationInWindow, from: nil)) else { return }

        if item.kind == .separator {
            onSeparatorClicked()
            return
        }

        onTileClicked(item)
    }

    /// Cursor rects and cursorUpdate only work in the key window, so the cursor is set by hand from mouse moves.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        updateCursor(at: point)
        updateHoveredTile(getTileIndex(at: point))
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        updateHoveredTile(nil)
    }

    private func updateCursor(at point: NSPoint) {
        if isSeparator(at: point) {
            NSCursor.pointingHand.set()
            return
        }

        NSCursor.arrow.set()
    }

    /// Reports only changes, with the tile's center x, so the tooltip is not rebuilt on every mouse move.
    private func updateHoveredTile(_ index: Int?) {
        if index == hoveredTileIndex { return }
        hoveredTileIndex = index

        guard let index else { onHoverEnded(); return }
        onTileHovered(items[index], getCellFrames()[index].midX)
    }

    private func isSeparator(at point: NSPoint) -> Bool {
        return getItem(at: point)?.kind == .separator
    }

    private func getItem(at point: NSPoint) -> DockItem? {
        return zip(items, getCellFrames()).first { $0.1.contains(point) }?.0
    }

    /// Index of the app or trash cell under the point; separators and empty space give nil.
    private func getTileIndex(at point: NSPoint) -> Int? {
        guard let index = getCellFrames().firstIndex(where: { $0.contains(point) }) else { return nil }
        if items[index].kind == .separator { return nil }
        return index
    }

    /// One full-height cell per item, left to right from the end padding; drawing and hit testing share them.
    func getCellFrames() -> [NSRect] {
        var frames: [NSRect] = []
        var cellX = stripEndPadding

        for item in items {
            frames.append(NSRect(x: cellX, y: 0, width: item.width, height: stripHeight))
            cellX += item.width
        }

        return frames
    }
}

/// Name pill with a downward caret above the hovered tile, like Apple's Dock tooltip. The caret is solid in the pill's tone, since glass cannot take that shape.
final class TooltipView: NSView {
    var text = "" {
        didSet { layoutText() }
    }

    private let glass = NSGlassEffectView()
    private let textView = TooltipTextView()

    convenience init() {
        self.init(frame: .zero)

        glass.style = .regular
        glass.cornerRadius = tooltipPillHeight / 2
        glass.tintColor = tooltipTintColor
        glass.contentView = textView
        addSubview(glass)
    }

    override func draw(_ dirtyRect: NSRect) {
        let caret = NSBezierPath()
        let centerX = bounds.midX

        caret.move(to: NSPoint(x: centerX - tooltipCaretWidth / 2, y: tooltipCaretHeight))
        caret.line(to: NSPoint(x: centerX + tooltipCaretWidth / 2, y: tooltipCaretHeight))
        caret.line(to: NSPoint(x: centerX, y: 0))
        caret.close()

        tooltipCaretColor.setFill()
        caret.fill()
    }

    private func layoutText() {
        let width = ceil((text as NSString).size(withAttributes: tooltipTextAttributes).width) + 2 * tooltipHorizontalPadding

        frame.size = NSSize(width: width, height: tooltipPillHeight + tooltipCaretHeight)
        glass.frame = NSRect(x: 0, y: tooltipCaretHeight, width: width, height: tooltipPillHeight)
        textView.frame = glass.bounds
        textView.text = text
        needsDisplay = true
    }
}

/// Centers the name's line box in the pill, which lands the capitals on the pill's center like Apple's tooltip.
final class TooltipTextView: NSView {
    var text = "" {
        didSet { needsDisplay = true }
    }

    /// Font smoothing thickens white text on a transparent layer; Apple's tooltip text is lighter than that.
    override func draw(_ dirtyRect: NSRect) {
        let size = (text as NSString).size(withAttributes: tooltipTextAttributes)
        let origin = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)

        NSGraphicsContext.current!.cgContext.setShouldSmoothFonts(false)
        (text as NSString).draw(at: origin, withAttributes: tooltipTextAttributes)
    }
}

final class MyDockController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hideUnpinnedMenuItem = NSMenuItem(title: "Hide unpinned apps", action: #selector(toggleHideUnpinned), keyEquivalent: "")

    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let content = NSView()
    private let glass = NSGlassEffectView()
    private let strip = DockStripView()
    private let tooltip = TooltipView()

    private var dock = (frame: CGRect.zero, items: [DockItem]())

    /// The smoke test goes first because it writes the preferences the menu and the first render read.
    func applicationDidFinishLaunching(_ notification: Notification) {
        runSmokeTestIfRequested()
        buildMenu()
        buildWindow()
        requestAccessibilityTrust()
        observeApplicationChanges()
        scheduleRefresh()
        render()
        hideAppleDock()
    }

    func applicationWillTerminate(_ notification: Notification) {
        restoreAppleDock()
    }

    // MARK: Apple's Dock

    /// Autohide with a huge delay keeps Apple's Dock off screen while its item list stays readable. The previous settings are kept
    /// in our defaults until a clean quit restores them, so a crash or kill does not lose them.
    private func hideAppleDock() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: restoreAutohideKey) == nil {
            defaults.set(dockDefaults.bool(forKey: "autohide"), forKey: restoreAutohideKey)
            defaults.set(dockDefaults.object(forKey: "autohide-delay"), forKey: restoreAutohideDelayKey)
        }

        dockDefaults.set(true, forKey: "autohide")
        dockDefaults.set(hiddenDockAutohideDelay, forKey: "autohide-delay")
        dockDefaults.synchronize()
        restartAppleDock()
    }

    private func restoreAppleDock() {
        let defaults = UserDefaults.standard

        dockDefaults.set(defaults.bool(forKey: restoreAutohideKey), forKey: "autohide")
        dockDefaults.set(defaults.object(forKey: restoreAutohideDelayKey), forKey: "autohide-delay")
        dockDefaults.synchronize()
        defaults.removeObject(forKey: restoreAutohideKey)
        defaults.removeObject(forKey: restoreAutohideDelayKey)
        restartAppleDock()
    }

    private func restartAppleDock() {
        let killall = Process()

        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Dock"]
        try! killall.run()
        killall.waitUntilExit()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

        statusItem.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "My Dock")
        hideUnpinnedMenuItem.target = self
        hideUnpinnedMenuItem.state = isHideUnpinnedEnabled ? .on : .off
        quitItem.target = self

        menu.addItem(hideUnpinnedMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func toggleHideUnpinned() {
        UserDefaults.standard.set(!isHideUnpinnedEnabled, forKey: hideUnpinnedKey)
        hideUnpinnedMenuItem.state = isHideUnpinnedEnabled ? .on : .off
        render()
    }

    private var isHideUnpinnedEnabled: Bool {
        return UserDefaults.standard.bool(forKey: hideUnpinnedKey)
    }

    /// Apple's Dock draws the light trash variant in both appearances, so the content draws as aqua.
    /// A borderless non-activating panel cannot become key, so clicks on the strip never move focus.
    private func buildWindow() {
        glass.style = .regular
        glass.cornerRadius = stripCornerRadius
        glass.contentView = strip
        strip.appearance = NSAppearance(named: .aqua)
        strip.onSeparatorClicked = { [unowned self] in self.toggleHideUnpinned() }
        strip.onTileClicked = { item in open(item) }
        strip.onTileHovered = { [unowned self] item, centerX in self.showTooltip(for: item, centerX: centerX) }
        strip.onHoverEnded = { [unowned self] in self.tooltip.isHidden = true }

        tooltip.isHidden = true
        content.addSubview(glass)
        content.addSubview(tooltip)

        panel.contentView = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    private func requestAccessibilityTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) { return }

        print("Accessibility permission not granted: grant it in System Settings > Privacy & Security > Accessibility, then relaunch.")
    }

    private func observeApplicationChanges() {
        let names = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ]

        for name in names {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in self.render() }
        }
    }

    private func scheduleRefresh() {
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in self.render() }
    }

    private func render() {
        guard let dock = readDockItems() else { return }
        self.dock = dock

        let pinned = readPinnedPaths()
        let grouped = insertGroupSeparator(into: dock.items, pinned: pinned)
        let visible = isHideUnpinnedEnabled ? filterHiddenItems(grouped, pinned: pinned) : grouped
        let items = markToggleHandle(visible, pinned: pinned, handle: isHideUnpinnedEnabled ? .expand : .collapse)

        let screen = NSScreen.main!.frame
        let width = stripEndPadding * 2 + items.reduce(0) { $0 + $1.width }
        let frame = NSRect(x: screen.midX - width / 2, y: screen.minY + stripBottomMargin, width: width, height: stripHeight + tooltipZoneHeight)

        panel.setFrame(frame, display: false)
        glass.frame = NSRect(x: 0, y: 0, width: width, height: stripHeight)
        strip.frame = glass.bounds
        strip.items = items
        panel.orderFrontRegardless()
    }

    /// Centered on the tile, kept inside the window, caret tip just above the strip.
    private func showTooltip(for item: DockItem, centerX: CGFloat) {
        tooltip.text = item.name

        let x = min(max(0, centerX - tooltip.frame.width / 2), panel.frame.width - tooltip.frame.width)
        tooltip.frame.origin = NSPoint(x: round(x), y: stripHeight + tooltipGapAboveStrip)
        tooltip.isHidden = false
    }

    private func runSmokeTestIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["MY_DOCK_SMOKE_TEST"] != nil else { return }

        UserDefaults.standard.set(environment["MY_DOCK_SMOKE_HIDE"] == "1", forKey: hideUnpinnedKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let index = environment["MY_DOCK_SMOKE_HOVER"] else { return }
            self.showTooltip(for: self.strip.items[Int(index)!], centerX: self.strip.getCellFrames()[Int(index)!].midX)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            print("smoke: frame=\(self.panel.frame) items=\(self.strip.items.count) dockItems=\(self.dock.items.count) dockListFrame=\(self.dock.frame)")
            print("smoke: items=\(self.strip.items.map { $0.kind == .separator ? "|" : $0.name })")
            print("smoke: tooltip=\(self.tooltip.frame) hidden=\(self.tooltip.isHidden) text=\(self.tooltip.text) badges=\(self.strip.items.filter { $0.badge != nil }.map { "\($0.name)=\($0.badge!)" })")
            writeCapture(around: self.panel, path: smokeCapturePath)
            exit(0)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let application = NSApplication.shared
let controller = MyDockController()

application.setActivationPolicy(.accessory)
application.delegate = controller
application.run()
