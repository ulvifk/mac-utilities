import SwiftUI

/// A round toggle filled with the tint while on, beside a title and a subtitle, as Control Center draws its modules. The whole row toggles.
struct PopoverToggleRow: View {
    let title: String
    /// Secondary unless it brings a colour of its own.
    let subtitle: Text
    let symbolName: String
    let tint: Color
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: roundToggleSpacing) {
                Image(systemName: symbolName)
                    .font(roundToggleSymbolFont)
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .frame(width: roundToggleDiameter, height: roundToggleDiameter)
                    .background(Circle().fill(isOn ? tint : roundToggleOffFill))

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
        .accessibilityAddTraits(.isToggle)
        .animation(popoverStateAnimation, value: isOn)
    }
}
