import SwiftUI

private let darknessSliderWidth: CGFloat = 130

/// One glass in a single row: Clear or Frosted, and the darkness of its black tint.
struct GlassSettingsRow: View {
    let title: String
    @ObservedObject var glassStore: GlassStore

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 14) {
                Picker("Look", selection: buildFrostedBinding()) {
                    Text("Clear").tag(false)
                    Text("Frosted").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Slider(value: buildDarknessBinding(), in: 0...maxGlassDarkness) {
                    Text("Darkness")
                } minimumValueLabel: {
                    Image(systemName: "sun.max")
                } maximumValueLabel: {
                    Image(systemName: "moon")
                }
                .labelsHidden()
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .frame(width: darknessSliderWidth)
            }
        }
    }

    private func buildFrostedBinding() -> Binding<Bool> {
        return Binding(
            get: { glassStore.isFrosted },
            set: { glassStore.setFrosted($0) }
        )
    }

    private func buildDarknessBinding() -> Binding<CGFloat> {
        return Binding(
            get: { glassStore.darkness },
            set: { glassStore.setDarkness($0) }
        )
    }
}
