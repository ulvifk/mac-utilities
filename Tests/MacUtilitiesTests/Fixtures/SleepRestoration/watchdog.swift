import Foundation

final class Process {
    var executableURL: URL?
    var arguments: [String] = []
    var terminationStatus: Int32 = 0

    func run() throws {}
    func waitUntilExit() {}
}

let watchdog = launchLidClosedSleepWatchdog()
print(watchdog.arguments[1])
