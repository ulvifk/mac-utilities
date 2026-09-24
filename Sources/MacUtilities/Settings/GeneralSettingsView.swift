import SwiftUI

/// Feature switches, launch at login and the Accessibility grant.
struct GeneralSettingsView: View {
    @ObservedObject var controller: AppController
    @StateObject private var state = GeneralSettingsState()

    var body: some View {
        Form {
            Section("Features") {
                ForEach(controller.features, id: \.identifier) { feature in
                    Toggle(feature.displayName, isOn: buildEnabledBinding(feature: feature))
                }
            }

            Section {
                LaunchAtLoginToggle(state: state)
                AccessibilityStatusRow(state: state)
            }
        }
        .formStyle(.grouped)
    }

    private func buildEnabledBinding(feature: Feature) -> Binding<Bool> {
        return Binding(
            get: { controller.isFeatureEnabled(feature) },
            set: { controller.setFeatureEnabled(feature, $0) }
        )
    }
}
