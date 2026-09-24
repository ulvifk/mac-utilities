import AppKit

/// The icon image; Tahoe icons fill ~80.5% of their canvas, so the visible squircle is ~55 wide. The cell is as wide as the image.
let iconSize: CGFloat = 68
let itemSpacing: CGFloat = 5
let horizontalPadding: CGFloat = 22
/// The widest the panel gets, as a share of the screen, before the icons wrap to the next row.
let maxPanelWidthFraction: CGFloat = 0.7
let verticalPadding: CGFloat = 7.5
let dotSize: CGFloat = 5

/// The 13pt name label's height. The whitelist dot gets a band of the same height above the icon, so the two mirror each other.
let nameBandHeight: CGFloat = 16
let nameTopSpacing: CGFloat = 0
/// Rows overlap their bands: the name below one row's icons ends 3pt above the whitelist dots of the next.
let rowSpacing: CGFloat = -8
/// Below the band's centre, so the dot reads as attached to the icon rather than floating.
let dotCenterFromCellTop: CGFloat = nameBandHeight / 2 + 3
/// Mirrored bands above and below, so the icon lands exactly in the middle of the cell.
let cellHeight: CGFloat = iconSize + 2 * (nameBandHeight + nameTopSpacing)
let iconFrameInCell = NSRect(x: 0, y: nameBandHeight + nameTopSpacing, width: iconSize, height: iconSize)
let dotFrameInCell = NSRect(x: (iconSize - dotSize) / 2, y: cellHeight - dotCenterFromCellTop - dotSize / 2, width: dotSize, height: dotSize)
let panelCornerRadius: CGFloat = 28
/// Clear glass keeps the backdrop's colour where regular glass washes it out; this pulls it down to the native
/// switcher's body, roughly 0.63 * backdrop + 19 per channel. The 1pt rim is left undimmed.
let panelDimmingColor = NSColor.black.withAlphaComponent(0.14)
/// Measured off the native switcher, one row at a time from the edge inward. [row from the edge] -> white alpha
let topRimAlphas: [CGFloat] = [0.34, 0.07, 0.03, 0.015]
let bottomRimAlphas: [CGFloat] = [0.35, 0.09, 0.055, 0.045, 0.035, 0.03, 0.02]
/// The native highlight hugs the icon's squircle with a 3pt margin and has no stroke.
let highlightColor = NSColor.white.withAlphaComponent(0.30)
let filteredHighlightColor = NSColor.systemGreen.withAlphaComponent(0.45)
let highlightCornerRadius: CGFloat = 15.5
/// The 68pt image has a ~6.5pt transparent margin around the squircle, and the highlight sits 3pt outside it.
let highlightIconInset: CGFloat = 3.5
/// Hidden apps stay listed, dimmed like in the native switcher, so they can be brought back.
let hiddenIconAlpha: CGFloat = 0.4
/// After Cmd+Q the icon fades and shrinks out while the rest slide into place, over this long.
let removalDuration: TimeInterval = 0.15
/// How far the leaving icon's edges pull in while it fades: to half its size.
let leavingIconShrink: CGFloat = iconSize / 4
