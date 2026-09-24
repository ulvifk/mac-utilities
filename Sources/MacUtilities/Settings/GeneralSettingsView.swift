import SwiftUI

/// Feature switches, launch at login and the Accessibility grant.
struct GeneralSettingsView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Form {
            Section("Features") {
                ForEach(controller.features, id: \.identifier) { feature in
                    Toggle(feature.displayName, isOn: buildEnabledBinding(feature: feature))
                }
            }

            Section {
                LaunchAtLoginToggle()
                AccessibilityStatusRow()
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
