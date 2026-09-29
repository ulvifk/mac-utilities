import Combine
import Foundation

/// Reads, writes, and watches hotkeys.json in the config directory.
final class HotkeyBindingsStore: ObservableObject {
    let path: String

    @Published private(set) var bindings: [HotkeyBinding] = []
    /// Why the file does not parse right now; the pane shows it and writes nothing while it is set, so hand edits are never overwritten.
    @Published private(set) var loadError: String?

    private let directory: String
    private var directoryWatcher: DispatchSourceFileSystemObject!
    private var fileWatcher: DispatchSourceFileSystemObject?

    init() {
        directory = getConfigDirectory() + "/mac-utilities"
        path = directory + "/hotkeys.json"

        try! FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        directoryWatcher = buildDirectoryWatcher()
        directoryWatcher.resume()
        refreshFileWatcher()

        load()
    }

    deinit {
        directoryWatcher.cancel()
        fileWatcher?.cancel()
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
        loadError = nil
        guard let data = FileManager.default.contents(atPath: path) else {
            bindings = []
            return
        }

        do {
            let loaded = try JSONDecoder().decode([HotkeyBinding].self, from: data)
            if loaded == bindings { return }
            bindings = loaded
        } catch {
            loadError = "\(error)"
            print("hotkeys: \(path) not loaded, keeping the current bindings: \(error)")
        }
    }

    /// The directory catches file creation and replacement; each replacement needs a new file watcher.
    private func buildDirectoryWatcher() -> DispatchSourceFileSystemObject {
        let descriptor = open(directory, O_EVTONLY)
        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)

        watcher.setEventHandler { [weak self] in
            guard let self else { return }
            self.refreshFileWatcher()

            self.load()
        }
        watcher.setCancelHandler { close(descriptor) }
        return watcher
    }

    private func refreshFileWatcher() {
        fileWatcher?.cancel()
        fileWatcher = nil

        let descriptor = open(path, O_EVTONLY)
        if descriptor == -1 { return }

        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        watcher.setEventHandler { [weak self] in self?.load() }
        watcher.setCancelHandler { close(descriptor) }

        fileWatcher = watcher
        watcher.resume()
    }
}

private func getConfigDirectory() -> String {
    return ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ?? NSHomeDirectory() + "/.config"
}
