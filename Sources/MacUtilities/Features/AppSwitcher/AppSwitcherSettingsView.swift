import SwiftUI

/// [what it does] -> the keys that do it while the switcher is open, one keycap group per alternative
private let switchingShortcuts: [(String, [[String]])] = [
    ("Next or previous app", [["⌘", "⇥"], ["⇧", "⌘", "⇥"]]),
    ("Next or previous window of the app", [["⌘", "`"], ["⇧", "⌘", "`"]]),
    ("Move the selection", [["←", "→", "↑", "↓"]]),
    ("Close without switching", [["esc"]]),
]

/// [what it does] -> the keys that do it while apps are listed
private let appShortcuts: [(String, [[String]])] = [
    ("Turn the filter on or off", [["⌘", "F"]]),
    ("Whitelist the selected app, or take it off", [["⌘", "W"]]),
    ("Hide the selected app", [["⌘", "H"]]),
    ("Quit the selected app", [["⌘", "Q"]]),
    ("Batch Quit", [["⇧", "⌘", "Q"]]),
]

/// Settings for filtering, glass, app and window cards, Dock badges, Batch Quit, and shortcuts.
struct AppSwitcherSettingsView: View {
    @ObservedObject private var whitelistStore: WhitelistStore
    @ObservedObject private var batchQuitStore: BatchQuitStore
    @ObservedObject private var appearanceStore: SwitcherAppearanceStore
    @ObservedObject private var dockBadgeStore: DockBadgeStore
    private let appGlassStore: GlassStore
    private let windowGlassStore: GlassStore
    @ObservedObject private var appCardStore: SwitcherCardStore
    private let appCardGlassStore: GlassStore
    @ObservedObject private var windowCardStore: SwitcherCardStore
    private let windowCardGlassStore: GlassStore
    @ObservedObject private var previewStore: SwitcherPreviewStore
    @StateObject private var runningApps = RunningRegularApps()

    /// Observes each store the sections read, so they follow changes made with the in-switcher shortcuts too.
    init(settings: SwitcherSettings) {
        whitelistStore = settings.whitelistStore
        batchQuitStore = settings.batchQuitStore
        appearanceStore = settings.appearanceStore
        dockBadgeStore = settings.dockBadgeStore
        appGlassStore = settings.appGlassStore
        windowGlassStore = settings.windowGlassStore
        appCardStore = settings.appCardStore
        appCardGlassStore = settings.appCardGlassStore
        windowCardStore = settings.windowCardStore
        windowCardGlassStore = settings.windowCardGlassStore
        previewStore = settings.previewStore
    }

    var body: some View {
        Section {
            Toggle("Filter to the whitelist", isOn: buildFilterBinding())
            LabeledContent("Whitelisted apps") {
                AppListPicker(store: whitelistStore, apps: runningApps.apps)
            }
        } header: {
            Text("Whitelist")
        } footer: {
            Text("Filtered, the switcher lists only whitelisted apps, or every app while none of them is running.")
        }

        Section {
            Toggle("Dim hidden apps", isOn: buildDimHiddenAppsBinding())
            Toggle("Show Dock badges", isOn: buildDockBadgesBinding())
            Toggle("Show preview", isOn: $previewStore.isShown)
                .toggleStyle(.checkbox)
            Picker("Preview", selection: $previewStore.isListingWindows) {
                Text("Apps").tag(false)
                Text("Windows").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(!previewStore.isShown)
            GlassSettingsRow(title: "Apps", glassStore: appGlassStore)
            GlassSettingsRow(title: "Windows", glassStore: windowGlassStore)
            Toggle("Cards around apps", isOn: buildCardsBinding(appCardStore))
            GlassSettingsRow(title: "App cards", glassStore: appCardGlassStore)
                .disabled(!appCardStore.showsCards)
            Toggle("Cards around windows", isOn: buildCardsBinding(windowCardStore))
            GlassSettingsRow(title: "Window cards", glassStore: windowCardGlassStore)
                .disabled(!windowCardStore.showsCards)
        } header: {
            Text("Glass")
        } footer: {
            Text("Clear shows what is behind the panel, Frosted blurs it away; the slider darkens the tint. Dock badges show the count an app's Dock icon shows, read when the switcher opens. Show preview shows the full switcher while this pane has focus.")
        }

        Section {
            Picker("Quit", selection: buildQuitsUnlistedAppsBinding()) {
                Text("Listed apps").tag(false)
                Text("Unlisted apps").tag(true)
            }
            .pickerStyle(.segmented)
            LabeledContent(batchQuitStore.quitsUnlistedApps ? "Apps to keep" : "Apps to quit") {
                AppListPicker(store: batchQuitStore, apps: runningApps.apps.filter(isBatchQuittable))
            }
            LabeledContent("Quit them now") {
                Button(batchQuitStore.quitsUnlistedApps ? "Quit Unlisted Apps" : "Quit Listed Apps") { runBatchQuit(batchQuitStore) }
            }
        } header: {
            Text("Batch Quit")
        } footer: {
            Text("Finder is never quit, and an app with unsaved changes asks first.")
        }

        Section {
            ForEach(switchingShortcuts, id: \.0) { meaning, keyGroups in
                buildShortcutRow(meaning: meaning, keyGroups: keyGroups)
            }
        } header: {
            Text("Switching")
        } footer: {
            Text("Keep ⌘ held while switching; letting go switches to the selection.")
        }

        Section {
            ForEach(appShortcuts, id: \.0) { meaning, keyGroups in
                buildShortcutRow(meaning: meaning, keyGroups: keyGroups)
            }
        } header: {
            Text("App Actions")
        } footer: {
            Text("Only while apps are listed; while windows are, these keys do nothing.")
        }
    }

    /// Alternatives are split by a slash: ⌘⇥ / ⇧⌘⇥.
    private func buildShortcutRow(meaning: String, keyGroups: [[String]]) -> some View {
        return LabeledContent(meaning) {
            HStack(spacing: 6) {
                ForEach(keyGroups.indices, id: \.self) { index in
                    if index > 0 {
                        Text("/")
                            .foregroundStyle(.tertiary)
                    }
                    KeycapsView(keys: keyGroups[index])
                }
            }
        }
    }

    private func buildFilterBinding() -> Binding<Bool> {
        return Binding(
            get: { whitelistStore.isFilterEnabled },
            set: { whitelistStore.setFilterEnabled($0) }
        )
    }

    private func buildCardsBinding(_ store: SwitcherCardStore) -> Binding<Bool> {
        return Binding(
            get: { store.showsCards },
            set: { store.setShowsCards($0) }
        )
    }

    private func buildDimHiddenAppsBinding() -> Binding<Bool> {
        return Binding(
            get: { appearanceStore.dimHiddenApps },
            set: { appearanceStore.setDimHiddenApps($0) }
        )
    }

    private func buildDockBadgesBinding() -> Binding<Bool> {
        return Binding(
            get: { dockBadgeStore.showsBadges },
            set: { dockBadgeStore.setShowsBadges($0) }
        )
    }

    private func buildQuitsUnlistedAppsBinding() -> Binding<Bool> {
        return Binding(
            get: { batchQuitStore.quitsUnlistedApps },
            set: { batchQuitStore.setQuitsUnlistedApps($0) }
        )
    }
}
