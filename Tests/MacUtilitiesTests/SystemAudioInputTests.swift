import Foundation
import Testing

struct SystemAudioInputTests {
    @Test
    func adapterCompletesConfirmedInterruptedAndFailedChanges() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: temporaryDirectory) }

        let sources = [
            "Sources/MacUtilities/Features/IPhoneMic/AudioInput.swift",
            "Sources/MacUtilities/Features/IPhoneMic/AudioInputDevice.swift",
            "Sources/MacUtilities/Features/IPhoneMic/SystemAudioInput.swift",
            "Tests/MacUtilitiesTests/Fixtures/SystemAudioInput/FakeAudioHardware.swift",
            "Tests/MacUtilitiesTests/Fixtures/SystemAudioInput/main.swift",
        ]
        let executable = temporaryDirectory.appendingPathComponent("system-audio-input-tests")
        let compilerOutput = temporaryDirectory.appendingPathComponent("compiler-output")
        let compiler = Process()
        compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        compiler.arguments = ["swiftc", "-swift-version", "5", "-parse-as-library"]
            + sources.map { repository.appendingPathComponent($0).path }
            + ["-o", executable.path]

        let compilerStatus = try run(compiler, writingOutputTo: compilerOutput)
        let diagnostics = try String(contentsOf: compilerOutput, encoding: .utf8)
        #expect(compilerStatus == 0, "\(diagnostics)")
        if compilerStatus != 0 { return }

        let runnerOutput = temporaryDirectory.appendingPathComponent("runner-output")
        let runner = Process()
        runner.executableURL = executable
        let runnerStatus = try run(runner, writingOutputTo: runnerOutput)
        let output = try String(contentsOf: runnerOutput, encoding: .utf8)
        #expect(runnerStatus == 0, "\(output)")
        #expect(output.split(separator: "\n").filter { $0.hasPrefix("PASS ") }.count == 7, "\(output)")
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
