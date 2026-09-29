import Darwin
import Foundation
import Testing
@testable import MacUtilities

@Suite(.serialized)
final class HotkeyBindingsStoreTests {
    private let configDirectory: URL
    private let originalConfigDirectory: String?

    init() throws {
        configDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        originalConfigDirectory = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
        setenv("XDG_CONFIG_HOME", configDirectory.path, 1)

        try FileManager.default.createDirectory(at: hotkeysURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    deinit {
        if let originalConfigDirectory {
            setenv("XDG_CONFIG_HOME", originalConfigDirectory, 1)
        } else {
            unsetenv("XDG_CONFIG_HOME")
        }

        try! FileManager.default.removeItem(at: configDirectory)
    }

    @Test @MainActor
    func testInPlaceEditsAreReloaded() async throws {
        let original = [buildBinding(target: "original")]
        try writeBindings(original)
        let store = HotkeyBindingsStore()
        #expect(store.bindings == original)

        let edited = [buildBinding(target: "edited")]
        try writeInPlace(JSONEncoder().encode(edited))
        try await waitUntil { store.bindings == edited }
        #expect(store.loadError == nil)
    }

    @Test @MainActor
    func testAtomicReplacementReattachesTheFileWatcher() async throws {
        try writeBindings([buildBinding(target: "original")])
        let store = HotkeyBindingsStore()

        let replaced = [buildBinding(target: "replaced")]
        try writeBindings(replaced, options: .atomic)
        try await waitUntil { store.bindings == replaced }

        let edited = [buildBinding(target: "edited after replacement")]
        try writeInPlace(JSONEncoder().encode(edited))
        try await waitUntil { store.bindings == edited }
    }

    @Test @MainActor
    func testInitiallyAbsentFileIsLoadedAndWatchedWhenCreated() async throws {
        let store = HotkeyBindingsStore()
        #expect(store.bindings.isEmpty)
        #expect(store.loadError == nil)

        let created = [buildBinding(target: "created")]
        try writeBindings(created)
        try await waitUntil { store.bindings == created }

        let edited = [buildBinding(target: "edited after creation")]
        try writeInPlace(JSONEncoder().encode(edited))
        try await waitUntil { store.bindings == edited }
    }

    @Test @MainActor
    func testInvalidInPlaceEditKeepsBindingsUntilValidEdit() async throws {
        let original = [buildBinding(target: "original")]
        try writeBindings(original)
        let store = HotkeyBindingsStore()

        try writeInPlace(Data("[".utf8))
        try await waitUntil { store.loadError != nil }
        #expect(store.bindings == original)

        let edited = [buildBinding(target: "recovered")]
        try writeInPlace(JSONEncoder().encode(edited))
        try await waitUntil { store.bindings == edited }
        #expect(store.loadError == nil)
    }

    @Test @MainActor
    func testInitiallyInvalidFileRecoversAfterInPlaceEdit() async throws {
        try Data("[".utf8).write(to: hotkeysURL)
        let store = HotkeyBindingsStore()
        #expect(store.loadError != nil)

        let edited = [buildBinding(target: "recovered")]
        try writeInPlace(JSONEncoder().encode(edited))
        try await waitUntil { store.bindings == edited }
        #expect(store.loadError == nil)
    }

    @Test @MainActor
    func testSettingsEditPreservesReloadedExternalBindings() async throws {
        let original = buildBinding(target: "original")
        try writeBindings([original])
        let store = HotkeyBindingsStore()

        let external = buildBinding(target: "external")
        try writeInPlace(JSONEncoder().encode([original, external]))
        try await waitUntil { store.bindings == [original, external] }

        let added = buildBinding(target: "added in settings")
        store.add(added)
        let saved = try JSONDecoder().decode([HotkeyBinding].self, from: Data(contentsOf: hotkeysURL))
        #expect(saved == [original, external, added])
    }

    @Test @MainActor
    func testDeletedFileCanBeRecreatedAndEdited() async throws {
        try writeBindings([buildBinding(target: "original")])
        let store = HotkeyBindingsStore()

        try FileManager.default.removeItem(at: hotkeysURL)
        try await waitUntil { store.bindings.isEmpty }
        #expect(store.loadError == nil)

        let recreated = [buildBinding(target: "recreated")]
        try writeBindings(recreated)
        try await waitUntil { store.bindings == recreated }

        let edited = [buildBinding(target: "edited after recreation")]
        try writeInPlace(JSONEncoder().encode(edited))
        try await waitUntil { store.bindings == edited }
    }

    @Test @MainActor
    func testReleasingStoreClosesWatcherDescriptors() async throws {
        try writeBindings([buildBinding(target: "original")])
        var store: HotkeyBindingsStore? = HotkeyBindingsStore()
        weak let releasedStore = store
        let directory = hotkeysURL.deletingLastPathComponent()
        #expect(try getOpenDescriptors(for: directory).count == 1)
        #expect(try getOpenDescriptors(for: hotkeysURL).count == 1)

        store = nil
        #expect(releasedStore == nil)
        try await waitUntil { try hasNoWatcherDescriptors() }
    }

    private var hotkeysURL: URL {
        return configDirectory.appendingPathComponent("mac-utilities/hotkeys.json")
    }

    private func buildBinding(target: String) -> HotkeyBinding {
        return HotkeyBinding(key: nil, action: HotkeyAction(type: .runCommand, target: target))
    }

    private func writeBindings(_ bindings: [HotkeyBinding], options: Data.WritingOptions = []) throws {
        try JSONEncoder().encode(bindings).write(to: hotkeysURL, options: options)
    }

    private func writeInPlace(_ data: Data) throws {
        let file = try FileHandle(forWritingTo: hotkeysURL)
        defer { try! file.close() }

        try file.truncate(atOffset: 0)
        try file.write(contentsOf: data)
    }

    private func getOpenDescriptors(for url: URL) throws -> Set<Int32> {
        var fileInfo = stat()
        #expect(stat(url.path, &fileInfo) == 0)

        var descriptors = Set<Int32>()
        for name in try FileManager.default.contentsOfDirectory(atPath: "/dev/fd") {
            guard let descriptor = Int32(name) else { continue }
            var descriptorInfo = stat()
            if fstat(descriptor, &descriptorInfo) != 0 { continue }
            if descriptorInfo.st_dev != fileInfo.st_dev { continue }
            if descriptorInfo.st_ino != fileInfo.st_ino { continue }
            descriptors.insert(descriptor)
        }
        return descriptors
    }

    private func hasNoWatcherDescriptors() throws -> Bool {
        if try !getOpenDescriptors(for: hotkeysURL.deletingLastPathComponent()).isEmpty { return false }
        if try !getOpenDescriptors(for: hotkeysURL).isEmpty { return false }
        return true
    }

    @MainActor
    private func waitUntil(_ condition: () throws -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while try !condition() {
            if ContinuousClock.now >= deadline {
                Issue.record("Timed out waiting for the hotkey file change", sourceLocation: sourceLocation)
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
