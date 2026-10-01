import SwiftUI

struct IPhoneMicSettingsView: View {
    @ObservedObject var feature: IPhoneMicFeature

    var body: some View {
        Section {
            LabeledContent("Current microphone", value: feature.defaultInput?.name ?? "None")

            Toggle(isOn: Binding(get: { feature.isIPhoneSelected }, set: { _ in feature.toggle() })) {
                Text("Use iPhone microphone")
                Text(feature.statusText)
            }
            .disabled(!feature.canToggle)

            Button("Open Sound Settings…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!)
            }
        } footer: {
            Text("Turning this off restores the previous microphone if it is still connected. Apps with their own microphone selection may need you to choose the iPhone there.")
        }

        Section("Connect your iPhone") {
            Text("Use the same Apple Account with two-factor authentication. Enable Continuity Camera in iPhone Settings → General → AirPlay & Continuity.")
            Text("Keep the iPhone nearby, locked and still. Enable Wi-Fi and Bluetooth on both devices, or connect with USB and trust this Mac.")
            Link("Continuity Camera setup and requirements", destination: URL(string: "https://support.apple.com/en-us/102546")!)
        }
    }
}
