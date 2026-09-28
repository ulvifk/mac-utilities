import SwiftUI

/// A white symbol on a rounded square filled with a gradient, as System Settings marks its panes. The symbol's filled variant is used where
/// there is one.
struct SettingsIconTile: View {
    let symbolName: String
    let gradient: Gradient
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * iconTileCornerRadiusShare, style: .continuous)

        return shape
            .fill(LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom))
            .overlay {
                shape.strokeBorder(LinearGradient(gradient: iconTileEdgeGradient, startPoint: .top, endPoint: .bottom), lineWidth: 0.5)
            }
            .overlay {
                Image(systemName: symbolName)
                    .symbolVariant(.fill)
                    .font(.system(size: size * iconTileSymbolShare, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }
}
