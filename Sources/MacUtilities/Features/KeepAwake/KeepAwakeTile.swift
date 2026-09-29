import SwiftUI

private let keepAwakeTint = Color.orange

/// Keep Awake in the menu bar popover: the round toggle with the time left, and a chip per duration that turns it on for that long from now,
/// the one in use filled.
struct KeepAwakeTile: View {
    @ObservedObject var feature: KeepAwakeFeature

    var body: some View {
        PopoverTile {
            VStack(alignment: .leading, spacing: tilePadding) {
                PopoverToggleRow(
                    title: "Keep Awake",
                    subtitle: buildSubtitle(),
                    symbolName: keepAwakeSymbolName,
                    tint: keepAwakeTint,
                    isOn: feature.session != nil,
                    toggle: feature.toggle
                )

                HStack(spacing: chipSpacing) {
                    ForEach(KeepAwakeAutoOff.allCases, id: \.self) { autoOff in
                        buildChip(autoOff)
                    }
                }
                .animation(popoverStateAnimation, value: feature.session?.autoOff)
            }
        }
    }

    /// Counts down live while a timer is set.
    private func buildSubtitle() -> Text {
        if feature.isSleepRestorationRefused {
            return Text("\(Image(systemName: "exclamationmark.triangle.fill")) Couldn't restore sleep; still on. Retrying automatically, or click the toggle to retry now.")
                .fontWeight(.medium)
                .foregroundStyle(.orange)
        }

        if feature.isPmsetRefused {
            return Text("\(Image(systemName: "exclamationmark.triangle.fill")) Couldn't keep a closed lid awake: run install.sh, or turn the lid option off in Settings")
                .fontWeight(.medium)
                .foregroundStyle(.orange)
        }

        guard let session = feature.session else { return Text("Off") }
        guard let deactivationDate = session.deactivationDate else { return Text("On, never turns off") }

        return Text("\(Text(deactivationDate, style: .timer)) left")
    }

    private func buildChip(_ autoOff: KeepAwakeAutoOff) -> some View {
        let isInUse = isAutoOffInUse(autoOff)

        return Button { feature.turnOn(for: autoOff) } label: {
            Text(getChipTitle(autoOff))
                .font(chipFont)
                .monospacedDigit()
                .foregroundStyle(isInUse ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: chipHeight)
                .background(Capsule().fill(isInUse ? keepAwakeTint : chipFill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(autoOff.title)
        .accessibilityAddTraits(isInUse ? .isSelected : [])
    }

    private func getChipTitle(_ autoOff: KeepAwakeAutoOff) -> String {
        if autoOff == .untilTurnedOff { return "∞" }
        return autoOff.title
    }

    private func isAutoOffInUse(_ autoOff: KeepAwakeAutoOff) -> Bool {
        return feature.session?.autoOff == autoOff
    }
}
