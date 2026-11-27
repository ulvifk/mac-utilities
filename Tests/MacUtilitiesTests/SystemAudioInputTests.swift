import CoreAudio
import Testing
@testable import MacUtilities

/// The adapter's device filtering, and when a requested default input counts as done: confirmed, interrupted by another input, failed
/// because the target disconnected or the setter refused it.
@MainActor
struct SystemAudioInputTests {
    private let hardware = FakeAudioHardware()
    private let input: SystemAudioInput

    init() {
        input = SystemAudioInput(hardware: hardware)
    }

    @Test
    func listsEveryLiveInputWhateverItsTransport() {
        hardware.deviceIDs = [10, 20, 30, 40, 50, 60]
        hardware.outputOnlyDeviceIDs = [50]
        hardware.inactiveDeviceIDs = [60]

        let devices = input.getInputDevices()

        #expect(devices.map { $0.id } == [10, 20, 30, 40])
        #expect(devices.map { $0.uid } == ["input-10", "input-20", "input-30", "input-40"])
        #expect(devices.map { $0.name } == ["input-10", "input-20", "input-30", "input-40"])
    }

    @Test
    func deviceListChangeKeepsWaitingAndTheTargetConfirms() async throws {
        var completed = false
        let selection = Task {
            let status = await input.setDefaultInputDevice(20)
            completed = true
            return status
        }
        try await waitUntil { hardware.requestedDeviceID == 20 }

        hardware.notify(kAudioHardwarePropertyDevices)
        for _ in 0..<10 { await Task.yield() }
        #expect(!completed, "Device-list notification completed a pending selection")

        hardware.defaultInputDeviceID = 20
        hardware.notify(kAudioHardwarePropertyDefaultInputDevice)
        #expect(await selection.value == noErr)
        #expect(hardware.listeners.isEmpty)
    }

    /// 30 is another input; 10 is the one selected before, so the change was undone.
    @Test(arguments: [AudioDeviceID(30), AudioDeviceID(10)])
    func anotherDefaultInputInterruptsTheSelection(defaultInputDeviceID: AudioDeviceID) async throws {
        let selection = Task { await input.setDefaultInputDevice(20) }
        try await waitUntil { hardware.requestedDeviceID == 20 }

        hardware.defaultInputDeviceID = defaultInputDeviceID
        hardware.notify(kAudioHardwarePropertyDefaultInputDevice)

        #expect(await selection.value == kAudioHardwareIllegalOperationError)
        #expect(hardware.defaultInputDeviceID == defaultInputDeviceID)
        #expect(hardware.listeners.isEmpty)
    }

    @Test
    func removedTargetFailsTheSelection() async throws {
        let selection = Task { await input.setDefaultInputDevice(20) }
        try await waitUntil { hardware.requestedDeviceID == 20 }

        hardware.deviceIDs = [10, 30]
        hardware.notify(kAudioHardwarePropertyDevices)

        #expect(await selection.value == kAudioHardwareBadDeviceError)
        #expect(hardware.listeners.isEmpty)
    }

    @Test
    func stoppingObservationKeepsListeningUntilThePendingSelectionFinishes() async throws {
        var notifications = 0
        input.startObserving { notifications += 1 }
        let selection = Task { await input.setDefaultInputDevice(20) }
        try await waitUntil { hardware.requestedDeviceID == 20 }

        input.stopObserving()
        #expect(hardware.listeners.count == 1)

        hardware.defaultInputDeviceID = 20
        hardware.notify(kAudioHardwarePropertyDefaultInputDevice)
        #expect(await selection.value == noErr)
        #expect(notifications == 0)
        #expect(hardware.listeners.isEmpty)
    }

    @Test
    func rejectedSetterFailsTheSelection() async {
        hardware.setterStatus = kAudioHardwareUnspecifiedError

        let status = await input.setDefaultInputDevice(20)

        #expect(status == kAudioHardwareUnspecifiedError)
        #expect(hardware.defaultInputDeviceID == 10)
        #expect(hardware.listeners.isEmpty)
    }

    @Test
    func selectingTheCurrentInputNeedsNoNotification() async {
        let status = await input.setDefaultInputDevice(10)

        #expect(status == noErr)
        #expect(hardware.requestedDeviceID == nil)
        #expect(hardware.listeners.isEmpty)
    }
}
