import AppKit

let pasteboard = NSPasteboard.withUniqueName()
defer { pasteboard.releaseGlobally() }
let finder = URL(fileURLWithPath: finderPath)
pasteboard.writeObjects([finder as NSURL])
guard case .applications(let apps) = DockDragPayload.read(pasteboard, isLocal: false) else { fatalError("Application drop was rejected") }
assert(apps.count == 1)
assert(apps[0].id == "com.apple.finder")
assert(apps[0].isKept)

pasteboard.clearContents()
pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/document.txt") as NSURL])
assert(DockDragPayload.read(pasteboard, isLocal: false) == nil)
pasteboard.clearContents()
pasteboard.writeObjects([finder as NSURL, URL(fileURLWithPath: "/tmp/document.txt") as NSURL])
assert(DockDragPayload.read(pasteboard, isLocal: false) == nil)

pasteboard.clearContents()
pasteboard.setString("com.apple.finder", forType: DockDragPayload.type)
assert(DockDragPayload.read(pasteboard, isLocal: false) == nil)
guard case .appID(let id) = DockDragPayload.read(pasteboard, isLocal: true) else { fatalError("Local drop was rejected") }
assert(id == "com.apple.finder")
assert(AppCatalog.resolveApplication(URL(string: "https://example.com/Finder.app")!, isKept: true) == nil)
print("Passed: external app drops, document rejection, mixed-drop rejection, private drag payloads.")
