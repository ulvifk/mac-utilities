import SwiftUI

private let batchQuitTint = Color.red

/// Runs Batch Quit from the menu bar popover. For a moment after each run the subtitle says how many apps were asked to quit, worded as the
/// switcher's ⇧⌘Q says it in its hint band, and the round button fills while some were.
struct BatchQuitTile: View {
    @ObservedObject var batchQuitStore: BatchQuitStore
    @StateObject private var state = BatchQuitTileState()

    var body: some View {
        PopoverTile {
            PopoverRoundButtonRow(
                title: batchQuitStore.quitsUnlistedApps ? "Quit Unlisted Apps" : "Quit Listed Apps",
                subtitle: buildSubtitle(),
                symbolName: "xmark",
                tint: batchQuitTint,
                isFilled: isQuittingApps(),
                action: quit
            )
        }
    }

    private func buildSubtitle() -> Text {
        if let quitCount = state.quitCount { return Text(SwitcherFeedback.quittingApps(count: quitCount).text) }
        if batchQuitStore.quitsUnlistedApps { return Text("Keeps the apps on the Batch Quit list") }

        return Text("Quits the apps on the Batch Quit list")
    }

    private func isQuittingApps() -> Bool {
        guard let quitCount = state.quitCount else { return false }

        return quitCount > 0
    }

    private func quit() {
        let quitCount = runBatchQuit(batchQuitStore)
        state.showQuitCount(quitCount)
    }
}
