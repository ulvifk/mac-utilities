import SwiftUI

/// One list's glass, as rows of the section they are placed in: Clear or Frosted, and the darkness of its tint.
struct GlassSettingsRows: View {
    @ObservedObject var glassStore: GlassStore

    var body: some View {
        Picker("Look", selection: buildFrostedBinding()) {
            Text("Clear").tag(false)
            Text("Frosted").tag(true)
        }
        .pickerStyle(.segmented)
        Slider(value: buildDarknessBinding(), in: 0...maxGlassDarkness) {
            Text("Darkness")
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
