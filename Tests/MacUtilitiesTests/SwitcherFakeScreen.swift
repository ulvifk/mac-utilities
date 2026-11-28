import AppKit
import Testing
@testable import MacUtilities

/// A 1440x900 visible screen whose thumbnail captures wait for the test to complete them.
final class SwitcherFakeScreen: SwitcherScreen {
    let visibleSize = NSSize(width: 1440, height: 900)
    private(set) var thumbnailRequests: [SwitcherThumbnailRequest] = []

    func captureThumbnails(of windowIDs: [CGWindowID], onCaptured: @escaping (CGWindowID, NSImage) -> Void) {
        if windowIDs.isEmpty { return }

        thumbnailRequests.append(SwitcherThumbnailRequest(windowIDs: windowIDs, onCaptured: onCaptured))
    }

    /// The capture the switcher asked for that many requests in, counting from 0.
    func getThumbnailRequest(at index: Int, sourceLocation: SourceLocation = #_sourceLocation) throws -> SwitcherThumbnailRequest {
        try #require(index < thumbnailRequests.count, "The switcher asked for fewer thumbnail captures", sourceLocation: sourceLocation)
        return thumbnailRequests[index]
    }
}

struct SwitcherThumbnailRequest {
    let windowIDs: [CGWindowID]
    let onCaptured: (CGWindowID, NSImage) -> Void
}
