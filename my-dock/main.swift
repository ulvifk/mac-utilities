import AppKit
import ApplicationServices
import UniformTypeIdentifiers

let stripHeight: CGFloat = 60
let stripEndPadding: CGFloat = 3.2
let stripCornerRadius: CGFloat = 22
let stripDimmingColor = NSColor.black.withAlphaComponent(0.3)
/// Apple's rims sit ~50 above the backdrop with a short falloff; the glass alone gives ~30, and its own top rim lands one row
/// outside the frame, so the top needs more. [row from the edge] -> white alpha
let topRimAlphas: [CGFloat] = [0.20, 0.04, 0.02]
let bottomRimAlphas: [CGFloat] = [0.28, 0.06, 0.03]
let stripBottomMargin: CGFloat = 5

let iconSize: CGFloat = 46
let iconTopInset: CGFloat = 7
/// Apple's Dock renders app icons from artwork of about this pixel size; NSImage alone picks the softer, simplified 48px variant.
let iconSourceMinimumPixels = 64
let runningDotDiameter: CGFloat = 4
let runningDotCenterFromBottom: CGFloat = 6
let runningDotColor = NSColor.white.withAlphaComponent(0.58)
let separatorVerticalInset: CGFloat = 8
let separatorColor = NSColor.white.withAlphaComponent(0.3)
let badgeHeight: CGFloat = 17
let badgeHorizontalPadding: CGFloat = 2.5
let badgeInsetFromIconRight: CGFloat = 1
let badgeColor = NSColor.systemRed
let badgeTextAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.white]

/// Our own cell at the pinned/running boundary: a divider with the chevron in a gap, widened by the hidden count when collapsed.
let toggleSlotWidth: CGFloat = 22
let toggleGapHalfHeight: CGFloat = 9
let toggleCountGap: CGFloat = 3
let toggleCountAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.5)]
let chevronWidth: CGFloat = 7
let chevronHeight: CGFloat = 12
let chevronLineWidth: CGFloat = 1.5
let chevronColor = NSColor.white.withAlphaComponent(0.5)
let toggleBadgeDotDiameter: CGFloat = 5
let toggleHoverColor = NSColor.white.withAlphaComponent(0.10)
let toggleHoverCornerRadius: CGFloat = 8
let toggleHoverVerticalInset: CGFloat = 8
let recenterAnimationDuration: TimeInterval = 0.25

/// Name pill in its own panel above the hovered cell, so it may overhang the strip's ends. Fill and rims match Apple's tooltip over a dark backdrop.
let tooltipPillHeight: CGFloat = 26
let tooltipHorizontalPadding: CGFloat = 14.5
let tooltipCaretHalfBase: CGFloat = 6
let tooltipCaretHeight: CGFloat = 6
let tooltipCaretFillet: CGFloat = 7
let tooltipTipAboveStrip: CGFloat = 6
let tooltipFillColor = NSColor(srgbRed: 74 / 255, green: 77 / 255, blue: 85 / 255, alpha: 0.88)
let tooltipTopRimColor = NSColor.white.withAlphaComponent(0.2)
let tooltipBottomRimColor = NSColor.white.withAlphaComponent(0.15)
let tooltipTextAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white]

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
    case toggle
}

/// State of our toggle slot: which way the chevron points, how many running apps sit behind it and whether one has a badge.
struct ToggleSlot {
    let isCollapsed: Bool
    let runningCount: Int
    let hasBadge: Bool
}

struct DockItem {
    let kind: DockItemKind
    let name: String
    let url: URL?
    let isRunning: Bool
    let badge: String?
    let width: CGFloat

