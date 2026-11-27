import AppKit
import ScreenCaptureKit

/// NSScreen.main, its windows captured with ScreenCaptureKit. Capturing needs Screen Recording: without it the listing fails, as does the capture
/// of a window closed meanwhile, and the task ends there, leaving the app's icon in place.
final class SystemSwitcherScreen: SwitcherScreen {
    var visibleSize: NSSize {
        return NSScreen.main!.visibleFrame.size
    }

    func captureThumbnails(of windowIDs: [CGWindowID], onCaptured: @escaping (CGWindowID, NSImage) -> Void) {
        if windowIDs.isEmpty { return }

        _ = Task { @MainActor in
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            for window in content.windows where windowIDs.contains(window.windowID) {
                _ = Task { @MainActor in
                    onCaptured(window.windowID, try await captureThumbnail(of: window))
                }
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
