import Foundation
import Testing

@Suite(.serialized)
struct KeepAwakeRestorationTests {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let fixtures = repository.appendingPathComponent("Tests/MacUtilitiesTests/Fixtures/SleepRestoration")
    private static let sources = repository.appendingPathComponent("Sources/MacUtilities")

    @Test
    func sessionAndFeatureKeepFailedCleanupUntilRestorationSucceeds() throws {
        let directory = try Self.createTemporaryDirectory()
        defer { try! FileManager.default.removeItem(at: directory) }

        let harness = directory.appendingPathComponent("session-harness")
        let compilation = try Self.runProcess("/usr/bin/xcrun", arguments: [
            "swiftc", Self.fixtures.appendingPathComponent("main.swift").path,
            Self.sources.appendingPathComponent("Core/Feature.swift").path,
            Self.sources.appendingPathComponent("Features/KeepAwake/KeepAwakeSession.swift").path,
            Self.sources.appendingPathComponent("Features/KeepAwake/KeepAwakeFeature.swift").path,
            "-o", harness.path
        ])
        try #require(compilation.status == 0, "\(compilation.output)")

        let scenarios = [
            "session-retry", "idle-sleep", "activation-refusal", "toggle-retry",
            "replacement-refusal", "stop-retry", "timer-retry", "pending-activation-stop",
            "rapid-toggles", "rapid-duration-replacement", "termination",
            "termination-refusal", "termination-restoring"
        ]
        for scenario in scenarios {
            let result = try Self.runProcess(harness.path, arguments: [scenario])
            #expect(result.status == 0, "\(scenario): \(result.output)")
        }
    }

    @Test
    func powerCommandsLeaveTheMainLoopResponsiveUntilProcessTermination() throws {
        let directory = try Self.createTemporaryDirectory()
        defer { try! FileManager.default.removeItem(at: directory) }

        let harness = directory.appendingPathComponent("commands-harness")
        let main = directory.appendingPathComponent("main.swift")
        try FileManager.default.copyItem(at: Self.fixtures.appendingPathComponent("commands.swift"), to: main)
        let compilation = try Self.runProcess("/usr/bin/xcrun", arguments: [
            "swiftc", main.path,
            Self.sources.appendingPathComponent("Features/KeepAwake/LidClosedSleep.swift").path,
            "-o", harness.path
        ])
        try #require(compilation.status == 0, "\(compilation.output)")

        let result = try Self.runProcess(harness.path, arguments: [])
        #expect(result.status == 0, "\(result.output)")
    }

    @Test
    func appKitTerminationFinishesCleanupFromQueuedAndNativeRequests() throws {
        let directory = try Self.createTemporaryDirectory()
        defer { try! FileManager.default.removeItem(at: directory) }

        let harness = directory.appendingPathComponent("termination-harness")
        let main = directory.appendingPathComponent("main.swift")
        try FileManager.default.copyItem(at: Self.fixtures.appendingPathComponent("termination.swift"), to: main)
        let compilation = try Self.runProcess("/usr/bin/xcrun", arguments: [
            "swiftc", main.path,
            Self.sources.appendingPathComponent("Core/AppController.swift").path,
            Self.sources.appendingPathComponent("Core/ApplicationTermination.swift").path,
            Self.sources.appendingPathComponent("Core/Feature.swift").path,
            "-o", harness.path
        ])
        try #require(compilation.status == 0, "\(compilation.output)")

        for context in ["dispatch", "task", "native"] {
            let result = try Self.runProcess(harness.path, arguments: [context])
            #expect(result.status == 0, "\(context): \(result.output)")
            #expect(result.output.components(separatedBy: "PASS \(context)").count == 2, "\(result.output)")
        }
    }

    @Test
    func watchdogRetriesAfterParentExitUntilRestoreSucceeds() throws {
        let directory = try Self.createTemporaryDirectory()
        defer { try! FileManager.default.removeItem(at: directory) }

        let harness = directory.appendingPathComponent("watchdog-harness")
        let main = directory.appendingPathComponent("main.swift")
        try FileManager.default.copyItem(at: Self.fixtures.appendingPathComponent("watchdog.swift"), to: main)
        let compilation = try Self.runProcess("/usr/bin/xcrun", arguments: [
            "swiftc", main.path,
            Self.sources.appendingPathComponent("Features/KeepAwake/LidClosedSleep.swift").path,
            "-o", harness.path
        ])
        try #require(compilation.status == 0, "\(compilation.output)")
        let capture = try Self.runProcess(harness.path, arguments: [])
        try #require(capture.status == 0, "\(capture.output)")

        let counter = directory.appendingPathComponent("restore-attempts")
        let sudo = directory.appendingPathComponent("sudo")
        try """
        #!/bin/sh
        printf '%s\\n' "$*" >> "$RESTORE_ATTEMPTS"
        attempts=$(wc -l < "$RESTORE_ATTEMPTS")
        test "$attempts" -ge 3
        """.write(to: sudo, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sudo.path)

        let sleep = directory.appendingPathComponent("sleep")
        try "#!/bin/sh\nexec /bin/sleep 0.02\n".write(to: sleep, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sleep.path)

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = directory.path + ":/usr/bin:/bin"
        environment["RESTORE_ATTEMPTS"] = counter.path
        let restoration = try Self.runProcess("/bin/sh", arguments: ["-c", capture.output], environment: environment)
        #expect(restoration.status == 0, "\(restoration.output)")
        let attempts = try String(contentsOf: counter, encoding: .utf8).split(separator: "\n")
        #expect(attempts.count == 3)
        #expect(attempts.allSatisfy { $0 == "-n /usr/bin/pmset -a disablesleep 0" })
    }

    private static func createTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func runProcess(_ executable: String, arguments: [String], environment: [String: String]? = nil) throws -> (status: Int32, output: String) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = output
        process.standardError = output

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (process.terminationStatus, String(data: data, encoding: .utf8)!)
    }
}
