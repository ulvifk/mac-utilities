import CoreAudio

protocol AudioInput {
    func getInputDevices() -> [AudioInputDevice]
    func getDefaultInputDeviceID() -> AudioDeviceID
    func setDefaultInputDevice(_ id: AudioDeviceID) -> OSStatus
    func startObserving(_ onChange: @escaping () -> Void)
    func stopObserving()
}
