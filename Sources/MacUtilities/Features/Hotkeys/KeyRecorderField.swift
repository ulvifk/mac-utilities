import SwiftUI

struct KeyRecorderField: NSViewRepresentable {
    let combo: KeyCombo?
    let onRecord: (KeyCombo) -> Void

    func makeNSView(context: Context) -> KeyRecorderButton {
        return KeyRecorderButton()
    }

    func updateNSView(_ button: KeyRecorderButton, context: Context) {
        button.combo = combo
        button.onRecord = onRecord
    }
}
