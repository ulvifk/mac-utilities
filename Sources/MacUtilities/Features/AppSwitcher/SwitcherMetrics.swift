import AppKit

/// The icon image; Tahoe icons fill ~80.5% of their canvas, so the visible squircle is ~55 wide. The cell is as wide as the image.
let iconSize: CGFloat = 68
let itemSpacing: CGFloat = 5
let horizontalPadding: CGFloat = 22
/// The panel width until its edge is dragged once, as a share of the screen; the icons wrap to the next row around it.
let defaultPanelWidthFraction: CGFloat = 0.7
/// The strip along each side edge that shows the resize cursor and takes the drag; it fits inside the padding, clear of the icons.
let resizeHandleWidth: CGFloat = 12
let verticalPadding: CGFloat = 9.5
let dotSize: CGFloat = 5

/// The 13pt name label's height. The whitelist dot gets a band of the same height above the icon, so the two mirror each other.
let nameBandHeight: CGFloat = 16
/// Keeps the name capsule clear of the highlight above it.
let nameTopSpacing: CGFloat = 2
/// Rows overlap their bands: the name capsule below one row's icons ends 2.5pt above the whitelist dots of the next.
let rowSpacing: CGFloat = -6
/// Below the band's centre, so the dot reads as attached to the icon rather than floating.
let dotCenterFromCellTop: CGFloat = nameBandHeight / 2 + 3 + nameTopSpacing
/// Mirrored bands above and below, so the icon lands exactly in the middle of the cell.
let cellHeight: CGFloat = iconSize + 2 * (nameBandHeight + nameTopSpacing)
let iconFrameInCell = NSRect(x: 0, y: nameBandHeight + nameTopSpacing, width: iconSize, height: iconSize)
/// The selected icon grows by this much on every side, 68 to 72pt, around its middle.
let selectedIconGrowth: CGFloat = 2
let selectedIconFrameInCell = iconFrameInCell.insetBy(dx: -selectedIconGrowth, dy: -selectedIconGrowth)
let dotFrameInCell = NSRect(x: (iconSize - dotSize) / 2, y: cellHeight - dotCenterFromCellTop - dotSize / 2, width: dotSize, height: dotSize)
/// The highlight is a drop of glass tinted toward white, hugging the selected icon's squircle with a 3pt margin.
let highlightColor = NSColor.white.withAlphaComponent(0.30)
let highlightCornerRadius: CGFloat = 15.5
/// The grown 72pt image has a ~7pt transparent margin around the squircle, and the highlight sits 3pt outside it.
let highlightIconInset: CGFloat = 4
/// Moving to a neighbouring icon, the highlight first stretches over both, then lets go of the old one.
let highlightStretchDuration: TimeInterval = 0.08
let highlightSettleDuration: TimeInterval = 0.16
/// Concentric with the highlight: its radius plus its distance from the side edges.
let panelCornerRadius: CGFloat = highlightCornerRadius + horizontalPadding - selectedIconGrowth + highlightIconInset
/// Room around the glass for its soft shadow: the window is this much larger on every side.
let shadowMargin: CGFloat = 48
let shadowRadius: CGFloat = 18
let shadowOpacity: CGFloat = 0.3
let shadowOffset = CGSize(width: 0, height: -8)
/// On opening the panel springs up from this scale while it fades in.
let openingScale: CGFloat = 0.94
let openingDuration: TimeInterval = 0.35
let openingBounce: CGFloat = 0.2
/// The selected app's name sits on a small glass capsule reaching this far past the text.
let nameCapsuleHorizontalPadding: CGFloat = 8
let nameCapsuleVerticalPadding: CGFloat = 2
let nameCapsuleTintColor = NSColor.black.withAlphaComponent(0.25)
/// Clear glass keeps the backdrop's colour where regular glass washes it out; the tint pulls it down so the icons and the name stand out.
let panelTintColor = NSColor.black.withAlphaComponent(0.14)
/// The capsule saying only the whitelist is listed, centered in the band above the top row where the dots would be.
let badgeHeight: CGFloat = 16
let badgeHorizontalPadding: CGFloat = 7
let badgeSymbolSpacing: CGFloat = 3
let badgeColor = NSColor.systemGreen.withAlphaComponent(0.85)
/// Hidden apps stay listed, dimmed like in the native switcher, so they can be brought back.
let hiddenIconAlpha: CGFloat = 0.4
/// After Cmd+Q the icon fades and shrinks out while the rest slide into place, over this long.
let removalDuration: TimeInterval = 0.15
/// How far the leaving icon's edges pull in while it fades: to half its size.
let leavingIconShrink: CGFloat = iconSize / 4
