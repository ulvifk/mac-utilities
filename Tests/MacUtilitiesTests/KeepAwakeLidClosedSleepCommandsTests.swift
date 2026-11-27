import Foundation
import Testing
@testable import MacUtilities

/// The processes SystemPowerManagement launches, inspected or run without sudo or pmset.
struct KeepAwakeLidClosedSleepCommandsTests {
    @Test(arguments: [true, false])
    func lidClosedSleepCommandRunsPmsetThroughSudo(disabled: Bool) {
        let command = buildLidClosedSleepCommand(disabled: disabled)

        #expect(command.executableURL?.path == "/usr/bin/sudo", "The command changed its executable")
        #expect(command.arguments == ["-n", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"], "The command changed its arguments")
    }

    /// The process exits with the status written to its standard input, so the test decides when it terminates.
    @Test(arguments: [Int32(0), Int32(1)]) @MainActor
    func runProcessLeavesTheMainLoopResponsiveUntilTheProcessExits(exitStatus: Int32) async throws {
        let process = Process()
        let input = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "read status; exit $status"]
        process.standardInput = input
        defer { try! input.fileHandleForWriting.close() }

        var didFinish = false
        let command = Task { @MainActor in
            let status = await runProcess(process)
            dispatchPrecondition(condition: .onQueue(.main)) // the command must return on the main thread
            didFinish = true
            return status
        }
        while !process.isRunning { await Task.yield() }

        var mainQueueProgressed = false
        DispatchQueue.main.async { mainQueueProgressed = true }
        while !mainQueueProgressed { try await Task.sleep(nanoseconds: 1_000_000) }
        #expect(!didFinish, "The power command finished before its process terminated")

        input.fileHandleForWriting.write("\(exitStatus)\n".data(using: .utf8)!)
        #expect(await command.value == exitStatus, "The command ignored its termination status")
    }

    /// Runs the watchdog's own process against an app that has already exited, with a sudo that fails twice before succeeding.
    @Test
    func watchdogRetriesAfterTheAppExitsUntilRestoreSucceeds() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: directory) }

        let attemptsFile = directory.appendingPathComponent("restore-attempts")
        try writeExecutable("""
        #!/bin/sh
        printf '%s\\n' "$*" >> "$RESTORE_ATTEMPTS"
        attempts=$(wc -l < "$RESTORE_ATTEMPTS")
        test "$attempts" -ge 3
        """, to: directory.appendingPathComponent("sudo"))
        try writeExecutable("#!/bin/sh\nexec /bin/sleep 0.02\n", to: directory.appendingPathComponent("sleep"))

        let exitedApp = Process()
        exitedApp.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try exitedApp.run()
        exitedApp.waitUntilExit()

        let watchdog = buildLidClosedSleepWatchdog(watching: exitedApp.processIdentifier)
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = directory.path + ":/usr/bin:/bin"
        environment["RESTORE_ATTEMPTS"] = attemptsFile.path
        watchdog.environment = environment
        try watchdog.run()
        watchdog.waitUntilExit()

        #expect(watchdog.terminationStatus == 0)
        let attempts = try String(contentsOf: attemptsFile, encoding: .utf8).split(separator: "\n")
        #expect(attempts.count == 3)
        #expect(attempts.allSatisfy { $0 == "-n /usr/bin/pmset -a disablesleep 0" })
    }

    private func writeExecutable(_ script: String, to file: URL) throws {
        try script.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }
}
