import CoreGraphics

struct MaximizedWindowArea: Equatable {
    private static let maximumTilingMargin: CGFloat = 20
    private static let edgeTolerance: CGFloat = 2

    let visibleFrame: CGRect
    let reservedTop: CGFloat
    let primaryScreenTop: CGFloat

    func getAdjustedFrame(_ frame: CGRect) -> CGRect? {
        if !isMaximized(frame) { return nil }
        if frame.minY >= reservedTop - Self.edgeTolerance { return nil }
        let height = frame.maxY - reservedTop
        if height <= 0 { return nil }
        return CGRect(x: frame.minX, y: reservedTop, width: frame.width, height: height)
    }

    func convertScreenCoordinates(_ frame: CGRect) -> CGRect {
        return CGRect(x: frame.minX, y: primaryScreenTop - frame.maxY, width: frame.width, height: frame.height)
    }

    private func isMaximized(_ frame: CGRect) -> Bool {
        if !isEdgeInset(frame.minX - visibleFrame.minX) { return false }
        if !isEdgeInset(visibleFrame.maxX - frame.maxX) { return false }
        if !isEdgeInset(frame.minY - visibleFrame.minY) { return false }
        if !isEdgeInset(visibleFrame.maxY - frame.maxY) { return false }
        return true
    }

    private func isEdgeInset(_ distance: CGFloat) -> Bool {
        if distance < -Self.edgeTolerance { return false }
        return distance <= Self.maximumTilingMargin
    }
}
