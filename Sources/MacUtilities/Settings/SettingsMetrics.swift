import SwiftUI

/// The window opens at this content size and grows either way; like System Settings it gets no narrower, which the hotkey rows need, but it can
/// get shorter down to the minimum height.
let settingsWindowSize = NSSize(width: 720, height: 540)
let settingsWindowMinimumHeight: CGFloat = 420
let settingsSidebarWidth: CGFloat = 200
let sidebarRowHeight: CGFloat = 28
/// Sets General apart from the features.
let sidebarGapHeight: CGFloat = 12
let sidebarIconTitleSpacing: CGFloat = 8

/// Icon tiles in the sidebar and on the app's card, the size System Settings draws its sidebar's.
let smallIconTileSize: CGFloat = 20
/// The tile in a feature pane's header.
let paneHeaderIconSize: CGFloat = 44
/// The app icon's body fills about 80% of its canvas, so at this size it looks as large as the tiles.
let paneHeaderAppIconSize: CGFloat = 54
/// A tile's corner radius and its symbol's point size, as shares of its side, so tiles of every size look alike.
let iconTileCornerRadiusShare: CGFloat = 0.25
let iconTileSymbolShare: CGFloat = 0.52
/// A hairline around every tile, bright at the top and fading down, like light catching the edge of glass.
let iconTileEdgeGradient = Gradient(colors: [.white.opacity(0.35), .white.opacity(0.05)])

let generalIconSymbolName = "gearshape"
let generalIconGradient = Gradient(colors: [Color(white: 0.62), Color(white: 0.44)])

/// A switched-off feature's pane sections and its tile on the app's card fade to this. Disabled controls dim on their own but their labels do
/// not, so the whole is faded to read as off.
let switchedOffFeatureOpacity: CGFloat = 0.5