    var toggle: ToggleSlot? = nil
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

/// Pinned apps, our toggle slot, the running apps unless collapsed, then everything from the Dock's own separator on (the Trash).
/// Collapsed, the Dock's separator is dropped: two dividers around the count read as clutter, and the toggle slot already divides.
func buildStripItems(_ dockItems: [DockItem], pinned: Set<String>, collapsed: Bool) -> [DockItem] {
    let trashGroupStart = dockItems.lastIndex { $0.kind == .separator }!
    let apps = dockItems[..<trashGroupStart].filter { $0.kind == .app }
    let pinnedApps = apps.filter { isPinned($0, pinned: pinned) }
    let runningApps = apps.filter { !isPinned($0, pinned: pinned) }
    let toggle = buildToggleItem(runningApps, collapsed: collapsed)

    if collapsed { return pinnedApps + [toggle] + dockItems[trashGroupStart...].filter { $0.kind != .separator } }
    return pinnedApps + [toggle] + runningApps + Array(dockItems[trashGroupStart...])
}

/// The badge dot only matters while the badged app is out of sight.
func buildToggleItem(_ runningApps: [DockItem], collapsed: Bool) -> DockItem {
    let slot = ToggleSlot(isCollapsed: collapsed, runningCount: runningApps.count, hasBadge: collapsed && runningApps.contains { $0.badge != nil })
    let name = "\(collapsed ? "Show" : "Hide") \(runningApps.count) running apps"

    return DockItem(kind: .toggle, name: name, url: nil, isRunning: false, badge: nil, width: getToggleWidth(slot), toggle: slot)
}

/// Widened by the count drawn right of the chevron while collapsed.
func getToggleWidth(_ slot: ToggleSlot) -> CGFloat {
    if !slot.isCollapsed { return toggleSlotWidth }
    return toggleSlotWidth + toggleCountGap + ceil(getToggleCountSize(slot).width)
}

func getToggleCountSize(_ slot: ToggleSlot) -> NSSize {
    return ("\(slot.runningCount)" as NSString).size(withAttributes: toggleCountAttributes)
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

func interpolateRect(_ from: NSRect, _ to: NSRect, _ progress: Double) -> NSRect {
    let t = CGFloat(progress)
    return NSRect(
        x: from.minX + (to.minX - from.minX) * t,
        y: from.minY + (to.minY - from.minY) * t,
        width: from.width + (to.width - from.width) * t,
        height: from.height + (to.height - from.height) * t
    )
}

/// Icons are drawn on every hover change, so they are built once per app. [icon key] -> the image drawn in the tile
var iconsByKey: [String: NSImage] = [:]

func getIcon(_ item: DockItem) -> NSImage {
    let key = getIconKey(item)
    if let icon = iconsByKey[key] { return icon }

    let icon = loadIcon(item)
    iconsByKey[key] = icon
    return icon
}

func getIconKey(_ item: DockItem) -> String {
    if item.kind == .trash { return isTrashFull() ? "trash-full" : "trash-empty" }
    return item.url?.path ?? "generic-app"
}

/// The trash keeps the system image, whose light variant is chosen by the drawing appearance; app icons take the sharper large artwork.
func loadIcon(_ item: DockItem) -> NSImage {
    if item.kind == .trash { return NSImage(named: isTrashFull() ? NSImage.trashFullName : NSImage.trashEmptyName)! }
    guard let url = item.url else { return buildTileIcon(NSWorkspace.shared.icon(for: .applicationBundle)) }

    return buildTileIcon(NSWorkspace.shared.icon(forFile: url.path))
}

func buildTileIcon(_ icon: NSImage) -> NSImage {
    let largeEnough = icon.representations.filter { $0.pixelsWide >= iconSourceMinimumPixels }
    let tile = NSImage(size: NSSize(width: iconSize, height: iconSize))

    tile.addRepresentation(largeEnough.min { $0.pixelsWide < $1.pixelsWide }!)
    return tile
}

/// ~/.Trash cannot be listed without Full Disk Access, but APFS reports a directory's link count as entries + 2.
func isTrashFull() -> Bool {
    let attributes = try! FileManager.default.attributesOfItem(atPath: NSHomeDirectory() + "/.Trash")
    return attributes[.referenceCount] as! Int > 2
}

/// Draws the tiles left to right in top-left coordinates, so every inset reads as a distance from the strip's top.
final class DockStripView: NSView {
    var onToggleClicked: () -> Void = {}
    var onTileClicked: (DockItem) -> Void = { _ in }
    var onHovered: (DockItem, CGFloat) -> Void = { _, _ in }
    var onHoverEnded: () -> Void = {}

    /// Re-evaluates the hover in place, so a refresh under a resting cursor neither flickers nor keeps a stale item.
    var items: [DockItem] = [] {
        didSet {
            needsDisplay = true
            updateHover(getHoverableIndex(at: convert(window!.mouseLocationOutsideOfEventStream, from: nil)))
        }
    }

    private var hoveredIndex: Int?

    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current!.imageInterpolation = .high
        drawDimming()
        drawRims()

        for (index, (item, cell)) in zip(items, getCellFrames()).enumerated() {
            drawItem(item, cell: cell, hovered: index == hoveredIndex)
        }
    }

    /// Regular glass renders lighter than the backdrop and tintColor only brightens it further; the 1pt rim is left undimmed.
    private func drawDimming() {
        let inset = bounds.insetBy(dx: 1, dy: 1)

        stripDimmingColor.setFill()
        NSBezierPath(roundedRect: inset, xRadius: stripCornerRadius - 1, yRadius: stripCornerRadius - 1).fill()
    }

    /// Top and bottom edges only, along the straight run between the corner arcs.
    private func drawRims() {
        let straight = NSRect(x: stripCornerRadius, y: 0, width: bounds.width - 2 * stripCornerRadius, height: 1)

        for (row, alpha) in topRimAlphas.enumerated() {
            NSColor.white.withAlphaComponent(alpha).setFill()
            straight.offsetBy(dx: 0, dy: CGFloat(row)).fill()
        }

        for (row, alpha) in bottomRimAlphas.enumerated() {
            NSColor.white.withAlphaComponent(alpha).setFill()
            straight.offsetBy(dx: 0, dy: stripHeight - 1 - CGFloat(row)).fill()
        }
    }

    private func drawItem(_ item: DockItem, cell: NSRect, hovered: Bool) {
        if let toggle = item.toggle {
            drawToggle(toggle, cell: cell, hovered: hovered)
            return
        }

        if item.kind == .separator {
            drawDividerLine(x: round(cell.midX), from: separatorVerticalInset, to: stripHeight - separatorVerticalInset)
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

    /// Snapped to a whole column, so a fractional center does not smear the line over two columns.
    private func drawDividerLine(x: CGFloat, from top: CGFloat, to bottom: CGFloat) {
        separatorColor.setFill()
        NSRect(x: x, y: top, width: 1, height: bottom - top).fill()
    }

    /// Divider with the chevron in its gap; collapsed it also shows the hidden count and a dot when a hidden app has a badge.
    private func drawToggle(_ slot: ToggleSlot, cell: NSRect, hovered: Bool) {
        let lineX = round(cell.minX + toggleSlotWidth / 2)
        let centerY = iconTopInset + iconSize / 2

        if hovered { drawToggleHover(cell) }
        drawDividerLine(x: lineX, from: separatorVerticalInset, to: centerY - toggleGapHalfHeight)
        drawDividerLine(x: lineX, from: centerY + toggleGapHalfHeight, to: stripHeight - separatorVerticalInset)
        drawChevron(pointingRight: slot.isCollapsed, center: NSPoint(x: lineX + 0.5, y: centerY))
        if slot.isCollapsed { drawToggleCount(slot, x: lineX + 0.5 + chevronWidth / 2 + toggleCountGap, centerY: centerY) }
        if slot.hasBadge { drawToggleBadgeDot(cell) }
    }

    private func drawToggleHover(_ cell: NSRect) {
        let rect = cell.insetBy(dx: 1, dy: toggleHoverVerticalInset)

        toggleHoverColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: toggleHoverCornerRadius, yRadius: toggleHoverCornerRadius).fill()
    }

    private func drawChevron(pointingRight: Bool, center: NSPoint) {
        let direction: CGFloat = pointingRight ? 1 : -1
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

    private func drawToggleCount(_ slot: ToggleSlot, x: CGFloat, centerY: CGFloat) {
        let size = getToggleCountSize(slot)
        ("\(slot.runningCount)" as NSString).draw(at: NSPoint(x: x, y: centerY - size.height / 2), withAttributes: toggleCountAttributes)
    }

    private func drawToggleBadgeDot(_ cell: NSRect) {
        let rect = NSRect(x: cell.maxX - 3 - toggleBadgeDotDiameter, y: separatorVerticalInset, width: toggleBadgeDotDiameter, height: toggleBadgeDotDiameter)

        badgeColor.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    // MARK: mouse

    /// The panel never becomes key, so the first click must reach the view directly.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        guard let item = getItem(at: convert(event.locationInWindow, from: nil)) else { return }

        if item.kind == .toggle {
            onToggleClicked()
            return
        }

        if item.kind == .separator { return }
        onTileClicked(item)
    }

    /// Cursor rects and cursorUpdate only work in the key window, so the cursor is set by hand from mouse moves.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
    }

    /// A pointer that lands on the strip and rests only produces the enter event, so it counts as a move.
    override func mouseEntered(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(getHoverableIndex(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        updateHover(nil)
    }

    /// Reports only changes, with the cell's center x, so the tooltip is not rebuilt on every mouse move.
    private func updateHover(_ index: Int?) {
        if index == hoveredIndex { return }
        hoveredIndex = index
        needsDisplay = true

        guard let index else {
            NSCursor.arrow.set()
            onHoverEnded()
            return
        }

        let item = items[index]
        if item.kind == .toggle { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        onHovered(item, getCellFrames()[index].midX)
    }

    private func getItem(at point: NSPoint) -> DockItem? {
        return zip(items, getCellFrames()).first { $0.1.contains(point) }?.0
    }

    /// Tiles and the toggle slot react to the mouse; the plain divider and empty space do not.
    private func getHoverableIndex(at point: NSPoint) -> Int? {
        guard let index = getCellFrames().firstIndex(where: { $0.contains(point) }) else { return nil }
        if items[index].kind == .separator { return nil }
        return index
    }

    /// One full-height cell per item, left to right from the end padding; drawing and hit testing share them.
    /// Centered in the bounds, so the tiles stay put while the window animates its width around them.
    func getCellFrames() -> [NSRect] {
        let contentWidth = 2 * stripEndPadding + items.reduce(0) { $0 + $1.width }
        var frames: [NSRect] = []
        var cellX = stripEndPadding + (bounds.width - contentWidth) / 2

        for item in items {
            frames.append(NSRect(x: cellX, y: 0, width: item.width, height: stripHeight))
            cellX += item.width
        }

        return frames
    }
}

/// Apple's Dock tooltip: a dark capsule with a filleted speech-bubble caret, drawn as one shape, the name centered on its line box.
final class TooltipView: NSView {
    var text = "" {
        didSet { needsDisplay = true }
    }

    static func getSize(for text: String) -> NSSize {
        let textWidth = (text as NSString).size(withAttributes: tooltipTextAttributes).width
        return NSSize(width: ceil(textWidth) + 2 * tooltipHorizontalPadding, height: tooltipPillHeight + tooltipCaretHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let pill = NSRect(x: 0, y: tooltipCaretHeight, width: bounds.width, height: tooltipPillHeight)

        tooltipFillColor.setFill()
        buildShape(pill: pill).fill()
        drawRims(pill: pill)
        drawText(pill: pill)
    }

    /// The capsule plus the caret hanging below its middle; one fill, so the translucent color never doubles up.
    private func buildShape(pill: NSRect) -> NSBezierPath {
        let shape = NSBezierPath(roundedRect: pill, xRadius: tooltipPillHeight / 2, yRadius: tooltipPillHeight / 2)
        let centerX = pill.midX
        let base = pill.minY
        let halfBase = tooltipCaretHalfBase
        let fillet = tooltipCaretFillet

        let caret = NSBezierPath()
        caret.move(to: NSPoint(x: centerX - halfBase - fillet, y: base + 1))
        caret.curve(to: NSPoint(x: centerX - halfBase + 2, y: base - 2), controlPoint1: NSPoint(x: centerX - halfBase - 2, y: base + 1), controlPoint2: NSPoint(x: centerX - halfBase, y: base))
        caret.line(to: NSPoint(x: centerX - 1.2, y: base - tooltipCaretHeight + 1.2))
        caret.curve(to: NSPoint(x: centerX + 1.2, y: base - tooltipCaretHeight + 1.2), controlPoint1: NSPoint(x: centerX - 0.4, y: base - tooltipCaretHeight), controlPoint2: NSPoint(x: centerX + 0.4, y: base - tooltipCaretHeight))
        caret.line(to: NSPoint(x: centerX + halfBase - 2, y: base - 2))
        caret.curve(to: NSPoint(x: centerX + halfBase + fillet, y: base + 1), controlPoint1: NSPoint(x: centerX + halfBase, y: base), controlPoint2: NSPoint(x: centerX + halfBase + 2, y: base + 1))
        caret.close()
        shape.append(caret)

        return shape
    }

    /// Apple's pill has bright top and bottom edges and plain sides; the bottom one stops at the caret's fillets.
    private func drawRims(pill: NSRect) {
        let radius = tooltipPillHeight / 2
        let caretSpan = tooltipCaretHalfBase + tooltipCaretFillet

        tooltipTopRimColor.setFill()
        NSRect(x: radius, y: pill.maxY - 1, width: pill.width - 2 * radius, height: 1).fill()
        tooltipBottomRimColor.setFill()
        NSRect(x: radius, y: pill.minY, width: pill.midX - caretSpan - radius, height: 1).fill()
        NSRect(x: pill.midX + caretSpan, y: pill.minY, width: pill.maxX - radius - pill.midX - caretSpan, height: 1).fill()
    }

    /// Font smoothing thickens white text on a transparent layer; Apple's tooltip text is lighter than that.
    private func drawText(pill: NSRect) {
        let size = (text as NSString).size(withAttributes: tooltipTextAttributes)
        let origin = NSPoint(x: pill.midX - size.width / 2, y: pill.midY - size.height / 2)

        NSGraphicsContext.current!.cgContext.setShouldSmoothFonts(false)
        (text as NSString).draw(at: origin, withAttributes: tooltipTextAttributes)
    }
}

final class MyDockController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hideUnpinnedMenuItem = NSMenuItem(title: "Hide unpinned apps", action: #selector(toggleHideUnpinned), keyEquivalent: "")

    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let glass = NSGlassEffectView()
    private let strip = DockStripView()

    private let tooltipPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let tooltip = TooltipView()

    private var dock = (frame: CGRect.zero, items: [DockItem]())
    private var frameAnimation: Timer?

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
        strip.autoresizingMask = [.width]
        strip.appearance = NSAppearance(named: .aqua)
        strip.onToggleClicked = { [unowned self] in self.toggleHideUnpinned() }
        strip.onTileClicked = { item in open(item) }
        strip.onHovered = { [unowned self] item, centerX in self.showTooltip(for: item, centerX: centerX) }
        strip.onHoverEnded = { [unowned self] in self.tooltipPanel.orderOut(nil) }

        panel.contentView = glass
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        tooltipPanel.contentView = tooltip
        tooltipPanel.isOpaque = false
        tooltipPanel.backgroundColor = .clear
        tooltipPanel.hasShadow = false
        tooltipPanel.ignoresMouseEvents = true
        tooltipPanel.level = panel.level
        tooltipPanel.collectionBehavior = panel.collectionBehavior
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

    /// The strip is drawn for the final layout at once; the window re-centers with an animation around it.
    private func render() {
        guard let dock = readDockItems() else { return }
        self.dock = dock

        let items = buildStripItems(dock.items, pinned: readPinnedPaths(), collapsed: isHideUnpinnedEnabled)
        let screen = NSScreen.main!.frame
        let width = stripEndPadding * 2 + items.reduce(0) { $0 + $1.width }
        let frame = NSRect(x: screen.midX - width / 2, y: screen.minY + stripBottomMargin, width: width, height: stripHeight)

        strip.items = items
        if !panel.isVisible {
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            return
        }

        animateFrame(to: frame)
    }

    /// Timer-driven instead of the window animator, which only starts moving some 200ms after the click.
    private func animateFrame(to target: NSRect) {
        let start = panel.frame
        let startedAt = Date()

        frameAnimation?.invalidate()
        frameAnimation = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [unowned self] timer in
            let progress = min(1, Date().timeIntervalSince(startedAt) / recenterAnimationDuration)
            let eased = progress < 0.5 ? 2 * progress * progress : 1 - pow(-2 * progress + 2, 2) / 2

            panel.setFrame(interpolateRect(start, target, eased), display: true)
            if progress >= 1 { timer.invalidate() }
        }
    }

    /// Centered on the cell in screen coordinates, caret tip a few points above the strip; may overhang the strip's ends.
    private func showTooltip(for item: DockItem, centerX: CGFloat) {
        let size = TooltipView.getSize(for: item.name)
        let origin = NSPoint(x: round(panel.frame.minX + centerX - size.width / 2), y: panel.frame.maxY + tooltipTipAboveStrip)

        tooltip.text = item.name
        tooltipPanel.setFrame(NSRect(origin: origin, size: size), display: true)
        tooltipPanel.orderFrontRegardless()
    }

    private func runSmokeTestIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["MY_DOCK_SMOKE_TEST"] != nil else { return }

        UserDefaults.standard.set(environment["MY_DOCK_SMOKE_HIDE"] == "1", forKey: hideUnpinnedKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let index = environment["MY_DOCK_SMOKE_HOVER"] else { return }
            self.moveMouse(toCellAt: Int(index)!)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            print("smoke: frame=\(self.panel.frame) items=\(self.strip.items.count) dockItems=\(self.dock.items.count) dockListFrame=\(self.dock.frame)")
            print("smoke: items=\(self.strip.items.map { $0.kind == .separator ? "|" : $0.name })")
            print("smoke: tooltip=\(self.tooltipPanel.frame) visible=\(self.tooltipPanel.isVisible) text=\(self.tooltip.text) badges=\(self.strip.items.filter { $0.badge != nil }.map { "\($0.name)=\($0.badge!)" })")
            writeCapture(around: self.panel, path: smokeCapturePath)
            exit(0)
        }
    }

    /// Drives the real hover path (tracking area, highlight, tooltip) by moving the pointer onto the cell.
    private func moveMouse(toCellAt index: Int) {
        let cell = strip.getCellFrames()[index]
        let point = CGPoint(x: panel.frame.minX + cell.midX, y: NSScreen.main!.frame.height - (panel.frame.minY + stripHeight / 2))

        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)!.post(tap: .cghidEventTap)
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
