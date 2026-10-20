import SwiftUI

let popoverWidth: CGFloat = 300
/// Around the header, the tiles and the footer.
let popoverPadding: CGFloat = 12
/// Between the header, the tiles and the footer.
let popoverSectionSpacing: CGFloat = 12
let popoverTitleFont = Font.system(size: 15, weight: .bold)
/// The app icon's body fills about 80% of its canvas, so at this size it is as large as the round buttons.
let popoverAppIconSize: CGFloat = 42
/// Between the icon's canvas and its body, on each side.
let popoverAppIconMargin = (popoverAppIconSize - roundButtonDiameter) / 2
/// Tile subtitles and the header's status line.
let secondaryLineFont = Font.system(size: 11)
/// A round button filling or a chip being picked.
let popoverStateAnimation = Animation.easeOut(duration: 0.15)

let tileSpacing: CGFloat = 8
let tilePadding: CGFloat = 10
let tileCornerRadius: CGFloat = 14
let tileFill = Color.primary.opacity(0.06)
let tileTitleFont = Font.system(size: 13, weight: .semibold)

let roundButtonDiameter: CGFloat = 34
let roundButtonSymbolFont = Font.system(size: 15, weight: .semibold)
let roundButtonUnfilledFill = Color.primary.opacity(0.1)
/// Between the round button and its title.
let roundButtonSpacing: CGFloat = 10

let chipHeight: CGFloat = 26
let chipSpacing: CGFloat = 6
let chipFill = Color.primary.opacity(0.08)
let chipFont = Font.system(size: 12, weight: .medium)
