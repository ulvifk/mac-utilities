import SwiftUI

/// A feature's pane: its header with the switch that turns it on and off, then the feature's own sections, disabled while it is off. A feature
/// switched off stops on the spot and stays off across launches.
struct FeatureSettingsPane: View {
    @ObservedObject var controller: AppController
    let feature: Feature

    var body: some View {
        Form {
            Section {
                SettingsPaneHeader(title: feature.displayName, subtitle: feature.summary) {
                    SettingsIconTile(symbolName: feature.iconSymbolName, gradient: feature.iconGradient, size: paneHeaderIconSize)
                } accessory: {
                    Toggle(feature.displayName, isOn: buildEnabledBinding())
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            feature.buildSettingsSections()
                .disabled(!controller.isFeatureEnabled(feature))
                .opacity(controller.isFeatureEnabled(feature) ? 1 : switchedOffFeatureOpacity)
        }
        .formStyle(.grouped)
    }

    private func buildEnabledBinding() -> Binding<Bool> {
        return Binding(
            get: { controller.isFeatureEnabled(feature) },
            set: { controller.setFeatureEnabled(feature, $0) }
        )
    }
}
