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

/// Icon tiles in the sidebar, the size System Settings draws its own.
let sidebarIconSize: CGFloat = 20
/// A tile's corner radius and its symbol's point size, as shares of its side, so tiles of every size look alike.
let iconTileCornerRadiusShare: CGFloat = 0.25
let iconTileSymbolShare: CGFloat = 0.52
/// A hairline around every tile, bright at the top and fading down, like light catching the edge of glass.
let iconTileEdgeGradient = Gradient(colors: [.white.opacity(0.35), .white.opacity(0.05)])

let generalIconSymbolName = "gearshape"
let generalIconGradient = Gradient(colors: [Color(white: 0.62), Color(white: 0.44)])
