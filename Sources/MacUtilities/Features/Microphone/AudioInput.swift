import CoreAudio

/// The Mac's audio inputs and its default input, as MicrophoneFeature uses them.
protocol AudioInput {
    func getInputDevices() -> [AudioInputDevice]
    func getDefaultInputDeviceID() -> AudioDeviceID
    @MainActor func setDefaultInputDevice(_ id: AudioDeviceID) async -> OSStatus
    func startObserving(_ onChange: @escaping () -> Void)
    func stopObserving()
}
