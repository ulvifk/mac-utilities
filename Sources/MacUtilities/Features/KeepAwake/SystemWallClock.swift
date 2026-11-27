import Foundation

final class SystemWallClock: WallClock {
    func now() -> Date {
        return Date()
    }

    /// A wall deadline, unlike a plain one, keeps counting while the Mac sleeps, so a Mac that slept past the date performs the work on waking.
    func schedule(_ work: DispatchWorkItem, at date: Date) {
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + date.timeIntervalSinceNow, execute: work)
    }
}
