import CoreAudio
import Testing
@testable import MacUtilities

/// Devices 10, 20 and 30, all live inputs, with 10 the default. A device's UID and name are "input-<id>". A requested default only takes
/// effect once a test changes defaultInputDeviceID and calls notify, as CoreAudio confirms a change later.
final class FakeAudioHardware: AudioHardware {
    var deviceIDs: [AudioDeviceID] = [10, 20, 30]
    var outputOnlyDeviceIDs: [AudioDeviceID] = []
    var inactiveDeviceIDs: [AudioDeviceID] = []
    var defaultInputDeviceID: AudioDeviceID = 10
    var requestedDeviceID: AudioDeviceID?
    var setterStatus: OSStatus = noErr
    private(set) var listeners: [AudioObjectPropertyListenerBlock] = []

    func getDeviceIDs() -> [AudioDeviceID] {
        return deviceIDs
    }

    func getDefaultInputDeviceID() -> AudioDeviceID {
        return defaultInputDeviceID
    }

    func setDefaultInputDevice(_ id: AudioDeviceID) -> OSStatus {
        requestedDeviceID = id
        return setterStatus
    }

    func hasInputStreams(_ id: AudioDeviceID) -> Bool {
        return !outputOnlyDeviceIDs.contains(id)
    }

    func isAlive(_ id: AudioDeviceID) -> Bool {
        return !inactiveDeviceIDs.contains(id)
    }

    func getUID(_ id: AudioDeviceID) -> String? {
        return "input-\(id)"
    }

    func getName(_ id: AudioDeviceID) -> String? {
        return "input-\(id)"
    }

    func addListener(_ listener: @escaping AudioObjectPropertyListenerBlock) {
        listeners.append(listener)
    }

    func removeListener(_ listener: @escaping AudioObjectPropertyListenerBlock) {
        listeners.removeAll()
    }

    /// Reports one changed property to the listener, as CoreAudio does.
    func notify(_ selector: AudioObjectPropertySelector, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let listener = try #require(listeners.first, "Nothing listened for the hardware change", sourceLocation: sourceLocation)
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        listener(1, &address)
    }
}
