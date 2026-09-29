import Foundation

final class Process {
    var executableURL: URL?
    var arguments: [String] = []
    var terminationStatus: Int32 = 0
    var terminationHandler: ((Process) -> Void)?

    func run() throws {}
}

let watchdog = launchLidClosedSleepWatchdog()
print(watchdog.arguments[1])
