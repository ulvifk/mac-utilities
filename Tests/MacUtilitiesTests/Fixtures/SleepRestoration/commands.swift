import Foundation

var launchedProcess: Process?

final class Process {
    var executableURL: URL?
    var arguments: [String] = []
    var terminationStatus: Int32 = 0
    var terminationHandler: ((Process) -> Void)?

    func run() throws {
        launchedProcess = self
    }

    func finish(status: Int32) {
        terminationStatus = status
        let handler = terminationHandler!
        DispatchQueue.global().async { handler(self) }
    }
}

func require(_ condition: Bool, _ message: String) {
    if condition { return }
    fatalError(message)
}

@MainActor func waitUntil(_ condition: () -> Bool) async {
    let deadline = Date(timeIntervalSinceNow: 2)
    while !condition() {
        require(Date() < deadline, "Timed out waiting for the main loop")
        try! await Task.sleep(nanoseconds: 1_000_000)
    }
}

Task { @MainActor in
    for disabled in [true, false] {
        launchedProcess = nil
        var didFinish = false
        let command = Task { @MainActor in
            let result = await setLidClosedSleepDisabled(disabled)
            require(Thread.isMainThread, "The command returned off the main thread")
            didFinish = true
            return result
        }
        await waitUntil { launchedProcess != nil }
        let process = launchedProcess!
        require(process.executableURL!.path == "/usr/bin/sudo", "The command changed its executable")
        require(process.arguments == ["-n", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"], "The command changed its arguments")

        var mainQueueProgressed = false
        DispatchQueue.main.async { mainQueueProgressed = true }
        await waitUntil { mainQueueProgressed }
        require(!didFinish, "The power command finished before its process terminated")

        process.finish(status: disabled ? 0 : 1)
        let result = await command.value
        require(result == disabled, "The command ignored its termination status")
    }
    exit(0)
}
RunLoop.main.run()
