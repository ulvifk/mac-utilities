import AppKit

/// The switcher's settings: the ones its settings pane edits, the transient preview checkbox among them, and the dragged panel width.
struct SwitcherSettings {
    let whitelistStore: WhitelistStore
    let batchQuitStore: BatchQuitStore
    let appearanceStore: SwitcherAppearanceStore
    let dockBadgeStore: DockBadgeStore
    let appGlassStore: GlassStore
    let windowGlassStore: GlassStore
    let appCardStore: SwitcherCardStore
    let appCardGlassStore: GlassStore
    let windowCardStore: SwitcherCardStore
    let windowCardGlassStore: GlassStore
    let panelWidthStore: PanelWidthStore
    let previewStore: SwitcherPreviewStore

    /// The glass of the panel listing apps or windows.
    func getGlassStore(listingWindows: Bool) -> GlassStore {
        if listingWindows { return windowGlassStore }
        return appGlassStore
    }

    /// The list's look as set now.
    func buildState(list: SwitcherList, thumbnails: [CGWindowID: NSImage]) -> SwitcherState {
        return SwitcherState(
            list: list,
            thumbnails: thumbnails,
            cardGlass: getCardGlass(listingWindows: list.isListingWindows),
            isFilterEnabled: whitelistStore.isFilterEnabled,
            dimHiddenApps: appearanceStore.dimHiddenApps,
            whitelisted: whitelistStore.getWhitelist()
        )
    }

    /// Nil while the list's cards are switched off.
    private func getCardGlass(listingWindows: Bool) -> GlassStore? {
        let cardStore = listingWindows ? windowCardStore : appCardStore
        if !cardStore.showsCards { return nil }

        return listingWindows ? windowCardGlassStore : appCardGlassStore
    }
}
