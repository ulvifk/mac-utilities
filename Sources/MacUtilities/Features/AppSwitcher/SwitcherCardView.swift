import AppKit

final class SwitcherCardView: NSView {
    private let blur = NSVisualEffectView()
    private let tint = NSView()
    private let border = NSView()

    convenience init(glass: GlassStore?) {
        self.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true

        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active

        tint.wantsLayer = true
        border.wantsLayer = true
        setCorners(radius: highlightCornerRadius, curve: .circular)

        for view in [blur, tint, border] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }

        updateGlass(glass)
        showSelected(false)
    }

    func updateGlass(_ glass: GlassStore?) {
        isHidden = glass == nil
        guard let glass else { return }

        blur.isHidden = !glass.isFrosted
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(glass.darkness).cgColor
    }

    func showSelected(_ isSelected: Bool) {
        border.layer?.borderWidth = isSelected ? selectedCardBorderWidth : cardBorderWidth
        border.layer?.borderColor = (isSelected ? NSColor.controlAccentColor : cardBorderColor).cgColor
    }

    func setCorners(radius: CGFloat, curve: CALayerCornerCurve) {
        layer?.cornerRadius = radius
        layer?.cornerCurve = curve
        border.layer?.cornerRadius = radius
        border.layer?.cornerCurve = curve
    }
}
