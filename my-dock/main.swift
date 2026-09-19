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

// ponytail: comparison mode floats our strip above Apple's Dock; set to 0 when it replaces the Dock.
let comparisonOffset: CGFloat = 70
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

struct DockItem {
    let kind: DockItemKind
    let name: String
    let url: URL?
    let isRunning: Bool
    let width: CGFloat
}

/// Apple's Dock item list through Accessibility. The frame is in top-left screen coordinates.
func readDockItems() -> (frame: CGRect, items: [DockItem]) {
    let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first!
    let application = AXUIElementCreateApplication(dock.processIdentifier)
    let children = getAttribute(application, kAXChildrenAttribute) as! [AXUIElement]
    let list = children.first { getAttribute($0, kAXRoleAttribute) as? String == "AXList" }!
    let items = (getAttribute(list, kAXChildrenAttribute) as! [AXUIElement]).map(buildDockItem)

    return (getFrame(list), items)
}

func buildDockItem(_ element: AXUIElement) -> DockItem {
    return DockItem(
        kind: getDockItemKind(subrole: getAttribute(element, kAXSubroleAttribute) as! String),
        name: getAttribute(element, kAXTitleAttribute) as? String ?? "",
        url: getAttribute(element, kAXURLAttribute) as? URL,
        isRunning: getAttribute(element, "AXIsApplicationRunning") as? Bool ?? false,
        width: getFrame(element).width
    )
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
    var items: [DockItem] = []

    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        drawDimming()

        var cellX = stripEndPadding
        for item in items {
            drawItem(item, cellX: cellX)
            cellX += item.width
        }
    }

    /// Regular glass renders lighter than the backdrop and tintColor only brightens it further; the 1pt rim is left undimmed.
    private func drawDimming() {
        let inset = bounds.insetBy(dx: 1, dy: 1)

        stripDimmingColor.setFill()
        NSBezierPath(roundedRect: inset, xRadius: stripCornerRadius - 1, yRadius: stripCornerRadius - 1).fill()
    }

    private func drawItem(_ item: DockItem, cellX: CGFloat) {
        let centerX = cellX + item.width / 2

        if item.kind == .separator {
            drawSeparator(centerX: centerX)
            return
        }

        drawIcon(getIcon(item), centerX: centerX)
        if item.isRunning { drawRunningDot(centerX: centerX) }
    }

    private func drawIcon(_ icon: NSImage, centerX: CGFloat) {
        let rect = NSRect(x: centerX - iconSize / 2, y: iconTopInset, width: iconSize, height: iconSize)
        icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
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

    private func drawSeparator(centerX: CGFloat) {
        let rect = NSRect(x: centerX, y: separatorVerticalInset, width: 1, height: stripHeight - 2 * separatorVerticalInset)

        separatorColor.setFill()
        rect.fill()
    }
}

final class MyDockController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
    private let glass = NSGlassEffectView()
    private let strip = DockStripView()

    private var dock = (frame: CGRect.zero, items: [DockItem]())

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        requestAccessibilityTrust()
        observeApplicationChanges()
        render()
        runSmokeTestIfRequested()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

        statusItem.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "My Dock")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    /// Apple's Dock draws the light trash variant in both appearances, so the content draws as aqua.
    private func buildWindow() {
        glass.style = .regular
        glass.cornerRadius = stripCornerRadius
        glass.contentView = strip
        strip.appearance = NSAppearance(named: .aqua)

        window.contentView = glass
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
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

    private func render() {
        dock = readDockItems()

        let screen = NSScreen.main!.frame
        let width = stripEndPadding * 2 + dock.items.reduce(0) { $0 + $1.width }
        let frame = NSRect(x: screen.midX - width / 2, y: screen.minY + stripBottomMargin + comparisonOffset, width: width, height: stripHeight)

        window.setFrame(frame, display: false)
        strip.items = dock.items
        strip.frame = glass.bounds
        strip.needsDisplay = true
        window.orderFrontRegardless()
    }

    private func runSmokeTestIfRequested() {
        guard ProcessInfo.processInfo.environment["MY_DOCK_SMOKE_TEST"] != nil else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            print("smoke: frame=\(self.window.frame) items=\(self.dock.items.count) dockListFrame=\(self.dock.frame)")
            print("smoke: items=\(self.dock.items.map { $0.name })")
            writeCapture(around: self.window, path: smokeCapturePath)
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
