import CoreAudio
@testable import MacUtilities

final class FakeAudioInput: AudioInput {
    var devices: [AudioInputDevice]
    var defaultInputDeviceID: AudioDeviceID
    var selectionStatus: OSStatus = noErr
    var selectedDeviceIDs: [AudioDeviceID] = []
    var onChange: (() -> Void)?

    init(devices: [AudioInputDevice], defaultInputDeviceID: AudioDeviceID) {
        self.devices = devices
        self.defaultInputDeviceID = defaultInputDeviceID
    }

    func getInputDevices() -> [AudioInputDevice] {
        return devices
    }

    func getDefaultInputDeviceID() -> AudioDeviceID {
        return defaultInputDeviceID
    }

    func setDefaultInputDevice(_ id: AudioDeviceID) -> OSStatus {
        selectedDeviceIDs.append(id)
        if selectionStatus != noErr { return selectionStatus }
        defaultInputDeviceID = id
        return noErr
    }

    func startObserving(_ onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func stopObserving() {
        onChange = nil
    }
}
