import AppKit
import ApplicationServices

enum DockBadges {
    static func read() -> [String: String] {
        if !AXIsProcessTrusted() { return [:] }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return [:] }
        let application = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.1)
        guard let children = getAttribute(application, kAXChildrenAttribute) as? [AXUIElement] else { return [:] }
        guard let list = children.first(where: { getAttribute($0, kAXRoleAttribute) as? String == "AXList" }) else { return [:] }
        guard let items = getAttribute(list, kAXChildrenAttribute) as? [AXUIElement] else { return [:] }
        var badges: [String: String] = [:]
        for item in items {
            if getAttribute(item, kAXSubroleAttribute) as? String != "AXApplicationDockItem" { continue }
            guard let url = getAttribute(item, kAXURLAttribute) as? URL else { continue }
            guard let badge = getAttribute(item, "AXStatusLabel") as? String else { continue }
            if badge.isEmpty { continue }
            badges[url.standardizedFileURL.path] = badge
        }
        return badges
    }

    private static func getAttribute(_ element: AXUIElement, _ key: String) -> Any? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, key as CFString, &value)
        return value
    }
}
