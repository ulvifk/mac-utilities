import ApplicationServices
import Combine

/// Whether macOS trusts the app for Accessibility, re-checked on demand.
final class AccessibilityStatus: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }
}
