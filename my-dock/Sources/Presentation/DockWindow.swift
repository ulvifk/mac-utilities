import AppKit

protocol DockStripViewDelegate: AnyObject {
    func perform(_ action: DockAction)
    func buildMenu(for item: DockItem) -> NSMenu?
    func canAcceptDrop(_ payload: DockDragPayload) -> Bool
    func acceptDrop(_ payload: DockDragPayload, at target: DockDropTarget) -> Bool
    func interactionDidEnd()
    func showTooltip(for item: DockItem, centerX: CGFloat)
    func hideTooltip()
}

final class DockWindow: DockStripViewDelegate {
    private unowned let handler: DockEventHandler
    private let menus: DockMenus

    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let glass = NSGlassEffectView()
    private let clip = NSView()
    private lazy var strip = DockStripView(delegate: self)
    private let tooltipPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let tooltip = TooltipView()

    var isInteracting: Bool { strip.isInteracting }

    init(handler: DockEventHandler, menus: DockMenus) {
        self.handler = handler
        self.menus = menus
    }

    func show() {
        glass.style = .clear
        glass.cornerRadius = stripCornerRadius
        glass.contentView = strip
        strip.appearance = NSAppearance(named: .aqua)
        clip.wantsLayer = true
        clip.layer!.cornerRadius = stripCornerRadius
        clip.layer!.masksToBounds = true
        clip.addSubview(glass)
        panel.contentView = clip
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.acceptsMouseMovedEvents = true
        panel.setAccessibilityLabel("MyDock")

        tooltipPanel.contentView = tooltip
        tooltipPanel.isOpaque = false
        tooltipPanel.backgroundColor = .clear
        tooltipPanel.hasShadow = false
        tooltipPanel.ignoresMouseEvents = true
        tooltipPanel.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
        tooltipPanel.collectionBehavior = panel.collectionBehavior
    }

    func render(_ items: [DockItem]) {
        if items != strip.items {
            hideTooltip()
            strip.setItems(items)
        }
        guard let screen = NSScreen.screens.first else { return }
        let size = strip.dockLayout.size
        let scale = min(1, (screen.visibleFrame.width - 20) / size.width)
        let frame = NSRect(x: screen.visibleFrame.midX - size.width * scale / 2,
                           y: screen.frame.minY + stripBottomMargin,
                           width: size.width * scale, height: size.height * scale)
        if panel.frame != frame {
            hideTooltip()
            panel.setFrame(frame, display: false)
            glass.frame = clip.bounds
            strip.frame = glass.bounds
            strip.bounds = NSRect(origin: .zero, size: size)
            strip.updateAccessibilityItems()
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
        strip.refreshHover()
    }

    func perform(_ action: DockAction) {
        hideTooltip()
        handler.perform(action)
    }

    func buildMenu(for item: DockItem) -> NSMenu? { menus.buildAppMenu(for: item) }
    func canAcceptDrop(_ payload: DockDragPayload) -> Bool { handler.canAcceptDrop(payload) }
    func acceptDrop(_ payload: DockDragPayload, at target: DockDropTarget) -> Bool { handler.acceptDrop(payload, at: target) }
    func interactionDidEnd() { handler.interactionDidEnd() }

    func showTooltip(for item: DockItem, centerX: CGFloat) {
        let size = TooltipView.getSize(for: item.tooltip)
        let point = panel.convertPoint(toScreen: strip.convert(NSPoint(x: centerX, y: 0), to: nil))
        let screen = panel.screen!.frame
        let x = min(max(point.x - size.width / 2, screen.minX + 4), screen.maxX - size.width - 4)
        tooltip.text = item.tooltip
        tooltipPanel.setFrame(NSRect(x: x, y: panel.frame.maxY + tooltipTipAboveStrip, width: size.width, height: size.height), display: true)
        tooltipPanel.orderFrontRegardless()
    }

    func hideTooltip() { tooltipPanel.orderOut(nil) }
}
