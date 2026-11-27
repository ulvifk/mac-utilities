import AppKit

/// Builds the App Switcher feature with the parts it reaches the system through.
struct AppSwitcherFeatureFactory {
    /// With APP_SWITCHER_SMOKE_TEST in the environment the feature runs the smoke test when it starts.
    func buildFeature(settings: SwitcherSettings, workspace: SwitcherWorkspace, screen: SwitcherScreen, panel: SwitcherPanel, previewPanel: SwitcherPanel,
                      environment: [String: String]) -> AppSwitcherFeature {
        let listLoader = SwitcherListLoader(workspace: workspace, screen: screen, whitelistStore: settings.whitelistStore, panelWidthStore: settings.panelWidthStore)
        let smokeTest = environment["APP_SWITCHER_SMOKE_TEST"] == nil ? nil : AppSwitcherSmokeTest(
            panel: GlassSwitcherPanel(), settings: settings, listLoader: listLoader, workspace: workspace, screen: screen, environment: environment
        )

        return AppSwitcherFeature(
            workspace: workspace,
            screen: screen,
            settings: settings,
            listLoader: listLoader,
            panel: panel,
            previewPanel: previewPanel,
            smokeTest: smokeTest
        )
    }

    /// On the system: the settings in the standard defaults, the preview's clicks passing through to the settings pane.
    func buildFeature() -> AppSwitcherFeature {
        let settings = buildSettings(defaults: .standard)
        let previewPanel = GlassSwitcherPanel()
        previewPanel.ignoresMouseEvents = true

        return buildFeature(
            settings: settings,
            workspace: SystemSwitcherWorkspace(batchQuitStore: settings.batchQuitStore),
            screen: SystemSwitcherScreen(),
            panel: GlassSwitcherPanel(),
            previewPanel: previewPanel,
            environment: ProcessInfo.processInfo.environment
        )
    }

    func buildSettings(defaults: UserDefaults) -> SwitcherSettings {
        return SwitcherSettings(
            whitelistStore: WhitelistStore(defaults: defaults),
            batchQuitStore: BatchQuitStore(defaults: defaults),
            appearanceStore: SwitcherAppearanceStore(defaults: defaults),
            appGlassStore: GlassStore(keyPrefix: "appGlass", defaultDarkness: defaultGlassDarkness, defaults: defaults),
            windowGlassStore: GlassStore(keyPrefix: "windowGlass", defaultDarkness: defaultGlassDarkness, defaults: defaults),
            appCardStore: SwitcherCardStore(key: "appCards", defaults: defaults),
            appCardGlassStore: GlassStore(keyPrefix: "appCardGlass", defaultDarkness: defaultCardDarkness, defaults: defaults),
            windowCardStore: SwitcherCardStore(key: "windowCards", defaults: defaults),
            windowCardGlassStore: GlassStore(keyPrefix: "windowCardGlass", defaultDarkness: defaultCardDarkness, defaults: defaults),
            panelWidthStore: PanelWidthStore(defaults: defaults),
            previewStore: SwitcherPreviewStore()
        )
    }
}
