import Foundation
import SwiftUI
@testable import MacUtilities

/// Counts what the controller does to it. Its cleanup takes a main-queue turn and a moment on another queue, as a real one waiting on a
/// command does, and has the tap deliver a key press meanwhile, which must not reach a stopped feature.
final class CleanupRecordingFeature: Feature {
    let identifier: String
    let displayName = "Test feature"
    let summary = "Records what the controller does to it."
    let iconSymbolName = "star"
    let iconGradient = Gradient(colors: [.orange])

    private let eventTap: FakeEventTap

    private(set) var stopCount = 0
    private(set) var eventCount = 0
    private(set) var cleanupCount = 0
    private(set) var didFinishCleanup = false

    init(identifier: String, eventTap: FakeEventTap) {
        self.identifier = identifier
        self.eventTap = eventTap
    }

    func stop() {
        stopCount += 1
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        eventCount += 1
        return false
    }

    func buildSettingsSections() -> AnyView {
        return AnyView(EmptyView())
    }

    @MainActor func prepareForTermination() async {
        cleanupCount += 1
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                self.eventTap.sendKeyPress()
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) {
                    continuation.resume()
                }
            }
        }
        didFinishCleanup = true
    }
}
