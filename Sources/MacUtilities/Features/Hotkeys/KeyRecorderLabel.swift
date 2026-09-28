import SwiftUI

private let recordingCapsuleFill = Color.accentColor.opacity(0.12)
private let emptyCapsuleDash: [CGFloat] = [3, 2]

private let recordingPrompt = "Press keys…"
private let emptyPrompt = "Record Shortcut"

/// What the key recorder shows: a dashed capsule asking for a shortcut, an accent capsule while recording, or the combo as keycaps.
struct KeyRecorderLabel: View {
    let combo: KeyCombo?
    let isRecording: Bool

    var body: some View {
        buildContent()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }

    /// What VoiceOver reads for the recorder: the prompt shown, or the combo.
    func getAccessibilityText() -> String {
        if isRecording { return recordingPrompt }
        return combo?.symbols ?? emptyPrompt
    }

    @ViewBuilder private func buildContent() -> some View {
        if isRecording {
            Text(recordingPrompt)
                .font(.callout)
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Capsule().fill(recordingCapsuleFill))
                .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1))
        } else if let combo {
            KeycapsView(keys: combo.keyLabels)
        } else {
            Text(emptyPrompt)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(Capsule().strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: emptyCapsuleDash)))
        }
    }
}
