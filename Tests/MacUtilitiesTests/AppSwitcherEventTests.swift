import Foundation
import Testing

struct AppSwitcherEventTests {
    @Test
    func eventHandlingPreservesDirectionCancellationAndPreviewReuse() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: temporaryDirectory) }

        let executable = temporaryDirectory.appendingPathComponent("switcher-event-tests")
        let compilerOutput = temporaryDirectory.appendingPathComponent("compiler-output")
        let sources = [
            "Sources/MacUtilities/Features/AppSwitcher/AppSwitcherFeature.swift",
            "Sources/MacUtilities/Features/AppSwitcher/SwitcherState.swift",
            "Sources/MacUtilities/Core/Feature.swift",
            "Sources/MacUtilities/Core/KeyMatching.swift",
            "Tests/MacUtilitiesTests/Fixtures/AppSwitcher/AppSwitcherFakes.swift",
            "Tests/MacUtilitiesTests/Fixtures/AppSwitcher/main.swift",
        ]
        let compiler = Process()
        compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        compiler.arguments = ["swiftc", "-swift-version", "5"]
            + sources.map { repository.appendingPathComponent($0).path }
            + ["-o", executable.path]

        let compilerStatus = try run(compiler, writingOutputTo: compilerOutput)
        let diagnostics = try String(contentsOf: compilerOutput, encoding: .utf8)
        #expect(compilerStatus == 0, "\(diagnostics)")
        if compilerStatus != 0 { return }

        let runner = Process()
        runner.executableURL = executable
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "APP_SWITCHER_SMOKE_TEST")
        runner.environment = environment
        let runnerOutput = temporaryDirectory.appendingPathComponent("runner-output")

        let runnerStatus = try run(runner, writingOutputTo: runnerOutput)
        let output = try String(contentsOf: runnerOutput, encoding: .utf8)
        #expect(runnerStatus == 0, "\(output)")
        #expect(output.split(separator: "\n").filter { $0.hasPrefix("PASS ") }.count == 64, "\(output)")
    }

    private func run(_ process: Process, writingOutputTo output: URL) throws -> Int32 {
        _ = FileManager.default.createFile(atPath: output.path, contents: nil)
        let handle = try FileHandle(forWritingTo: output)
        defer { try! handle.close() }

        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        process.waitUntilExit()

        return process.terminationStatus
    }
}
