import SwiftUI

let generalTabIdentifier = "general"
/// The tab shown last time, so the window reopens on it.
let selectedSettingsTabKey = "selectedSettingsTab"

/// The General tab followed by one tab per feature.
struct SettingsView: View {
    @ObservedObject var controller: AppController
    @AppStorage(selectedSettingsTabKey) private var selectedTabIdentifier = generalTabIdentifier

    var body: some View {
        TabView(selection: $selectedTabIdentifier) {
            GeneralSettingsView(controller: controller)
                .tabItem { Text("General") }
                .tag(generalTabIdentifier)

            ForEach(controller.features, id: \.identifier) { feature in
                feature.buildSettingsView()
                    .tabItem { Text(feature.displayName) }
                    .tag(feature.identifier)
            }
        }
        .frame(width: 520, height: 460)
    }
}
