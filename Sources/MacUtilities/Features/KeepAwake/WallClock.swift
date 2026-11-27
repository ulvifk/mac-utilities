import Foundation

/// The wall clock Keep Awake's deadlines run on, so time the Mac spends asleep counts toward them.
protocol WallClock {
    func now() -> Date
    /// Performs work on the main queue once the wall clock reaches date, unless it is cancelled first.
    func schedule(_ work: DispatchWorkItem, at date: Date)
}
