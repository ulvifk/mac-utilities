import Foundation
import Testing

struct AppSwitcherEventTests {
    @Test
    func settingsWindowReportsPreviewVisibility() throws {
        let sources = [
            "Sources/MacUtilities/Settings/SettingsWindow.swift",
            "Sources/MacUtilities/Settings/SettingsSplitViewController.swift",
            "Sources/MacUtilities/Settings/SettingsPane.swift",
            "Sources/MacUtilities/Settings/SettingsMetrics.swift",
            "Sources/MacUtilities/Core/Feature.swift",
            "Tests/MacUtilitiesTests/Fixtures/SettingsPreview/SettingsPreviewFakes.swift",
            "Tests/MacUtilitiesTests/Fixtures/SettingsPreview/main.swift",
        ]

        try runFixture(sources: sources, expectedScenarioCount: 6)
    }

    @Test
    func eventHandlingPreservesDirectionCancellationAndPreviewReuse() throws {
        let sources = [
            "Sources/MacUtilities/Features/AppSwitcher/AppSwitcherFeature.swift",
            "Sources/MacUtilities/Features/AppSwitcher/SwitcherState.swift",
            "Sources/MacUtilities/Features/AppSwitcher/SwitcherPreviewStore.swift",
            "Sources/MacUtilities/Core/Feature.swift",
            "Sources/MacUtilities/Core/KeyMatching.swift",
            "Tests/MacUtilitiesTests/Fixtures/AppSwitcher/AppSwitcherFakes.swift",
            "Tests/MacUtilitiesTests/Fixtures/AppSwitcher/main.swift",
        ]

        try runFixture(sources: sources, expectedScenarioCount: 81)
    }

    private func runFixture(sources: [String], expectedScenarioCount: Int) throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: temporaryDirectory) }

        let executable = temporaryDirectory.appendingPathComponent("fixture-tests")
        let compilerOutput = temporaryDirectory.appendingPathComponent("compiler-output")
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
        #expect(output.split(separator: "\n").filter { $0.hasPrefix("PASS ") }.count == expectedScenarioCount, "\(output)")
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
