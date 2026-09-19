import AppKit

let stripHeight: CGFloat = 60
let stripEndPadding: CGFloat = 3.2
let stripCornerRadius: CGFloat = 22
let stripDimmingColor = NSColor.black.withAlphaComponent(0.08)
let stripBottomMargin: CGFloat = 5

let iconSize: CGFloat = 46
let iconTopInset: CGFloat = 7
let iconSourceMinimumPixels = 64
let runningDotDiameter: CGFloat = 4
let runningDotCenterFromBottom: CGFloat = 6
let runningDotColor = NSColor.white.withAlphaComponent(0.58)
let separatorVerticalInset: CGFloat = 8
let separatorColor = NSColor.white.withAlphaComponent(0.3)
let badgeHeight: CGFloat = 17
let badgeHorizontalPadding: CGFloat = 2.5
let badgeInsetFromIconRight: CGFloat = 1
let badgeColor = NSColor.systemRed
let badgeTextAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.white]

let toggleSlotWidth: CGFloat = 28
let toggleGapHalfHeight: CGFloat = 9
let toggleCountGap: CGFloat = 3
let toggleCountAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.5)]
let chevronWidth: CGFloat = 7
let chevronHeight: CGFloat = 12
let chevronLineWidth: CGFloat = 1.5
let chevronColor = NSColor.white.withAlphaComponent(0.5)
let toggleBadgeDotDiameter: CGFloat = 5
let toggleHoverColor = NSColor.white.withAlphaComponent(0.10)
let toggleHoverCornerRadius: CGFloat = 8
let toggleHoverVerticalInset: CGFloat = 8

let tooltipPillHeight: CGFloat = 26
let tooltipHorizontalPadding: CGFloat = 14.5
let tooltipCaretHalfBase: CGFloat = 6
let tooltipCaretHeight: CGFloat = 6
let tooltipCaretFillet: CGFloat = 7
let tooltipTipAboveStrip: CGFloat = 6
let tooltipFillColor = NSColor(srgbRed: 74 / 255, green: 77 / 255, blue: 85 / 255, alpha: 0.88)
let tooltipTopRimColor = NSColor.white.withAlphaComponent(0.2)
let tooltipBottomRimColor = NSColor.white.withAlphaComponent(0.15)
let tooltipTextAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white]

final class TooltipView: NSView {
    var text = "" {
        didSet { needsDisplay = true }
    }

    static func getSize(for text: String) -> NSSize {
        let textWidth = (text as NSString).size(withAttributes: tooltipTextAttributes).width
        return NSSize(width: ceil(textWidth) + 2 * tooltipHorizontalPadding, height: tooltipPillHeight + tooltipCaretHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let pill = NSRect(x: 0, y: tooltipCaretHeight, width: bounds.width, height: tooltipPillHeight)

        tooltipFillColor.setFill()
        buildShape(pill: pill).fill()
        drawRims(pill: pill)
        drawText(pill: pill)
    }

    /// The capsule plus the caret hanging below its middle; one fill, so the translucent color never doubles up.
    private func buildShape(pill: NSRect) -> NSBezierPath {
        let shape = NSBezierPath(roundedRect: pill, xRadius: tooltipPillHeight / 2, yRadius: tooltipPillHeight / 2)
        let centerX = pill.midX
        let base = pill.minY
        let halfBase = tooltipCaretHalfBase
        let fillet = tooltipCaretFillet

        let caret = NSBezierPath()
        caret.move(to: NSPoint(x: centerX - halfBase - fillet, y: base + 1))
        caret.curve(to: NSPoint(x: centerX - halfBase + 2, y: base - 2), controlPoint1: NSPoint(x: centerX - halfBase - 2, y: base + 1), controlPoint2: NSPoint(x: centerX - halfBase, y: base))
        caret.line(to: NSPoint(x: centerX - 1.2, y: base - tooltipCaretHeight + 1.2))
        caret.curve(to: NSPoint(x: centerX + 1.2, y: base - tooltipCaretHeight + 1.2), controlPoint1: NSPoint(x: centerX - 0.4, y: base - tooltipCaretHeight), controlPoint2: NSPoint(x: centerX + 0.4, y: base - tooltipCaretHeight))
        caret.line(to: NSPoint(x: centerX + halfBase - 2, y: base - 2))
        caret.curve(to: NSPoint(x: centerX + halfBase + fillet, y: base + 1), controlPoint1: NSPoint(x: centerX + halfBase, y: base), controlPoint2: NSPoint(x: centerX + halfBase + 2, y: base + 1))
        caret.close()
        shape.append(caret)

        return shape
    }

    /// Apple's pill has bright top and bottom edges and plain sides; the bottom one stops at the caret's fillets.
    private func drawRims(pill: NSRect) {
        let radius = tooltipPillHeight / 2
        let caretSpan = tooltipCaretHalfBase + tooltipCaretFillet

        tooltipTopRimColor.setFill()
        NSRect(x: radius, y: pill.maxY - 1, width: pill.width - 2 * radius, height: 1).fill()
        tooltipBottomRimColor.setFill()
        NSRect(x: radius, y: pill.minY, width: pill.midX - caretSpan - radius, height: 1).fill()
        NSRect(x: pill.midX + caretSpan, y: pill.minY, width: pill.maxX - radius - pill.midX - caretSpan, height: 1).fill()
    }

    /// Font smoothing thickens white text on a transparent layer; Apple's tooltip text is lighter than that.
    private func drawText(pill: NSRect) {
        let size = (text as NSString).size(withAttributes: tooltipTextAttributes)
        let origin = NSPoint(x: pill.midX - size.width / 2, y: pill.midY - size.height / 2)

        NSGraphicsContext.current!.cgContext.setShouldSmoothFonts(false)
        (text as NSString).draw(at: origin, withAttributes: tooltipTextAttributes)
    }
}
