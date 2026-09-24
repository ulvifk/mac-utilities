import SwiftUI

let generalTabIdentifier = "general"

/// The General tab followed by one tab per feature.
struct SettingsView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        TabView(selection: $controller.selectedSettingsTabIdentifier) {
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
