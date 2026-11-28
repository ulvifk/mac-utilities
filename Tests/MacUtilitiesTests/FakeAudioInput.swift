import CoreAudio
import Testing
@testable import MacUtilities

final class FakeAudioInput: AudioInput {
    var devices: [AudioInputDevice]
    var defaultInputDeviceID: AudioDeviceID
    var selectionStatus: OSStatus = noErr
    var selectedDeviceIDs: [AudioDeviceID] = []
    var onChange: (() -> Void)?
    var defersSelection = false

    private var inputChange: (deviceID: AudioDeviceID, continuation: CheckedContinuation<OSStatus, Never>)?

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

    @MainActor func setDefaultInputDevice(_ id: AudioDeviceID) async -> OSStatus {
        selectedDeviceIDs.append(id)
        if selectionStatus != noErr { return selectionStatus }
        if defersSelection {
            return await withCheckedContinuation { continuation in
                inputChange = (id, continuation)
            }
        }
        defaultInputDeviceID = id
        onChange?()
        return noErr
    }

    /// Confirms the pending selection, as CoreAudio does once the default input changed.
    @MainActor func completeSelection(sourceLocation: SourceLocation = #_sourceLocation) throws {
        let inputChange = try #require(inputChange, "No selection was pending", sourceLocation: sourceLocation)
        self.inputChange = nil

        defaultInputDeviceID = inputChange.deviceID
        onChange?()
        inputChange.continuation.resume(returning: noErr)
    }

    /// Reports a change of the Mac's inputs to the observer, as CoreAudio does.
    func notifyInputChange(sourceLocation: SourceLocation = #_sourceLocation) throws {
        let onChange = try #require(onChange, "Nothing observed the inputs", sourceLocation: sourceLocation)
        onChange()
    }

    func startObserving(_ onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func stopObserving() {
        onChange = nil
    }
}
