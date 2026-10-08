import SwiftUI

struct MicrophoneSettingsView: View {
    @ObservedObject var feature: MicrophoneFeature

    var body: some View {
        Section {
            LabeledContent("Current microphone", value: feature.defaultInput?.name ?? "None")
            MicrophonePicker(feature: feature)

            Button("Restore previous microphone", action: feature.restorePreviousInput)
                .disabled(!feature.canRestore)
            Text(feature.statusText)
                .foregroundStyle(.secondary)

            Button("Open Sound Settings…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!)
            }
        } footer: {
            Text("Restore the previous microphone to turn off the selection. Disabling this feature or quitting also restores it if it is still connected. Apps with their own microphone selection need you to choose the input there.")
        }

        Section("Available microphones") {
            Text("Choose any audio input available to macOS: the built-in microphone, a USB microphone, a Bluetooth headset or an iPhone microphone. The list updates when devices connect or disconnect.")
            Text("For an iPhone, enable Continuity Camera and use the same Apple Account on both devices. Keep it nearby, locked and still, or connect with USB and trust this Mac.")
            Link("Continuity Camera setup and requirements", destination: URL(string: "https://support.apple.com/en-us/102546")!)
        }
    }
}
