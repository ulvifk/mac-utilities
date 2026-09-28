import SwiftUI

/// The app's card with how many features are on, launch at login and the Accessibility grant; the last two are re-read whenever the window
/// comes back to the front.
struct GeneralSettingsView: View {
    @ObservedObject var controller: AppController
    let showPane: (String) -> Void
    @StateObject private var state = GeneralSettingsState()

    var body: some View {
        Form {
            Section {
                SettingsPaneHeader(title: "MacUtilities", subtitle: getFeatureCountSummary()) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: paneHeaderAppIconSize, height: paneHeaderAppIconSize)
                } accessory: {
                    featureTiles
                }
            }

            Section {
                LaunchAtLoginToggle(state: state)
                AccessibilityStatusRow(state: state)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            state.refresh()
        }
    }

    /// Each feature's tile, faded while it is off; a click opens its pane.
    private var featureTiles: some View {
        HStack(spacing: 6) {
            ForEach(controller.features, id: \.identifier) { feature in
                Button { showPane(feature.identifier) } label: {
                    SettingsIconTile(symbolName: feature.iconSymbolName, gradient: feature.iconGradient, size: smallIconTileSize)
                        .saturation(controller.isFeatureEnabled(feature) ? 1 : 0)
                        .opacity(controller.isFeatureEnabled(feature) ? 1 : switchedOffFeatureOpacity)
                }
                .buttonStyle(.plain)
                .help(feature.displayName)
                .accessibilityLabel(feature.displayName)
                .accessibilityValue(controller.isFeatureEnabled(feature) ? "On" : "Off")
            }
        }
    }

    private func getFeatureCountSummary() -> String {
        return "\(controller.enabledFeatures.count) of \(controller.features.count) features on"
    }
}
