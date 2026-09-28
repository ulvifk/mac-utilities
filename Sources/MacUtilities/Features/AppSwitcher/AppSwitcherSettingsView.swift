import SwiftUI

/// [shortcut while the switcher is open] -> what it does
private let switcherShortcuts: [(String, String)] = [
    ("Cmd+Tab / Cmd+Shift+Tab", "Cycle forward / backward"),
    ("Cmd+` / Cmd+Shift+`", "Cycle the current app's windows"),
    ("Right / Left", "Cycle forward / backward"),
    ("Up / Down", "Move one row up / down"),
    ("Cmd+F", "Toggle the filter"),
    ("Cmd+W", "Toggle the selected app's whitelist membership"),
    ("Cmd+Q", "Quit the selected app"),
    ("Cmd+X", "Quit every app not in the whitelist"),
    ("Cmd+H", "Hide the selected app"),
    ("Esc", "Close without switching"),
]

/// The filter switch, the panel's glass for apps and for windows, the window cards and their glass, the whitelist (every running regular app,
/// switch = whitelisted) and the in-switcher shortcuts.
struct AppSwitcherSettingsView: View {
    @ObservedObject var whitelistStore: WhitelistStore
    let appGlassStore: GlassStore
    let windowGlassStore: GlassStore
    @ObservedObject var windowCardStore: WindowCardStore
    let windowCardGlassStore: GlassStore
    @StateObject private var runningApps = RunningRegularApps()

    var body: some View {
        Form {
            Section {
                Toggle("Filter to the whitelist", isOn: buildFilterBinding())
                Button("Quit apps not in the whitelist") { quitRegularAppsNotIn(whitelist: whitelistStore.getWhitelist()) }
            }

            Section("Apps (Cmd+Tab)") {
                GlassSettingsRows(glassStore: appGlassStore)
            }

            Section("Windows (Cmd+`)") {
                GlassSettingsRows(glassStore: windowGlassStore)
            }

            Section("Window cards") {
                Toggle("Cards around windows", isOn: buildWindowCardsBinding())
                GlassSettingsRows(glassStore: windowCardGlassStore)
                    .disabled(!windowCardStore.showsCards)
            }

            Section("Whitelist") {
                ForEach(runningApps.apps, id: \.processIdentifier) { app in
                    Toggle(isOn: buildWhitelistedBinding(bundleIdentifier: app.bundleIdentifier!)) {
                        HStack(spacing: 8) {
                            Image(nsImage: app.icon!)
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(getAppName(app))
                        }
                    }
                }
            }

            Section("While switching") {
                ForEach(switcherShortcuts, id: \.0) { shortcut, meaning in
                    LabeledContent(meaning, value: shortcut)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func buildFilterBinding() -> Binding<Bool> {
        return Binding(
            get: { whitelistStore.isFilterEnabled },
            set: { whitelistStore.setFilterEnabled($0) }
        )
    }

    private func buildWindowCardsBinding() -> Binding<Bool> {
        return Binding(
            get: { windowCardStore.showsCards },
            set: { windowCardStore.setShowsCards($0) }
        )
    }

    private func buildWhitelistedBinding(bundleIdentifier: String) -> Binding<Bool> {
        return Binding(
            get: { whitelistStore.isWhitelisted(bundleIdentifier) },
            set: { whitelistStore.setWhitelisted(bundleIdentifier, $0) }
        )
    }
}
