import AppKit
import ApplicationServices
import os

private let dockBundleIdentifier = "com.apple.dock"
/// The SDK has no constants for the app items' subrole and their badge text.
private let applicationDockItemSubrole = "AXApplicationDockItem"
private let statusLabelAttribute = "AXStatusLabel"
/// For each question to the Dock, as for the apps' windows, so a hung Dock fails the read on its first question after this long.
private let dockMessagingTimeout: TimeInterval = 0.1
/// The whole read: each question may only take what is left of it and none is asked past it, so a Dock that keeps answering slowly
/// delays the switcher's opening by this much at most.
private let dockReadTimeLimit: TimeInterval = 0.2

/// [bundle URL] -> the badge text the Dock shows on that app's item, verbatim, e.g. "3", "12" or "•", for the switcher to draw on the app's
/// icon. There is no public API for another app's badge, so it is read from the accessibility tree: the Dock's AXList holds one item per
/// Dock tile, and an app's item (subrole AXApplicationDockItem) has its bundle as AXURL and its badge as AXStatusLabel, which has no value
/// without a badge.
/// - other items (separator, Trash, folders, minimized windows) are not asked; an app item without a badge is left out
/// - two running instances of an app have one item each with the same URL; the last one read wins
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

    for list in try getChildren(of: dock, deadline: deadline) {
        if try copyValue(of: kAXRoleAttribute, from: list, deadline: deadline) as? String != kAXListRole { continue }

        for item in try getChildren(of: list, deadline: deadline) {
            if try copyValue(of: kAXSubroleAttribute, from: item, deadline: deadline) as? String != applicationDockItemSubrole { continue }

            guard let url = try copyValue(of: kAXURLAttribute, from: item, deadline: deadline) as? URL else { continue }
            guard let badge = try copyValue(of: statusLabelAttribute, from: item, deadline: deadline) as? String else { continue }
            badges[url] = badge
        }
    }

    return badges
}

private func getChildren(of element: AXUIElement, deadline: Date) throws(DockReadFailure) -> [AXUIElement] {
    return try copyValue(of: kAXChildrenAttribute, from: element, deadline: deadline) as? [AXUIElement] ?? []
}

/// Nil when the element has no such attribute or no value for it, as an item without a badge has none for AXStatusLabel. The question
/// may take dockMessagingTimeout, or what is left before the deadline when that is less; past the deadline it is not asked.
private func copyValue(of attribute: String, from element: AXUIElement, deadline: Date) throws(DockReadFailure) -> CFTypeRef? {
    let remainingTime = deadline.timeIntervalSinceNow
    if remainingTime <= 0 { throw DockReadFailure(reason: "the Dock took longer than \(dockReadTimeLimit) seconds") }
    AXUIElementSetMessagingTimeout(element, Float(min(dockMessagingTimeout, remainingTime)))

    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    switch result {
    case .success:
        return value
    case .noValue, .attributeUnsupported:
        return nil
    default:
        throw DockReadFailure(reason: "\(attribute) failed with AXError \(result.rawValue) (\(getDescription(of: result)))")
    }
}

/// The failures the Dock read meets in practice, in words for the log.
private func getDescription(of error: AXError) -> String {
    switch error {
    case .apiDisabled: return "accessibility is not granted"
    case .cannotComplete: return "the Dock did not answer, or quit"
    case .invalidUIElement: return "the Dock's element went away, as when it restarts"
    default: return "unexpected"
    }
}
