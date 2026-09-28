import SwiftUI

private let keepAwakeTint = Color.orange

/// Keep Awake in the menu bar popover: the round toggle with the time left.
struct KeepAwakeTile: View {
    @ObservedObject var feature: KeepAwakeFeature

    var body: some View {
        PopoverTile {
            PopoverToggleRow(
                title: "Keep Awake",
                subtitle: buildSubtitle(),
                symbolName: keepAwakeSymbolName,
                tint: keepAwakeTint,
                isOn: feature.session != nil,
                toggle: feature.toggle
            )
        }
    }

    /// Counts down live while a timer is set.
    private func buildSubtitle() -> Text {
        if feature.isPmsetRefused {
            return Text("\(Image(systemName: "exclamationmark.triangle.fill")) Couldn't keep a closed lid awake: run install.sh, or turn the lid option off in Settings")
                .fontWeight(.medium)
                .foregroundStyle(.orange)
        }

        guard let session = feature.session else { return Text("Off") }
        guard let deactivationDate = session.deactivationDate else { return Text("On until turned off") }

        return Text("\(Text(deactivationDate, style: .timer)) left")
    }
}
