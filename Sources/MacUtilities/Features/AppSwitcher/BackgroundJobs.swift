import AppKit

private let launchctlPath = "/bin/launchctl"
private let lsappinfoPath = "/usr/bin/lsappinfo"
private let checkInterval: TimeInterval = 1
private let checkCount = 120

/// Removes the launchd jobs the quit apps submitted themselves, such as Squirrel's ShipIt or Sparkle's updater. macOS keeps an
/// exited app that still owns such a job in the Dock as running in the background, with Stop Running in Background in its menu.
/// That Dock item removes the same jobs and kills the running ones; this waits instead, so an update that starts installing right
/// after the quit finishes first:
/// - once a second on a background queue, an app is handled once it has exited, and each of its jobs once it is not running
/// - gives up after two minutes, leaving an app still open at its unsaved-changes dialog, or a job that keeps running, as it is
func removeBackgroundJobs(of apps: [NSRunningApplication]) {
    let processIdentifiers = apps.map { $0.processIdentifier }

    DispatchQueue.global(qos: .utility).async {
        var waitingProcessIdentifiers = processIdentifiers
        for _ in 0..<checkCount {
            Thread.sleep(forTimeInterval: checkInterval)
            waitingProcessIdentifiers = removeStoppedJobs(of: waitingProcessIdentifiers)
            if waitingProcessIdentifiers.isEmpty { return }
        }
    }
}

/// Removes the jobs of the exited apps that are not running. Returns the apps to check again: the ones still running, and the ones
/// with a job still running.
private func removeStoppedJobs(of processIdentifiers: [pid_t]) -> [pid_t] {
    let runningJobLabels = getRunningJobLabels()
    var waitingProcessIdentifiers: [pid_t] = []

    for processIdentifier in processIdentifiers {
        if isProcessRunning(processIdentifier) {
            waitingProcessIdentifiers.append(processIdentifier)
            continue
        }

        let jobLabels = getSubmittedJobLabels(of: processIdentifier)
        for label in jobLabels where !runningJobLabels.contains(label) {
            runTool(launchctlPath, ["remove", label])
        }
        if jobLabels.contains(where: runningJobLabels.contains) { waitingProcessIdentifiers.append(processIdentifier) }
    }

    return waitingProcessIdentifiers
}

private func isProcessRunning(_ processIdentifier: pid_t) -> Bool {
    return kill(processIdentifier, 0) == 0
}

/// The jobs LaunchServices counts as the app's own, the ones it submitted, read from lsappinfo's loadedJobs line:
/// `    loadedJobs:"notion.id.ShipIt" "other.job"` -> ["notion.id.ShipIt", "other.job"]. Empty once LaunchServices has let the
/// exited app go, which it does when the app owned no job.
private func getSubmittedJobLabels(of processIdentifier: pid_t) -> [String] {
    let output = runTool(lsappinfoPath, ["info", "-only", "loadedJobs", String(processIdentifier)])
    guard let line = output.split(separator: "\n").first(where: { $0.contains("loadedJobs:") }) else { return [] }

    let quotedParts = line.split(separator: "\"", omittingEmptySubsequences: false)
    return stride(from: 1, to: quotedParts.count, by: 2).map { String(quotedParts[$0]) }
}

/// The labels of the user's launchd jobs that have a process, from launchctl list's "PID Status Label" rows, where a job
/// without a process shows "-" as its PID.
private func getRunningJobLabels() -> Set<String> {
    var labels = Set<String>()

    for row in runTool(launchctlPath, ["list"]).split(separator: "\n").dropFirst() {
        let columns = row.split(separator: "\t")
        if columns[0] == "-" { continue }
        labels.insert(String(columns[2]))
    }

    return labels
}

/// Waits for the tool to exit and returns what it wrote to standard output.
@discardableResult
private func runTool(_ path: String, _ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output

    try! process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    return String(decoding: data, as: UTF8.self)
}
