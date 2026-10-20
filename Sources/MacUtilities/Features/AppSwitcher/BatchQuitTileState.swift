import Combine
import Foundation

/// How many apps the Batch Quit tile's latest run asked to quit, for a moment after it ran; nil otherwise.
/// A class held as a state object, since the command-line toolchain has no plugin for the @State macro.
final class BatchQuitTileState: ObservableObject {
    @Published private(set) var quitCount: Int?
    private var quitCountHiding: DispatchWorkItem?

    /// Replaces the count still shown, and is taken away after feedbackDuration.
    func showQuitCount(_ quitCount: Int) {
        quitCountHiding?.cancel()

        self.quitCount = quitCount
        quitCountHiding = DispatchWorkItem { self.quitCount = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration, execute: quitCountHiding!)
    }
}
