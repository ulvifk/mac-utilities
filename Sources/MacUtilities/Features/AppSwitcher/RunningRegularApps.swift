import AppKit
import Combine

/// The running regular apps with a bundle identifier, by name, kept current as apps launch and quit.
final class RunningRegularApps: ObservableObject {
    @Published private(set) var apps: [NSRunningApplication] = []

    init() {
        NSWorkspace.shared.publisher(for: \.runningApplications)
            .map { _ in getRegularRunningApps().filter { $0.bundleIdentifier != nil }.sorted { getAppName($0) < getAppName($1) } }
            .assign(to: &$apps)
    }
}
