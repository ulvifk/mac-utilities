import Foundation

enum DockEdit {
    case toggleHiddenGroup
    case setKept(appID: String, isKept: Bool)
    case moveApp(appID: String, target: DockDropTarget)
    case placeApps([SavedApp], target: DockDropTarget)
}

extension DockState {
    func applying(_ edit: DockEdit) -> DockState {
        switch edit {
        case .toggleHiddenGroup:
            var result = self
            result.isCollapsed.toggle()
            return result
        case .setKept(let id, let isKept):
            return settingKept(isKept, appID: id)
        case .moveApp(let id, let target):
            return movingApp(id: id, to: target)
        case .placeApps(let apps, let target):
            return placingApps(apps, at: target)
        }
    }
}
