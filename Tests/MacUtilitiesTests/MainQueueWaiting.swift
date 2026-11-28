import Testing

/// How many main queue turns the waits let pass. A turn is at least one trip to the back of the main queue, so the limit counts the main thread's
/// progress, not time: a busy machine, or a test holding the main thread, delays the turns but cannot use them up. The work the tests wait for
/// took at most 4 turns, also under load.
///
/// - waitUntil and waitForResult: a hang guard, far above those 4 turns; they return as soon as the work is done.
/// - letMainQueueRun: how long it waits, always the whole limit.
private let mainQueueTurnLimit = 100

/// How long a wait on an event from outside the main queue, such as a file system notification or a child process, may take before it fails.
/// It only turns a hang into a failure, well inside the CI job's 15 minutes; the longest main thread stall seen on the runner is about 5 seconds.
let outsideEventTimeLimit: Duration = .seconds(60)

/// Waits until the condition holds, checking it once per main queue turn, so the work the code under test queued on the main queue runs between
/// checks. Fails when it still does not hold after mainQueueTurnLimit turns.
///
/// Only for work that stays on the main queue. Work that goes through a timer or another queue arrives at a time of its own, and the turns run out
/// in a fraction of a millisecond meanwhile; wait for it with waitForOutsideEvent.
@MainActor
func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    for _ in 0..<mainQueueTurnLimit {
        if condition() { return }
        await Task.yield()
    }
    try #require(condition(), "The awaited main queue work did not happen", sourceLocation: sourceLocation)
}

/// The task's result, once main queue work finishes it, checked once per main queue turn as in waitUntil. Fails when the task has not finished
/// after mainQueueTurnLimit turns.
@MainActor
func waitForResult<Value>(of task: Task<Value, Never>, sourceLocation: SourceLocation = #_sourceLocation) async throws -> Value {
    var result: Value?
    Task { result = await task.value }

    for _ in 0..<mainQueueTurnLimit {
        if let result { return result }
        await Task.yield()
    }
    return try #require(result, "The awaited task did not finish", sourceLocation: sourceLocation)
}

/// Lets mainQueueTurnLimit main queue turns pass, so the work queued now, and the work it queues in turn, runs to the end before the test checks
/// the state it left, including that something did not happen.
@MainActor
func letMainQueueRun() async {
    for _ in 0..<mainQueueTurnLimit {
        await Task.yield()
    }
}

/// Waits until the condition holds after an event from outside the main queue, checking it every 10 milliseconds. Fails after
/// outsideEventTimeLimit.
@MainActor
func waitForOutsideEvent(_ condition: () throws -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    let deadline = ContinuousClock.now.advanced(by: outsideEventTimeLimit)
    while try !condition() {
        try #require(ContinuousClock.now < deadline, "The awaited outside event did not happen", sourceLocation: sourceLocation)
        try await Task.sleep(for: .milliseconds(10))
    }
}
