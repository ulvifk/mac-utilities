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
    ("Cmd+Shift+Q", "Batch quit: the listed apps, or the unlisted ones"),
    ("Cmd+H", "Hide the selected app"),
    ("Esc", "Close without switching"),
]

/// The filter switch and the whitelist, the panel's glass for apps and for windows, the window cards and their glass, Batch Quit (whether it
/// quits the listed apps or the others, and its list) and the in-switcher shortcuts. Both lists are picked in a popover checklist.
struct AppSwitcherSettingsView: View {
    @ObservedObject var whitelistStore: WhitelistStore
    @ObservedObject var batchQuitStore: BatchQuitStore
    let appGlassStore: GlassStore
    let windowGlassStore: GlassStore
    @ObservedObject var windowCardStore: WindowCardStore
    let windowCardGlassStore: GlassStore
    @StateObject private var runningApps = RunningRegularApps()

    var body: some View {
        Section("Whitelist") {
            Toggle("Filter to the whitelist", isOn: buildFilterBinding())
            LabeledContent("Whitelisted apps") {
                AppListPicker(store: whitelistStore, apps: runningApps.apps)
            }
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

        Section("Batch Quit") {
            Picker("Quit", selection: buildQuitsUnlistedAppsBinding()) {
                Text("Listed apps").tag(false)
                Text("Unlisted apps").tag(true)
            }
            .pickerStyle(.segmented)
            LabeledContent(batchQuitStore.quitsUnlistedApps ? "Apps to keep" : "Apps to quit") {
                AppListPicker(store: batchQuitStore, apps: runningApps.apps.filter(isBatchQuittable))
            }
            Button(batchQuitStore.quitsUnlistedApps ? "Quit unlisted apps" : "Quit listed apps") { runBatchQuit(batchQuitStore) }
        }

        Section("While switching") {
            ForEach(switcherShortcuts, id: \.0) { shortcut, meaning in
                LabeledContent(meaning, value: shortcut)
            }
        }
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

    private func buildQuitsUnlistedAppsBinding() -> Binding<Bool> {
        return Binding(
            get: { batchQuitStore.quitsUnlistedApps },
            set: { batchQuitStore.setQuitsUnlistedApps($0) }
        )
    }
}
