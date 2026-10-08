import SwiftUI

struct MicrophoneTile: View {
    @ObservedObject var feature: MicrophoneFeature

    var body: some View {
        PopoverTile {
            VStack(alignment: .leading, spacing: 8) {
                Label(feature.displayName, systemImage: feature.iconSymbolName)
                    .font(tileTitleFont)
                MicrophonePicker(feature: feature)
                    .pickerStyle(.menu)
                    .labelsHidden()
                Text(feature.statusText)
                    .font(secondaryLineFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if feature.isActive {
                    Button("Restore previous microphone", action: feature.restorePreviousInput)
                        .disabled(!feature.canRestore)
                }
            }
        }
    }
}
