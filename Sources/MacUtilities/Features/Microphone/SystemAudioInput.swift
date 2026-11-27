import CoreAudio

/// The Mac's audio inputs. A selection completes only once the hardware reports the outcome: the requested input became the default, it
/// disconnected, or another input became the default instead. The hardware is listened to while observed or while a selection is pending.
final class SystemAudioInput: AudioInput {
    private let hardware: AudioHardware

    private var listener: AudioObjectPropertyListenerBlock?
    private var onChange: (() -> Void)?
    private var inputChange: (deviceUID: String, continuation: CheckedContinuation<OSStatus, Never>)?

    init(hardware: AudioHardware) {
        self.hardware = hardware
    }

    deinit {
        stopObserving()
    }

    /// The live devices with input streams, whatever their transport.
    func getInputDevices() -> [AudioInputDevice] {
        return hardware.getDeviceIDs().compactMap { getInputDevice($0) }
    }

    func getDefaultInputDeviceID() -> AudioDeviceID {
        return hardware.getDefaultInputDeviceID()
    }

    @MainActor func setDefaultInputDevice(_ id: AudioDeviceID) async -> OSStatus {
        guard let deviceUID = hardware.getUID(id) else {
            return kAudioHardwareBadDeviceError
        }
        startListening()

        let currentDeviceUID = hardware.getUID(hardware.getDefaultInputDeviceID())
        if currentDeviceUID == deviceUID {
            if onChange == nil { stopListening() }
            return noErr
        }

        return await withCheckedContinuation { continuation in
            inputChange = (deviceUID, continuation)

            let status = hardware.setDefaultInputDevice(id)
            if status != noErr { finishInputChange(status: status) }
        }
    }

    func startObserving(_ onChange: @escaping () -> Void) {
        self.onChange = onChange
        startListening()
    }

    func stopObserving() {
        onChange = nil
        if inputChange != nil { return }
        stopListening()
    }

    private func startListening() {
        if listener != nil { return }

        let listener: AudioObjectPropertyListenerBlock = { [weak self] count, addresses in
            let properties = UnsafeBufferPointer(start: addresses, count: Int(count))
            let didChangeDefaultInput = properties.contains { $0.mSelector == kAudioHardwarePropertyDefaultInputDevice }
            self?.inputChanged(didChangeDefaultInput: didChangeDefaultInput)
        }
        self.listener = listener
        hardware.addListener(listener)
    }

    private func stopListening() {
        guard let listener else { return }

        hardware.removeListener(listener)
        self.listener = nil
    }

    private func inputChanged(didChangeDefaultInput: Bool) {
        if let inputChange {
            let devices = getInputDevices()
            let currentDeviceID = getDefaultInputDeviceID()
            let currentInput = devices.first { $0.id == currentDeviceID }

            if currentInput?.uid == inputChange.deviceUID {
                finishInputChange(status: noErr)
            } else if !devices.contains(where: { $0.uid == inputChange.deviceUID }) {
                finishInputChange(status: kAudioHardwareBadDeviceError)
            } else if didChangeDefaultInput {
                finishInputChange(status: kAudioHardwareIllegalOperationError)
            }
        }
        onChange?()
    }

    private func finishInputChange(status: OSStatus) {
        let continuation = inputChange!.continuation
        inputChange = nil
        if onChange == nil { stopListening() }

        continuation.resume(returning: status)
    }

    private func getInputDevice(_ id: AudioDeviceID) -> AudioInputDevice? {
        if !hardware.hasInputStreams(id) { return nil }
        if !hardware.isAlive(id) { return nil }

        guard let uid = hardware.getUID(id) else { return nil }
        guard let name = hardware.getName(id) else { return nil }

        return AudioInputDevice(id: id, uid: uid, name: name)
    }
}
