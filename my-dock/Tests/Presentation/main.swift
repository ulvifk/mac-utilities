import AppKit

func app(_ id: String, kept: Bool) -> SavedApp {
    return SavedApp(id: id, url: URL(fileURLWithPath: "/Applications/\(id).app"), name: id, isKept: kept)
}

let a = app("a", kept: true)
let b = app("b", kept: true)
let c = app("c", kept: false)
let d = app("d", kept: false)
let expanded = DockState(visibleApps: [a, b], hiddenApps: [c, d], isCollapsed: false)
let items = DockItems.build(state: expanded, runningIDs: ["a", "c"], badges: [c.url.path: "3"])
assert(items.compactMap(\.app).map(\.id) == ["a", "b", "c"])
let toggle = items[2]
guard case .toggle(let slot) = toggle else { fatalError("Missing group toggle") }
assert(slot.hiddenCount == 1)
assert(slot.hasBadge)

let layout = DockLayout.build(items: items)
let aCell = layout.cells[0].frame
let bCell = layout.cells[1].frame
let toggleCell = layout.cells[2].frame
let cCell = layout.cells[3].frame
let beforeB = layout.getDropPreview(at: NSPoint(x: bCell.minX + 1, y: bCell.midY))!
assert(beforeB.target == DockDropTarget(group: .visible, beforeAppID: "b"))
let afterB = layout.getDropPreview(at: NSPoint(x: bCell.maxX - 1, y: bCell.midY))!
assert(afterB.target == DockDropTarget(group: .visible, beforeAppID: nil))
let beforeC = layout.getDropPreview(at: NSPoint(x: cCell.minX + 1, y: cCell.midY))!
assert(beforeC.target == DockDropTarget(group: .hidden, beforeAppID: "c"))
let intoHidden = layout.getDropPreview(at: NSPoint(x: toggleCell.midX, y: toggleCell.midY))!
assert(intoHidden.target == DockDropTarget(group: .hidden, beforeAppID: nil))
assert(intoHidden.marker == .groupHighlight(toggleCell))
assert(layout.getDropPreview(at: NSPoint(x: -1, y: 30)) == nil)
assert(layout.getDropPreview(at: NSPoint(x: aCell.midX, y: -1)) == nil)
for cell in layout.cells.suffix(2) {
    assert(layout.getDropPreview(at: NSPoint(x: cell.frame.midX, y: cell.frame.midY)) == nil)
}

let collapsed = expanded.applying(.toggleHiddenGroup)
let collapsedItems = DockItems.build(state: collapsed, runningIDs: ["a", "c"], badges: [:])
assert(collapsedItems.compactMap(\.app).map(\.id) == ["a", "b"])
assert(collapsed.allApps == expanded.allApps)
let collapsedLayout = DockLayout.build(items: collapsedItems)
let collapsedToggle = collapsedLayout.cells[2].frame
assert(collapsedLayout.getDropPreview(at: NSPoint(x: collapsedToggle.midX, y: 30))!.target.group == .hidden)

let empty = DockState(visibleApps: [], hiddenApps: [], isCollapsed: true)
let emptyLayout = DockLayout.build(items: DockItems.build(state: empty, runningIDs: [], badges: [:]))
assert(emptyLayout.getDropPreview(at: NSPoint(x: 20, y: 30))!.target == DockDropTarget(group: .visible, beforeAppID: nil))
assert(DockLayout.build(items: []).getDropPreview(at: .zero) == nil)

let move = DockDragPayload.appID("a")
assert(move.getOperation(allowed: [.move, .copy]) == .move)
assert(move.getOperation(allowed: [.copy]) == [])
let reference = DockDragPayload.applications([a])
assert(reference.getOperation(allowed: [.move, .copy]) == .copy)
assert(reference.getOperation(allowed: [.link]) == .link)
assert(reference.getOperation(allowed: [.move, .delete]) == [])
print("Passed: display filtering, hidden badges, insertion boundaries, collapsed and empty drops, rejected targets, operation negotiation.")
