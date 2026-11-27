import Foundation
import Testing

struct ApplicationTerminationTests {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let sources = repository.appendingPathComponent("Sources/MacUtilities")

    @Test
    func appKitTerminationFinishesCleanupFromQueuedAndNativeRequests() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: directory) }

        let harness = directory.appendingPathComponent("termination-harness")
        let compilation = try Self.runProcess("/usr/bin/xcrun", arguments: [
            "swiftc", Self.repository.appendingPathComponent("Tests/MacUtilitiesTests/Fixtures/ApplicationTermination/main.swift").path,
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

    private static func runProcess(_ executable: String, arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (process.terminationStatus, String(data: data, encoding: .utf8)!)
    }
}
