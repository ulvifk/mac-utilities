import SwiftUI

private let batchQuitTint = Color.red

/// Runs Batch Quit from the menu bar popover. For a moment after each run the round toggle fills and the subtitle says how many apps were asked
/// to quit, worded as the switcher's ⇧⌘Q says it in its hint band.
struct BatchQuitTile: View {
    @ObservedObject var batchQuitStore: BatchQuitStore
    @StateObject private var state = BatchQuitTileState()

    var body: some View {
        PopoverTile {
            PopoverToggleRow(
                title: batchQuitStore.quitsUnlistedApps ? "Quit Unlisted Apps" : "Quit Listed Apps",
                subtitle: buildSubtitle(),
                symbolName: "xmark",
                tint: batchQuitTint,
                isOn: state.feedback != nil,
                toggle: quit
            )
        }
    }

    private func buildSubtitle() -> Text {
        if let feedback = state.feedback { return Text(feedback.text) }
        if batchQuitStore.quitsUnlistedApps { return Text("Keeps the apps on the Batch Quit list") }

        return Text("Quits the apps on the Batch Quit list")
    }

    private func quit() {
        let quitCount = runBatchQuit(batchQuitStore)
        state.showFeedback(.quittingApps(count: quitCount))
    }
}
