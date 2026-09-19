import Foundation

enum DockAction {
    case edit(DockEdit)
    case openApp(SavedApp)
    case revealApp(SavedApp)
    case quitApp(SavedApp)
    case openTrash
    case showSavedList
    case quitDock
}

protocol DockEventHandler: AnyObject {
    func perform(_ action: DockAction)
    func canAcceptDrop(_ payload: DockDragPayload) -> Bool
    func acceptDrop(_ payload: DockDragPayload, at target: DockDropTarget) -> Bool
    func interactionDidEnd()
}
