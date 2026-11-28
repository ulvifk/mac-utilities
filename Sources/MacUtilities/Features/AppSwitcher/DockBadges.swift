import AppKit
import ApplicationServices
import os

private let dockBundleIdentifier = "com.apple.dock"
/// The badge text on an AXApplicationDockItem; the SDK has no constant for it.
private let statusLabelAttribute = "AXStatusLabel"
/// For each question to the Dock, as for the apps' windows. A timeout only holds for the element it is set on, so each one gets it.
private let dockMessagingTimeout: Float = 0.1
/// The whole read gives up past this, so a Dock answering slowly delays the switcher's opening by about this much at most.
private let dockReadTimeLimit: TimeInterval = 0.2

/// [bundle URL] -> the badge text the Dock shows on that app's item, verbatim, e.g. "3", "12" or "•", for the switcher to draw on the app's
/// icon. There is no public API for another app's badge, so it is read from the accessibility tree: the Dock's AXList holds one item per
/// Dock tile, and an app's item has its bundle as AXURL and its badge as AXStatusLabel, which has no value without a badge.
/// - an item without a URL (separator, Trash) or without a badge is left out
/// - when the Dock is not running, accessibility is not granted, the Dock goes away mid-read or does not answer in time, the failure is
///   logged once and there are no badges at all
func getDockBadges() -> [URL: String] {
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleIdentifier).first else {
        Logger.appSwitcher.error("Dock badges not read: the Dock is not running")
        return [:]
    }

    do {
        return try readDockBadges(dockProcessIdentifier: dock.processIdentifier, deadline: Date(timeIntervalSinceNow: dockReadTimeLimit))
    } catch {
        Logger.appSwitcher.error("Dock badges not read: \(error.reason, privacy: .public)")
        return [:]
    }
}

private func readDockBadges(dockProcessIdentifier: pid_t, deadline: Date) throws(DockReadFailure) -> [URL: String] {
    let dock = AXUIElementCreateApplication(dockProcessIdentifier)
    var badges: [URL: String] = [:]

    for list in try getChildren(of: dock) {
        if try copyValue(of: kAXRoleAttribute, from: list) as? String != kAXListRole { continue }

        for item in try getChildren(of: list) {
            if Date() > deadline { throw DockReadFailure(reason: "the Dock took longer than \(dockReadTimeLimit) seconds") }

            guard let url = try copyValue(of: kAXURLAttribute, from: item) as? URL else { continue }
            guard let badge = try copyValue(of: statusLabelAttribute, from: item) as? String else { continue }
            badges[url] = badge
        }
    }

    return badges
}

private func getChildren(of element: AXUIElement) throws(DockReadFailure) -> [AXUIElement] {
    return try copyValue(of: kAXChildrenAttribute, from: element) as? [AXUIElement] ?? []
}

/// Nil when the element has no such attribute or no value for it, as an item without a badge has none for AXStatusLabel.
private func copyValue(of attribute: String, from element: AXUIElement) throws(DockReadFailure) -> CFTypeRef? {
    AXUIElementSetMessagingTimeout(element, dockMessagingTimeout)

    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    switch result {
    case .success:
        return value
    case .noValue, .attributeUnsupported:
        return nil
    default:
        throw DockReadFailure(reason: "\(attribute) failed with AXError \(result.rawValue) (\(describe(result)))")
    }
}

/// The failures the Dock read meets in practice, in words for the log.
private func describe(_ error: AXError) -> String {
    switch error {
    case .apiDisabled: return "accessibility is not granted"
    case .cannotComplete: return "the Dock did not answer, or quit"
    case .invalidUIElement: return "the Dock's element went away, as when it restarts"
    default: return "unexpected"
    }
}
