import CoreAudio

protocol AudioInput {
    func getInputDevices() -> [AudioInputDevice]
    func getDefaultInputDeviceID() -> AudioDeviceID
    @MainActor func setDefaultInputDevice(_ id: AudioDeviceID) async -> OSStatus
    func startObserving(_ onChange: @escaping () -> Void)
    func stopObserving()
}
