import SwiftUI

/// A round symbol filled with the tint while highlighted, beside a title and a subtitle, as Control Center draws its modules. The whole row is
/// one button; a row that toggles something adds the toggle trait where it is used.
struct PopoverRoundButtonRow: View {
    let title: String
    /// Secondary unless it brings a colour of its own.
    let subtitle: Text
    let symbolName: String
    let tint: Color
    let isFilled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: roundButtonSpacing) {
                Image(systemName: symbolName)
                    .font(roundButtonSymbolFont)
                    .foregroundStyle(isFilled ? Color.white : Color.primary)
                    .frame(width: roundButtonDiameter, height: roundButtonDiameter)
                    .background(Circle().fill(isFilled ? tint : roundButtonUnfilledFill))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(tileTitleFont)
                    subtitle
                        .font(secondaryLineFont)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
        .animation(popoverStateAnimation, value: isFilled)
    }
}
