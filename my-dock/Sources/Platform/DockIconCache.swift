import AppKit

final class DockIconCache {
    private var images: [URL: NSImage] = [:]

    func getIcon(_ app: SavedApp) -> NSImage {
        if let image = images[app.url] { return image }
        let original = NSWorkspace.shared.icon(forFile: app.url.path)
        let image = buildIcon(original)
        images[app.url] = image
        return image
    }

    private func buildIcon(_ original: NSImage) -> NSImage {
        let representations = original.representations.filter { $0.pixelsWide >= iconSourceMinimumPixels }
        guard let representation = representations.min(by: { $0.pixelsWide < $1.pixelsWide }) else { return original }
        let image = NSImage(size: NSSize(width: iconSize, height: iconSize))
        image.addRepresentation(representation)
        return image
    }
}
