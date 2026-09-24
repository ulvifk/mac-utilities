import SwiftUI

/// The auto-off timer and whether a closed lid is kept awake too or only idle sleep is held off.
struct KeepAwakeSettingsView: View {
    @ObservedObject var preferences: KeepAwakePreferences

    var body: some View {
        Form {
            Section {
                Picker("Turn off after", selection: buildAutoOffBinding()) {
                    ForEach(KeepAwakeAutoOff.allCases, id: \.self) { autoOff in
                        Text(autoOff.title)
                    }
                }
                Toggle("Keep awake with the lid closed", isOn: buildLidClosedBinding())
            } footer: {
                Text("Both apply the next time Keep awake is turned on. Keeping a closed lid awake runs pmset as root through the sudoers line install.sh installs; with it off only idle sleep is held off and the display may still sleep.")
            }
        }
        .formStyle(.grouped)
    }

    private func buildAutoOffBinding() -> Binding<KeepAwakeAutoOff> {
        return Binding(
            get: { preferences.autoOff },
            set: { preferences.setAutoOff($0) }
        )
    }

    private func buildLidClosedBinding() -> Binding<Bool> {
        return Binding(
            get: { preferences.keepsAwakeWithLidClosed },
            set: { preferences.setKeepsAwakeWithLidClosed($0) }
        )
    }
}
