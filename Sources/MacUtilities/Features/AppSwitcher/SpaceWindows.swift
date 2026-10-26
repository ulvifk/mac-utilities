import AppKit

private typealias GetMainConnectionID = @convention(c) () -> Int32
private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>
private typealias CopyWindowsWithOptionsAndTags = @convention(c) (Int32, UInt32, CFArray, UInt32, UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>) -> Unmanaged<CFArray>

private let anyOwner: UInt32 = 0 // windows of every connection, not only ours
private let openWindowsOnly: UInt32 = 0 // the invisible-window flags would add closed windows still kept ordered out
private let normalWindowLayer = Int(CGWindowLevelForKey(.normalWindow)) // no palettes, panels or menu bar strips

/// The processes with an open window on any Space of any display, full-screen ones included. The public window list cannot tell a window on
/// another Space from a closed one kept ordered out, so each Space's windows come from the window server. Minimized windows and hidden apps'
/// windows are ordered out too, so they are missing here. CGS* is not in the SDK but still in the dylib.
func getProcessesWithOpenWindowsOnAnySpace() -> Set<pid_t> {
    let handle = dlopen(nil, RTLD_NOW)
    let getMainConnection = unsafeBitCast(dlsym(handle, "CGSMainConnectionID")!, to: GetMainConnectionID.self)
    let copyManagedDisplaySpaces = unsafeBitCast(dlsym(handle, "CGSCopyManagedDisplaySpaces")!, to: CopyManagedDisplaySpaces.self)
    let copyWindows = unsafeBitCast(dlsym(handle, "CGSCopyWindowsWithOptionsAndTags")!, to: CopyWindowsWithOptionsAndTags.self)
    let connection = getMainConnection()

    let displays = copyManagedDisplaySpaces(connection).takeRetainedValue() as! [[String: Any]]
    var setTags: UInt64 = 0
    var clearTags: UInt64 = 0
    let windows = copyWindows(connection, anyOwner, getSpaceIDs(displays) as CFArray, openWindowsOnly, &setTags, &clearTags).takeRetainedValue()

    var processes = Set<pid_t>()
    for window in getWindowDescriptions(windows as! [CGWindowID]) {
        if window[kCGWindowLayer as String] as! Int != normalWindowLayer { continue }
        processes.insert(window[kCGWindowOwnerPID as String] as! pid_t)
    }

    return processes
}

/// Every Space of every display, desktops, full-screen apps and Split Views alike.
private func getSpaceIDs(_ displays: [[String: Any]]) -> [Int] {
    var spaceIDs: [Int] = []
    for display in displays {
        for space in display["Spaces"] as! [[String: Any]] {
            spaceIDs.append(space["id64"] as! Int)
        }
    }

    return spaceIDs
}

/// Describes only the given windows, far cheaper than the whole session's window list. The function takes the ids themselves as the array's
/// values, not as CFNumbers; handed CFNumbers it finds no window.
private func getWindowDescriptions(_ windowIDs: [CGWindowID]) -> [[String: Any]] {
    var values = windowIDs.map { UnsafeRawPointer(bitPattern: UInt($0)) }
    let array = CFArrayCreate(nil, &values, values.count, nil)!

    return CGWindowListCreateDescriptionFromArray(array) as! [[String: Any]]
}
