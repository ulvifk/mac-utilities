import SwiftUI

private let keycapHeight: CGFloat = 20
private let keycapMinWidth: CGFloat = 20
private let keycapHorizontalPadding: CGFloat = 5
private let keycapCornerRadius: CGFloat = 5
private let keycapSpacing: CGFloat = 3
private let keycapFontSize: CGFloat = 11
/// A hairline under each keycap, so it sits on the row like a key.
private let keycapShadowColor = Color.black.opacity(0.18)

/// A shortcut as the keys to press, each in a small rounded keycap: ⇧ ⌘ ⇥.
struct KeycapsView: View {
    /// In the order they are held, modifiers first.
    let keys: [String]

    var body: some View {
        HStack(spacing: keycapSpacing) {
            ForEach(keys, id: \.self) { key in
                buildKeycap(key)
            }
        }
    }

    private func buildKeycap(_ key: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: keycapCornerRadius, style: .continuous)

        return Text(key)
            .font(.system(size: keycapFontSize, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, keycapHorizontalPadding)
            .frame(minWidth: keycapMinWidth, minHeight: keycapHeight)
            .background(shape.fill(Color(nsColor: .controlColor).shadow(.drop(color: keycapShadowColor, radius: 0.5, y: 0.5))))
            .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
    }
}
