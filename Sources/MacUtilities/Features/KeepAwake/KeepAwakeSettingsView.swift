import SwiftUI

struct KeepAwakeSettingsView: View {
    @ObservedObject var preferences: KeepAwakePreferences

    var body: some View {
        Section {
            Picker("Turn off after", selection: buildAutoOffBinding()) {
                ForEach(KeepAwakeAutoOff.allCases, id: \.self) { autoOff in
                    Text(autoOff.title)
                }
            }
            .pickerStyle(.segmented)

            Toggle(isOn: buildLidClosedBinding()) {
                Text("Keep awake with the lid closed")
                Text("Runs pmset as root through the sudoers line install.sh installs. Off, only idle sleep is held off and the display may still sleep.")
            }

            Toggle(isOn: buildPowerOnlyBinding()) {
                Text("Only while connected to power")
                Text("Restores normal sleep on battery. Reconnecting resumes Keep Awake if it is still enabled and its time has not run out.")
            }
        } footer: {
            Text("The duration and lid options apply the next time Keep Awake is turned on. The power option applies immediately. The duration chips in the menu bar popover set Turn off after too.")
        }
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

    private func buildPowerOnlyBinding() -> Binding<Bool> {
        return Binding(
            get: { preferences.onlyWhileConnectedToPower },
            set: { preferences.setOnlyWhileConnectedToPower($0) }
        )
    }
}
