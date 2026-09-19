import Foundation

func app(_ id: String, kept: Bool = true) -> SavedApp {
    return SavedApp(id: id, url: URL(fileURLWithPath: "/Applications/\(id).app"), name: id, isKept: kept)
}

let initial = DockState(visibleApps: [app("a"), app("b"), app("c")], hiddenApps: [app("d", kept: false)], isCollapsed: true)
let hidden = initial.movingApp(id: "b", to: DockDropTarget(group: .hidden, beforeAppID: "d"))
assert(hidden.visibleApps.map(\.id) == ["a", "c"])
assert(hidden.hiddenApps.map(\.id) == ["b", "d"])
assert(hidden.isCollapsed)
assert(initial.visibleApps.map(\.id) == ["a", "b", "c"])

let reordered = initial.movingApp(id: "c", to: DockDropTarget(group: .visible, beforeAppID: "a"))
assert(reordered.visibleApps.map(\.id) == ["c", "a", "b"])
let atEnd = reordered.movingApp(id: "c", to: DockDropTarget(group: .visible, beforeAppID: nil))
assert(atEnd.visibleApps.map(\.id) == ["a", "b", "c"])
assert(initial.movingApp(id: "b", to: DockDropTarget(group: .visible, beforeAppID: "b")) == initial)
assert(initial.placingApps([app("b")], at: DockDropTarget(group: .visible, beforeAppID: "b")) == initial)
let batch = initial.placingApps([app("b"), app("c"), app("e")], at: DockDropTarget(group: .visible, beforeAppID: "b"))
assert(batch.visibleApps.map(\.id) == ["a", "b", "c", "e"])
let crossGroup = hidden.movingApp(id: "b", to: DockDropTarget(group: .visible, beforeAppID: "c"))
assert(crossGroup == initial)

let discovered = initial.addingRunningApps([app("d", kept: false), app("e", kept: false), app("e", kept: false)])
assert(discovered.hiddenApps.map(\.id) == ["d", "e"])
assert(initial.addingRunningApps([]) == initial)
assert(!initial.hiddenApps[0].isDisplayed(runningIDs: []))
assert(initial.hiddenApps[0].isDisplayed(runningIDs: ["d"]))
assert(initial.visibleApps[0].isDisplayed(runningIDs: []))
let kept = initial.settingKept(true, appID: "d")
assert(kept.hiddenApps[0].isDisplayed(runningIDs: []))

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try! FileManager.default.removeItem(at: directory) }
let store = DockStateStore(fileURL: directory.appendingPathComponent("apps.json"))
let missing = try store.load()
assert(missing == nil)
try store.save(hidden)
let loadedHidden = try store.load()
assert(loadedHidden == hidden)
try store.save(reordered)
let loadedReordered = try store.load()
assert(loadedReordered == reordered)
let empty = DockState(visibleApps: [], hiddenApps: [], isCollapsed: false)
let inserted = empty.placingApps([app("a")], at: DockDropTarget(group: .visible, beforeAppID: nil))
assert(inserted.visibleApps.map(\.id) == ["a"])
print("Passed: group moves, reorder, self-drop, batch drop, running-app discovery, pinning, empty groups, persistence.")

let sessionStore = DockStateStore(fileURL: directory.appendingPathComponent("session.json"))
try sessionStore.save(initial)
let session = DockSession(store: sessionStore, state: initial)
try session.apply(.moveApp(appID: "b", target: DockDropTarget(group: .hidden, beforeAppID: "d")))
assert(session.state == hidden)
let savedSession = try sessionStore.load()
assert(savedSession == hidden)
try session.registerRunningApps([app("d", kept: false), app("e", kept: false)])
assert(session.state.hiddenApps.map(\.id) == ["b", "d", "e"])
try session.apply(.toggleHiddenGroup)
assert(!session.state.isCollapsed)

let blockedParent = directory.appendingPathComponent("blocked-parent")
try Data("not a directory".utf8).write(to: blockedParent)
let blockedStore = DockStateStore(fileURL: blockedParent.appendingPathComponent("apps.json"))
let blockedSession = DockSession(store: blockedStore, state: initial)
var writeFailed = false
do {
    try blockedSession.apply(.toggleHiddenGroup)
} catch {
    writeFailed = true
}
assert(writeFailed)
assert(blockedSession.state == initial)
print("Passed: shared state edits, saved group order, deferred running discovery, failed saves leave state unchanged.")
