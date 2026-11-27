import AppKit

/// [window id] -> the window's latest thumbnail, shared by the switcher and its preview and kept until another app's windows are listed, so
/// opening on the same app again shows them at once.
final class WindowThumbnailCache {
    private let screen: SwitcherScreen
    private(set) var thumbnails: [CGWindowID: NSImage] = [:]

    init(screen: SwitcherScreen) {
        self.screen = screen
    }

    /// Drops the thumbnails of other windows and captures these afresh; each is kept, and onUpdated told, as it arrives, unless the session
    /// was renewed meanwhile.
    func refresh(of windows: [SwitcherWindow], session: SwitcherSession, onUpdated: @escaping () -> Void) {
        thumbnails = thumbnails.filter { windowID, _ in windows.contains { $0.windowID == windowID } }

        let keepThumbnail = session.guarding { (windowID: CGWindowID, thumbnail: NSImage) in
            self.thumbnails[windowID] = thumbnail
            onUpdated()
        }
        screen.captureThumbnails(of: windows.map { $0.windowID }) { windowID, thumbnail in keepThumbnail((windowID, thumbnail)) }
    }
}
