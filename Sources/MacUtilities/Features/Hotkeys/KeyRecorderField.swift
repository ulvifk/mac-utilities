import SwiftUI

struct KeyRecorderField: NSViewRepresentable {
    let combo: KeyCombo?
    let onRecord: (KeyCombo) -> Void

    func makeNSView(context: Context) -> KeyRecorderButton {
        let button = KeyRecorderButton(frame: .zero)
        button.bezelStyle = .rounded
        return button
    }

    func updateNSView(_ button: KeyRecorderButton, context: Context) {
        button.combo = combo
        button.onRecord = onRecord
    }
}
