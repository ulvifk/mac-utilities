import Foundation

final class DockSession {
    private let store: DockStateStore
    private(set) var state: DockState

    var fileURL: URL { store.fileURL }

    init(store: DockStateStore, state: DockState) {
        self.store = store
        self.state = state
    }

    func apply(_ edit: DockEdit) throws {
        try commit(state.applying(edit))
    }

    func registerRunningApps(_ apps: [SavedApp]) throws {
        try commit(state.addingRunningApps(apps))
    }

    private func commit(_ updatedState: DockState) throws {
        if updatedState == state { return }
        try store.save(updatedState)
        state = updatedState
    }
}
