import Combine
import Foundation

/// The Batch Quit tile's feedback: what the latest run did, said for a moment in place of the tile's subtitle.
/// A class held as a state object, since the command-line toolchain has no plugin for the @State macro.
final class BatchQuitTileState: ObservableObject {
    @Published private(set) var feedback: SwitcherFeedback?
    private var feedbackHiding: DispatchWorkItem?

    /// Replaces the feedback still shown, and is taken away after feedbackDuration.
    func showFeedback(_ feedback: SwitcherFeedback) {
        feedbackHiding?.cancel()

        self.feedback = feedback
        feedbackHiding = DispatchWorkItem { self.feedback = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration, execute: feedbackHiding!)
    }
}
