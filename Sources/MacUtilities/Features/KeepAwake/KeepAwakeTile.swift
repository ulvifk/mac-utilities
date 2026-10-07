import SwiftUI

private let keepAwakeTint = Color.orange

struct KeepAwakeTile: View {
    @ObservedObject var feature: KeepAwakeFeature
    @ObservedObject var preferences: KeepAwakePreferences

    var body: some View {
        let isActive = feature.session != nil

        PopoverTile {
            VStack(alignment: .leading, spacing: tilePadding) {
                PopoverToggleRow(
                    title: "Keep Awake",
                    subtitle: buildSubtitle(),
                    symbolName: keepAwakeSymbolName,
                    tint: keepAwakeTint,
                    isOn: isActive,
                    toggle: feature.toggle
                )

                HStack(spacing: chipSpacing) {
                    ForEach(KeepAwakeAutoOff.allCases, id: \.self) { autoOff in
                        buildChip(autoOff)
                    }
                }
                .animation(popoverStateAnimation, value: feature.session?.autoOff)

                Toggle(isOn: buildPowerOnlyBinding()) {
                    Text("Only while connected to power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(secondaryLineFont)
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

        if feature.isChangingSession {
            return Text(feature.session == nil ? "Turning on…" : "Restoring sleep…")
        }

        if feature.isWaitingForPower {
            return Text("Waiting for power")
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

    private func buildPowerOnlyBinding() -> Binding<Bool> {
        return Binding(
            get: { preferences.onlyWhileConnectedToPower },
            set: { preferences.setOnlyWhileConnectedToPower($0) }
        )
    }
}
