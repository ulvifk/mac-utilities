import AppKit

final class DockStripView: NSView, NSDraggingSource {
    private unowned let delegate: DockStripViewDelegate
    private let icons = DockIconCache()
    private lazy var renderer = DockRenderer(icons: icons)
    private(set) var items: [DockItem] = []
    private(set) var dockLayout = DockLayout.build(items: [])

    private var hoveredIndex: Int?
    private var pressedIndex: Int?
    private var pressEvent: NSEvent?
    private var isShowingMenu = false
    private var draggedAppID: String?
    private var incomingPayload: DockDragPayload?
    private var dropPreview: DockDropPreview?

    var isInteracting: Bool {
        if pressedIndex != nil { return true }
        if isShowingMenu { return true }
        return isDragging
    }

    private var isDragging: Bool {
        if draggedAppID != nil { return true }
        return incomingPayload != nil
    }

    override var isFlipped: Bool { true }

    init(delegate: DockStripViewDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        registerForDraggedTypes([DockDragPayload.type, .fileURL])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("MyDock")
    }

    required init?(coder: NSCoder) { fatalError("Use init(delegate:)") }

    func setItems(_ items: [DockItem]) {
        self.items = items
        dockLayout = DockLayout.build(items: items)
        hoveredIndex = nil
        needsDisplay = true
        updateAccessibilityItems()
    }

    func updateAccessibilityItems() {
        let children = dockLayout.cells.compactMap { cell -> DockAccessibilityElement? in
            if cell.item == .separator { return nil }
            return DockAccessibilityElement(view: self, item: cell.item, frame: cell.frame)
        }
        setAccessibilityChildren(children)
    }

    func refreshHover() {
        if isInteracting { return }
        let point = convert(window!.mouseLocationOutsideOfEventStream, from: nil)
        updateHover(dockLayout.getItemIndex(at: point))
    }

    func activateItem(_ item: DockItem) {
        if isDragging { return }
        guard let action = item.primaryAction else { return }
        delegate.perform(action)
    }

    func showMenu(for item: DockItem) {
        if isDragging { return }
        guard let menu = delegate.buildMenu(for: item) else { return }
        guard let cell = dockLayout.cells.first(where: { $0.item.accessibilityID == item.accessibilityID }) else { return }
        updateHover(nil)
        isShowingMenu = true
        menu.popUp(positioning: nil, at: NSPoint(x: cell.frame.minX, y: 0), in: self)
        isShowingMenu = false
        delegate.interactionDidEnd()
    }

    override func draw(_ dirtyRect: NSRect) {
        renderer.draw(layout: dockLayout, hoveredIndex: hoveredIndex, draggedAppID: draggedAppID, preview: dropPreview)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        pressedIndex = nil
        pressEvent = nil
        guard let index = dockLayout.getItemIndex(at: convert(event.locationInWindow, from: nil)) else { return }
        if event.modifierFlags.contains(.control) {
            showMenu(for: items[index])
            return
        }
        pressedIndex = index
        pressEvent = event
    }

    override func mouseUp(with event: NSEvent) {
        guard let index = pressedIndex else { return }
        pressedIndex = nil
        pressEvent = nil
        if dockLayout.getItemIndex(at: convert(event.locationInWindow, from: nil)) == index {
            activateItem(items[index])
        }
        delegate.interactionDidEnd()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let index = pressedIndex else { return }
        guard let pressEvent else { return }
        guard let app = items[index].app else { return }
        let start = convert(pressEvent.locationInWindow, from: nil)
        let point = convert(event.locationInWindow, from: nil)
        if hypot(point.x - start.x, point.y - start.y) < 4 { return }
        let cell = dockLayout.cells[index].frame
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(app.id, forType: DockDragPayload.type)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(NSRect(x: cell.midX - iconSize / 2, y: iconTopInset, width: iconSize, height: iconSize), contents: icons.getIcon(app))

        pressedIndex = nil
        self.pressEvent = nil
        draggedAppID = app.id
        updateHover(nil)
        needsDisplay = true
        let session = beginDraggingSession(with: [draggingItem], event: pressEvent, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        if context == .withinApplication { return .move }
        return []
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        draggedAppID = nil
        clearDropPreview()
        delegate.interactionDidEnd()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let isLocal = sender.draggingSource as? DockStripView === self
        incomingPayload = DockDragPayload.read(sender.draggingPasteboard, isLocal: isLocal)
        updateHover(nil)
        return updateDropPreview(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { updateDropPreview(sender) }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearDropPreview()
        delegate.interactionDidEnd()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { updateDropPreview(sender) != [] }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let incomingPayload else { return false }
        guard let dropPreview else { return false }
        return delegate.acceptDrop(incomingPayload, at: dropPreview.target)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        clearDropPreview()
        delegate.interactionDidEnd()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        clearDropPreview()
        delegate.interactionDidEnd()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let index = dockLayout.getItemIndex(at: convert(event.locationInWindow, from: nil)) else { return }
        showMenu(for: items[index])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }

    override func mouseMoved(with event: NSEvent) {
        if isDragging { return }
        updateHover(dockLayout.getItemIndex(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) { updateHover(nil) }

    private func updateHover(_ index: Int?) {
        if index == hoveredIndex { return }
        hoveredIndex = index
        needsDisplay = true
        NSCursor.arrow.set()
        guard let index else {
            delegate.hideTooltip()
            return
        }
        let item = items[index]
        if item == .separator {
            delegate.hideTooltip()
            return
        }
        if case .toggle = item { NSCursor.pointingHand.set() }
        delegate.showTooltip(for: item, centerX: dockLayout.cells[index].frame.midX)
    }

    private func updateDropPreview(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropPreview = nil
        needsDisplay = true
        guard let incomingPayload else { return [] }
        if !delegate.canAcceptDrop(incomingPayload) { return [] }
        let operation = incomingPayload.getOperation(allowed: sender.draggingSourceOperationMask)
        if operation == [] { return [] }
        let point = convert(sender.draggingLocation, from: nil)
        dropPreview = dockLayout.getDropPreview(at: point)
        if dropPreview == nil { return [] }
        return operation
    }

    private func clearDropPreview() {
        incomingPayload = nil
        dropPreview = nil
        needsDisplay = true
    }
}
