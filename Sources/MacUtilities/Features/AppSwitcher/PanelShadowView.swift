import AppKit

/// The soft shadow the glass casts, drawn from the panel's rounded shape; the layer itself has no content. The shadow is cut out under the
/// panel, as the clear glass would show it through and grey out.
final class PanelShadowView: NSView {
    convenience init() {
        self.init(frame: .zero)

        let panelShadow = NSShadow()
        panelShadow.shadowColor = NSColor.black.withAlphaComponent(shadowOpacity)
        panelShadow.shadowBlurRadius = shadowRadius
        panelShadow.shadowOffset = shadowOffset

        wantsLayer = true
        shadow = panelShadow
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    /// Follows the panel as it resizes, through the removal animation too.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        let panelShape = CGPath(roundedRect: bounds, cornerWidth: panelCornerRadius, cornerHeight: panelCornerRadius, transform: nil)
        layer!.shadowPath = panelShape
        layer!.mask = buildOutsideMask(panelShape: panelShape)
    }

    /// Everything within the shadow margin except the panel itself.
    private func buildOutsideMask(panelShape: CGPath) -> CAShapeLayer {
        let outside = CGMutablePath()
        let mask = CAShapeLayer()

        outside.addRect(bounds.insetBy(dx: -shadowMargin, dy: -shadowMargin))
        outside.addPath(panelShape)
        mask.frame = bounds
        mask.path = outside
        mask.fillRule = .evenOdd

        return mask
    }
}
