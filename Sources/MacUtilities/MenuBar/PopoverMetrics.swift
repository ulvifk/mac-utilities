import SwiftUI

let popoverWidth: CGFloat = 300
/// Around the header, the tiles and the footer.
let popoverPadding: CGFloat = 12
/// Between the header, the tiles and the footer.
let popoverSectionSpacing: CGFloat = 12
let popoverTitleFont = Font.system(size: 15, weight: .bold)
/// Tile subtitles and the header's status line.
let secondaryLineFont = Font.system(size: 11)
/// A round toggle filling or emptying.
let popoverStateAnimation = Animation.easeOut(duration: 0.15)

let tileSpacing: CGFloat = 8
let tilePadding: CGFloat = 10
let tileCornerRadius: CGFloat = 14
let tileFill = Color.primary.opacity(0.06)
let tileTitleFont = Font.system(size: 13, weight: .semibold)

let roundToggleDiameter: CGFloat = 34
let roundToggleSymbolFont = Font.system(size: 15, weight: .semibold)
let roundToggleOffFill = Color.primary.opacity(0.1)
/// Between the round toggle and its title.
let roundToggleSpacing: CGFloat = 10
