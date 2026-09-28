import AppKit

/// The icon image; Tahoe icons fill ~80.5% of their canvas, so the visible squircle is ~55 wide. The cell is as wide as the image.
let iconSize: CGFloat = 68
let itemSpacing: CGFloat = 5
let horizontalPadding: CGFloat = 22
/// The panel width until its edge is dragged once, as a share of the screen; the cells wrap to the next row around it.
let defaultPanelWidthFraction: CGFloat = 0.7
/// The strip along each side edge that shows the resize cursor and takes the drag; it fits inside the padding, clear of the cells.
let resizeHandleWidth: CGFloat = 12
let iconVerticalPadding: CGFloat = 7.5
let dotSize: CGFloat = 5

/// The 13pt name label's height. The whitelist dot gets a band of the same height above the icon, so the two mirror each other.
let nameBandHeight: CGFloat = 16
let nameTopSpacing: CGFloat = 0
/// Rows overlap their bands: the name below one row's icons ends 3pt above the whitelist dots of the next.
let iconRowSpacing: CGFloat = -8
/// Below the band's centre, so the dot reads as attached to the icon rather than floating.
let dotCenterFromCellTop: CGFloat = nameBandHeight / 2 + 3
/// Mirrored bands above and below, so the icon lands exactly in the middle of the cell.
let iconCellHeight: CGFloat = iconSize + 2 * (nameBandHeight + nameTopSpacing)
let iconFrameInCell = NSRect(x: 0, y: nameBandHeight + nameTopSpacing, width: iconSize, height: iconSize)
let dotFrameInCell = NSRect(x: (iconSize - dotSize) / 2, y: iconCellHeight - dotCenterFromCellTop - dotSize / 2, width: dotSize, height: dotSize)
/// The native highlight hugs the icon's squircle with a 3pt margin and has no stroke.
let highlightColor = NSColor.white.withAlphaComponent(0.30)
let highlightCornerRadius: CGFloat = 15.5
/// The 68pt image has a ~6.5pt transparent margin around the squircle, and the highlight sits 3pt outside it.
let highlightIconInset: CGFloat = 3.5
/// Concentric with the highlight: its radius plus its distance from the side edges.
let panelCornerRadius: CGFloat = highlightCornerRadius + horizontalPadding + highlightIconInset
/// Leaves the hint tray about as far below the name band as above the bottom edge.
let iconHintBandHeight: CGFloat = 38
let iconCellMetrics = SwitcherCellMetrics(
    cellSize: NSSize(width: iconSize, height: iconCellHeight),
    highlightFrameInCell: iconFrameInCell.insetBy(dx: highlightIconInset, dy: highlightIconInset),
    rowSpacing: iconRowSpacing,
    verticalPadding: iconVerticalPadding,
    hintBandHeight: iconHintBandHeight
)

/// A window's thumbnail is fitted into this box keeping its aspect ratio, and never scaled up.
let windowThumbnailSize = NSSize(width: 224, height: 140)
let windowTitleHeight: CGFloat = 16
let windowTitleTopSpacing: CGFloat = 5
/// From the cell's edge to the thumbnail and title: the highlight sits as far inside the cell as around an icon, and the content 7pt inside the highlight.
let windowContentInset: CGFloat = highlightIconInset + 7
let windowCellSize = NSSize(
    width: windowThumbnailSize.width + 2 * windowContentInset,
    height: windowThumbnailSize.height + windowTitleTopSpacing + windowTitleHeight + 2 * windowContentInset
)
let windowTitleFrameInCell = NSRect(x: windowContentInset, y: windowContentInset, width: windowThumbnailSize.width, height: windowTitleHeight)
let windowThumbnailFrameInCell = NSRect(
    x: windowContentInset,
    y: windowTitleFrameInCell.maxY + windowTitleTopSpacing,
    width: windowThumbnailSize.width,
    height: windowThumbnailSize.height
)
/// The card framing each window's thumbnail and title, where the highlight also sits.
let windowCardFrameInCell = NSRect(origin: .zero, size: windowCellSize).insetBy(dx: highlightIconInset, dy: highlightIconInset)
/// The card's black fill until its darkness slider is moved: enough to keep the title readable on clear glass.
let defaultWindowCardDarkness: CGFloat = 0.3
let windowCardBorderColor = NSColor.white.withAlphaComponent(0.18)
let windowCardBorderWidth: CGFloat = 1
/// The selected card's border is Mission Control's ring around a hovered window, in the accent colour, so it shows on bright glass too.
let selectedWindowCardBorderWidth: CGFloat = 3
/// Lower than below icons: the rows' wide bottom padding already holds part of the hint tray, which ends about as far below the cards as above
/// the bottom edge.
let windowHintBandHeight: CGFloat = 28
/// Padded like the sides, so the highlight stays concentric with the panel at the top and bottom corners too; rows as far apart as columns.
let windowCellMetrics = SwitcherCellMetrics(
    cellSize: windowCellSize,
    highlightFrameInCell: windowCardFrameInCell,
    rowSpacing: itemSpacing,
    verticalPadding: horizontalPadding,
    hintBandHeight: windowHintBandHeight
)

/// The black tint's opacity until the darkness slider is moved; it pulls the glass down so the icons and the name stand out.
let defaultGlassDarkness: CGFloat = 0.14
let maxGlassDarkness: CGFloat = 0.6
/// How long the preview stays after the last change in the settings tab.
let glassPreviewDuration: TimeInterval = 1
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

/// How long the panel stays open before the shortcut hints come in, so a quick Cmd+Tab never shows them.
let hintDelay: TimeInterval = 0.9
/// The hint band growing in and the hints fading in.
let hintFadeDuration: TimeInterval = 0.2

let hintKeycapHeight: CGFloat = 18
let hintKeycapCornerRadius: CGFloat = 5
let hintKeycapHorizontalPadding: CGFloat = 5
let hintKeycapColor = NSColor.white.withAlphaComponent(0.16)
let hintKeycapActionSpacing: CGFloat = 5
/// From one hint's text to the next keycap.
let hintSpacing: CGFloat = 14
let hintActionColor = NSColor.white.withAlphaComponent(0.9)

/// The hints sit in a dark tray, so they read on bright glass too, this far above the panel's bottom edge.
let hintTrayBottomPadding: CGFloat = 10
/// Around the keycaps; after the last hint's text the tray runs on a little further.
let hintTrayPadding: CGFloat = 4
let hintTrayTrailingPadding: CGFloat = 10
let hintTrayHeight: CGFloat = hintKeycapHeight + 2 * hintTrayPadding
/// Concentric with the keycaps.
let hintTrayCornerRadius: CGFloat = hintKeycapCornerRadius + hintTrayPadding
let hintTrayColor = NSColor.black.withAlphaComponent(0.26)
/// The tray grows no nearer the side edges than this, which at its height keeps it clear of the panel's rounded corners, so even a panel one
/// icon wide has room for the shortest hint.
let hintTraySideInset: CGFloat = 16
