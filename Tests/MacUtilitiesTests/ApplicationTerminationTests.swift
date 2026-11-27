import AppKit
import Testing
@testable import MacUtilities

/// Quitting must not deadlock when it starts inside a main-queue job or a Task: AppKit's deferred termination runs a nested run loop that
/// waits for the features' cleanup, and that cleanup needs the main queue. Terminating ends the process, so each scenario runs the real
/// NSApplication in an exit test, a child process of the test runner. AppKit starts from a run loop block, so the main thread is inside a
/// main-queue job only when the scenario puts it there.
struct ApplicationTerminationTests {
    @Test(arguments: TerminationContext.allCases)
    func quitFinishesEveryFeaturesCleanup(context: TerminationContext) async {
        await #expect(processExitsWith: .exitCode(TerminationScenario.checkedExitCode)) { [context = context as TerminationContext] in
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) {
                MainActor.assumeIsolated { TerminationScenario(context: context).run() }
            }
            CFRunLoopWakeUp(CFRunLoopGetMain())

            try await Task.sleep(for: .seconds(3))
            Issue.record("Timed out waiting for AppKit termination")
            exit(3)
        }
    }
}
