import Combine
import Foundation

/// The bindings in $XDG_CONFIG_HOME/mac-utilities/hotkeys.json (~/.config by default). Every edit is written on the spot; the directory is watched, so hand edits are picked up while the app runs.
final class HotkeyBindingsStore: ObservableObject {
    let path: String

    @Published private(set) var bindings: [HotkeyBinding] = []

    private let directory: String
    private var directoryWatcher: DispatchSourceFileSystemObject!

    init() {
        directory = getConfigDirectory() + "/mac-utilities"
        path = directory + "/hotkeys.json"

        try! FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        load()
        directoryWatcher = buildDirectoryWatcher()
        directoryWatcher.resume()
    }

    func add(_ binding: HotkeyBinding) {
        save(bindings + [binding])
    }

    func replace(at index: Int, with binding: HotkeyBinding) {
        var updated = bindings
        updated[index] = binding
        save(updated)
    }

    func remove(at index: Int) {
        var updated = bindings
        updated.remove(at: index)
        save(updated)
    }

    private func save(_ updated: [HotkeyBinding]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        try! encoder.encode(updated).write(to: URL(fileURLWithPath: path))
        bindings = updated
    }

    /// A file that does not parse, half-typed in an editor for instance, leaves the current bindings in place.
    private func load() {
        guard let data = FileManager.default.contents(atPath: path) else {
            bindings = []
            return
        }

        do {
            let loaded = try JSONDecoder().decode([HotkeyBinding].self, from: data)
            if loaded == bindings { return }
            bindings = loaded
        } catch {
            print("hotkeys: \(path) not loaded, keeping the current bindings: \(error)")
        }
    }

    /// Editors save by writing a new file and renaming it over the old one, which a watcher on the file itself misses; the directory sees every such change.
    private func buildDirectoryWatcher() -> DispatchSourceFileSystemObject {
        let descriptor = open(directory, O_EVTONLY)
        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)

        watcher.setEventHandler { [unowned self] in self.load() }
        return watcher
    }
}

private func getConfigDirectory() -> String {
    return ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ?? NSHomeDirectory() + "/.config"
}
