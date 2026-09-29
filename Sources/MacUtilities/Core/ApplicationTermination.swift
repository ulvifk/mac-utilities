import AppKit

/// Leaves the caller's main-queue job before AppKit enters its deferred-termination run loop.
func terminateApplication() {
    let runLoop = CFRunLoopGetMain()
    CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
        NSApplication.shared.terminate(nil)
    }
    CFRunLoopWakeUp(runLoop)
}
