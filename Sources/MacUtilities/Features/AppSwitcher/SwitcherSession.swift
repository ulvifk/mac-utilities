import Foundation

/// Cancels queued work: work wrapped by the session does nothing once the session has been renewed after the wrapping. The switcher queues
/// most of its work, since the event tap callback must never do any, and renews a session wherever that work would act on a panel or a
/// feature state that is gone.
final class SwitcherSession {
    private var generation = 0

    /// Cancels the work wrapped so far.
    func renew() {
        generation += 1
    }

    func guarding(_ work: @escaping () -> Void) -> () -> Void {
        let wrappedGeneration = generation
        return {
            if self.generation != wrappedGeneration { return }

            work()
        }
    }

    func guarding<Input>(_ work: @escaping (Input) -> Void) -> (Input) -> Void {
        let wrappedGeneration = generation
        return { input in
            if self.generation != wrappedGeneration { return }

            work(input)
        }
    }

    /// On the next turn of the main queue, unless the session is renewed before.
    func runOnNextTurn(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: guarding(work))
    }
}
