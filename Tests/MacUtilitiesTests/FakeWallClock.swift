import Foundation
@testable import MacUtilities

/// A wall clock that only moves when the test advances it, performing the work that falls due.
final class FakeWallClock: WallClock {
    private var currentDate = Date(timeIntervalSinceReferenceDate: 0)
    private var scheduledWork: [(work: DispatchWorkItem, date: Date)] = []

    func now() -> Date {
        return currentDate
    }

    func schedule(_ work: DispatchWorkItem, at date: Date) {
        scheduledWork.append((work, date))
    }

    /// Moves the clock forward and performs the uncancelled work due by then, earliest first.
    func advance(by interval: TimeInterval) {
        currentDate = currentDate.addingTimeInterval(interval)

        let dueWork = scheduledWork.filter { $0.date <= currentDate }.sorted { $0.date < $1.date }
        scheduledWork = scheduledWork.filter { $0.date > currentDate }
        for (work, _) in dueWork where !work.isCancelled {
            work.perform()
        }
    }
}
