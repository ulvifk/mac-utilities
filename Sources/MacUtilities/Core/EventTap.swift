import CoreGraphics

/// Hands every key press and modifier change in the session to one handler, which returns true when the event is swallowed and must not reach
/// the focused app. The handler must never do real work, or macOS disables the tap and the keystroke falls through.
protocol EventTap {
    /// False until started, and when macOS refused the tap at launch, which it does until Accessibility is granted; it is not retried.
    var isRunning: Bool { get }

    func start(handle: @escaping (CGEventType, CGEvent) -> Bool)
}
