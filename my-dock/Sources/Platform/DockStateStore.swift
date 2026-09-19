import Foundation

final class DockStateStore {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() throws -> DockState? {
        if !FileManager.default.fileExists(atPath: fileURL.path) { return nil }
        let state = try JSONDecoder().decode(DockState.self, from: Data(contentsOf: fileURL))
        let ids = state.allApps.map(\.id)
        if Set(ids).count != ids.count {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "An app belongs to more than one MyDock position."))
        }
        return state
    }

    func save(_ state: DockState) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}
