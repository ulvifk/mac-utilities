import SwiftUI

struct IPhoneMicTile: View {
    @ObservedObject var feature: IPhoneMicFeature

    var body: some View {
        PopoverTile {
            PopoverToggleRow(
                title: feature.displayName,
                subtitle: Text(feature.statusText),
                symbolName: feature.iconSymbolName,
                tint: .cyan,
                isOn: feature.isIPhoneSelected,
                toggle: feature.toggle
            )
            .disabled(!feature.canToggle)
        }
    }
}
