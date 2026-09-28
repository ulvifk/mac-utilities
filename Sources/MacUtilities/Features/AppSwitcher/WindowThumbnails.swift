import AppKit
import ScreenCaptureKit

/// Captures what each window shows, covered ones included, and hands every thumbnail to `onCaptured` on the main thread as it arrives. Minimized
/// windows and those on another Space draw nothing and are left out. Needs Screen Recording: without it the listing fails, as does the capture of a
/// window closed meanwhile, and the task ends there, leaving the app's icon in place.
func captureThumbnails(of windowIDs: [CGWindowID], onCaptured: @escaping (CGWindowID, NSImage) -> Void) {
    _ = Task { @MainActor in
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        for window in content.windows where windowIDs.contains(window.windowID) {
            _ = Task { @MainActor in
                onCaptured(window.windowID, try await captureThumbnail(of: window))
            }
        }
    }
}

/// At the main screen's pixel density, so the thumbnail is sharp where the panel shows it.
@MainActor
private func captureThumbnail(of window: SCWindow) async throws -> NSImage {
    let size = getThumbnailSize(forWindowSize: window.frame.size)
    let scale = NSScreen.main!.backingScaleFactor
    let configuration = SCStreamConfiguration()

    configuration.width = Int(size.width * scale)
    configuration.height = Int(size.height * scale)
    configuration.showsCursor = false
    configuration.ignoreShadowsSingleWindow = true

    let image: CGImage = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration)
    return NSImage(cgImage: image, size: size)
}

private func getThumbnailSize(forWindowSize windowSize: CGSize) -> NSSize {
    let scale = min(windowThumbnailSize.width / windowSize.width, windowThumbnailSize.height / windowSize.height, 1)

    return NSSize(width: (windowSize.width * scale).rounded(), height: (windowSize.height * scale).rounded())
}
