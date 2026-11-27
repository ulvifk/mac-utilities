import ApplicationServices
import os

/// Asks macOS to show the Accessibility prompt when the app is not trusted yet; the event tap needs the grant.
func requestAccessibilityTrust() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    if AXIsProcessTrustedWithOptions(options) {
        Logger.core.notice("Accessibility permission granted")
        return
    }

    Logger.core.error("Accessibility permission not granted: grant it in System Settings > Privacy & Security > Accessibility, then relaunch")
}
