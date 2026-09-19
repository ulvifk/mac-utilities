import AppKit

enum DockDragPayload {
    case appID(String)
    case applications([SavedApp])

    static let type = NSPasteboard.PasteboardType("com.ulvifk.my-dock.application-id")

    func getEdit(at target: DockDropTarget) -> DockEdit {
        switch self {
        case .appID(let id): return .moveApp(appID: id, target: target)
        case .applications(let apps): return .placeApps(apps, target: target)
        }
    }

    func getOperation(allowed: NSDragOperation) -> NSDragOperation {
        switch self {
        case .appID:
            if allowed.contains(.move) { return .move }
        case .applications:
            if allowed.contains(.copy) { return .copy }
            if allowed.contains(.link) { return .link }
        }
        return []
    }

    static func read(_ pasteboard: NSPasteboard, isLocal: Bool) -> DockDragPayload? {
        if let id = pasteboard.string(forType: type) {
            if !isLocal { return nil }
            return .appID(id)
        }
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return nil }
        if urls.isEmpty { return nil }
        var apps: [SavedApp] = []
        var ids = Set<String>()
        for url in urls {
            guard let app = AppCatalog.resolveApplication(url, isKept: true) else { return nil }
            if !ids.insert(app.id).inserted { continue }
            apps.append(app)
        }
        return .applications(apps)
    }
}
