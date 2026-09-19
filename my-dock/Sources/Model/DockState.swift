import Foundation

enum AppGroup: String, Codable, CaseIterable {
    case visible
    case hidden
}

struct SavedApp: Codable, Equatable {
    let id: String
    let url: URL
    let name: String
    var isKept: Bool

    func isDisplayed(runningIDs: Set<String>) -> Bool {
        if isKept { return true }
        return runningIDs.contains(id)
    }
}

struct DockDropTarget: Equatable {
    let group: AppGroup
    let beforeAppID: String?
}

struct DockState: Codable, Equatable {
    var visibleApps: [SavedApp]
    var hiddenApps: [SavedApp]
    var isCollapsed: Bool

    var allApps: [SavedApp] { visibleApps + hiddenApps }

    func getApps(in group: AppGroup) -> [SavedApp] {
        if group == .visible { return visibleApps }
        return hiddenApps
    }

    func getApp(id: String) -> SavedApp? {
        return allApps.first { $0.id == id }
    }

    func addingRunningApps(_ runningApps: [SavedApp]) -> DockState {
        var result = self
        var knownIDs = Set(allApps.map(\.id))
        for app in runningApps {
            if !knownIDs.insert(app.id).inserted { continue }
            result.hiddenApps.append(app)
        }
        return result
    }

    func movingApp(id: String, to target: DockDropTarget) -> DockState {
        if target.beforeAppID == id { return self }
        return placingApps([getApp(id: id)!], at: target)
    }

    func placingApps(_ apps: [SavedApp], at target: DockDropTarget) -> DockState {
        let movedIDs = Set(apps.map(\.id))
        var visible = visibleApps.filter { !movedIDs.contains($0.id) }
        var hidden = hiddenApps.filter { !movedIDs.contains($0.id) }
        var destination = target.group == .visible ? visible : hidden
        let original = getApps(in: target.group)
        let originalIndex = getInsertionIndex(in: original, beforeAppID: target.beforeAppID)
        let nextApp = original.dropFirst(originalIndex).first { !movedIDs.contains($0.id) }
        let index = getInsertionIndex(in: destination, beforeAppID: nextApp?.id)
        destination.insert(contentsOf: apps, at: index)

        if target.group == .visible { visible = destination } else { hidden = destination }
        return DockState(visibleApps: visible, hiddenApps: hidden, isCollapsed: isCollapsed)
    }

    func settingKept(_ isKept: Bool, appID: String) -> DockState {
        var result = self
        if let index = visibleApps.firstIndex(where: { $0.id == appID }) {
            result.visibleApps[index].isKept = isKept
            return result
        }
        let index = hiddenApps.firstIndex { $0.id == appID }!
        result.hiddenApps[index].isKept = isKept
        return result
    }

    private func getInsertionIndex(in apps: [SavedApp], beforeAppID: String?) -> Int {
        guard let beforeAppID else { return apps.count }
        return apps.firstIndex { $0.id == beforeAppID }!
    }
}
