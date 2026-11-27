import Foundation
import Testing
@testable import MacUtilities

@MainActor
struct SwitcherSessionTests {
    @Test
    func guardedWorkRunsUntilRenewed() {
        let session = SwitcherSession()
        var runs: [String] = []
        let early = session.guarding { runs.append("early") }
        let earlyWithInput = session.guarding { (value: Int) in runs.append("early \(value)") }

        early()
        earlyWithInput(1)
        session.renew()
        let late = session.guarding { runs.append("late") }
        early()
        earlyWithInput(2)
        late()

        #expect(runs == ["early", "early 1", "late"])
    }

    @Test
    func queuedWorkIsDroppedWhenRenewedBeforeItRuns() async {
        let session = SwitcherSession()
        var runs: [String] = []

        session.runOnNextTurn { runs.append("canceled") }
        session.renew()
        session.runOnNextTurn { runs.append("kept") }
        #expect(runs.isEmpty, "Queued work ran inside the caller")

        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(runs == ["kept"])
    }
}
