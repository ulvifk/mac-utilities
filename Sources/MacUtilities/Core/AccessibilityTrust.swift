import ApplicationServices

/// Asks macOS to show the Accessibility prompt when the app is not trusted yet; the event tap needs the grant.
func requestAccessibilityTrust() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    if AXIsProcessTrustedWithOptions(options) { return }

    print("Accessibility permission not granted: grant it in System Settings > Privacy & Security > Accessibility, then relaunch.")
}
