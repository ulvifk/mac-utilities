import AppKit
@testable import MacUtilities

/// A 1440x900 visible screen whose thumbnail captures wait for the test to complete them.
final class SwitcherFakeScreen: SwitcherScreen {
    let visibleSize = NSSize(width: 1440, height: 900)
    private(set) var thumbnailRequests: [SwitcherThumbnailRequest] = []

    func captureThumbnails(of windowIDs: [CGWindowID], onCaptured: @escaping (CGWindowID, NSImage) -> Void) {
        if windowIDs.isEmpty { return }

        thumbnailRequests.append(SwitcherThumbnailRequest(windowIDs: windowIDs, onCaptured: onCaptured))
    }
}

struct SwitcherThumbnailRequest {
    let windowIDs: [CGWindowID]
    let onCaptured: (CGWindowID, NSImage) -> Void
}
