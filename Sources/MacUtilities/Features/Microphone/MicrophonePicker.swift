import SwiftUI

struct MicrophonePicker: View {
    @ObservedObject var feature: MicrophoneFeature

    var body: some View {
        Picker("Microphone", selection: Binding(
            get: { feature.defaultInput?.uid },
            set: { uid in
                if let uid { feature.selectInput(uid) }
            }
        )) {
            if feature.defaultInput == nil {
                Text("None").tag(String?.none)
            }
            ForEach(feature.inputDevices, id: \.uid) { input in
                Text(input.name).tag(Optional(input.uid))
            }
        }
        .disabled(!feature.canSelect)
    }
}
