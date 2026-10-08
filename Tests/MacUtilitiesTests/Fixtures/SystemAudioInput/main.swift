import CoreAudio

@main
struct SystemAudioInputChecks {
    @MainActor static func main() async {
        checkAvailableInputDevices()
        await checkDeviceListNotificationKeepsWaiting()
        await checkInterruptedSelection(currentDeviceID: 30)
        await checkInterruptedSelection(currentDeviceID: 10)
        await checkRemovedTargetCompletesChange()
        await checkStopObservingKeepsPendingListener()
        await checkRejectedSetterCompletesChange()
        await checkAlreadySelectedInputNeedsNoNotification()
    }

    @MainActor private static func checkAvailableInputDevices() {
        audioHardware.reset()
        audioHardware.devices = [10, 20, 30, 40, 50, 60]
        audioHardware.outputOnlyDeviceIDs = [50]
        audioHardware.inactiveDeviceIDs = [60]
        let input = SystemAudioInput()

        let devices = input.getInputDevices()
        precondition(devices.map { $0.id } == [10, 20, 30, 40])
        precondition(devices.map { $0.uid } == ["input-10", "input-20", "input-30", "input-40"])
        precondition(devices.map { $0.name } == ["input-10", "input-20", "input-30", "input-40"])
        print("PASS adapter/all-live-inputs-without-transport-filter")
    }

    @MainActor private static func checkDeviceListNotificationKeepsWaiting() async {
        audioHardware.reset()
        let input = SystemAudioInput()
        var completed = false
        let selection = Task {
            let status = await input.setDefaultInputDevice(20)
            completed = true
            return status
        }
        await waitUntil { audioHardware.requestedDeviceID == 20 }

        audioHardware.notify(kAudioHardwarePropertyDevices)
        for _ in 0..<10 { await Task.yield() }
        precondition(!completed, "Device-list notification completed a pending selection")

        audioHardware.currentDeviceID = 20
        audioHardware.notify(kAudioHardwarePropertyDefaultInputDevice)
        let status = await selection.value
        precondition(status == noErr)
        precondition(audioHardware.listeners.isEmpty)
        print("PASS adapter/device-list-waits-and-target-confirms")
    }

    @MainActor private static func checkInterruptedSelection(currentDeviceID: AudioDeviceID) async {
        audioHardware.reset()
        let input = SystemAudioInput()
        var completed = false
        let selection = Task {
            let status = await input.setDefaultInputDevice(20)
            completed = true
            return status
        }
        await waitUntil { audioHardware.requestedDeviceID == 20 }

        audioHardware.currentDeviceID = currentDeviceID
        audioHardware.notify(kAudioHardwarePropertyDefaultInputDevice)
        await waitUntil { completed }
        let status = await selection.value
        precondition(status == kAudioHardwareIllegalOperationError)
        precondition(audioHardware.currentDeviceID == currentDeviceID)
        precondition(audioHardware.listeners.isEmpty)
        print("PASS adapter/interrupted-selection-\(currentDeviceID)")
    }

    @MainActor private static func checkRemovedTargetCompletesChange() async {
        audioHardware.reset()
        let input = SystemAudioInput()
        let selection = Task { await input.setDefaultInputDevice(20) }
        await waitUntil { audioHardware.requestedDeviceID == 20 }

        audioHardware.devices = [10, 30]
        audioHardware.notify(kAudioHardwarePropertyDevices)
        let status = await selection.value
        precondition(status == kAudioHardwareBadDeviceError)
        precondition(audioHardware.listeners.isEmpty)
        print("PASS adapter/removed-target")
    }

    @MainActor private static func checkStopObservingKeepsPendingListener() async {
        audioHardware.reset()
        let input = SystemAudioInput()
        var notifications = 0
        input.startObserving { notifications += 1 }
        let selection = Task { await input.setDefaultInputDevice(20) }
        await waitUntil { audioHardware.requestedDeviceID == 20 }

        input.stopObserving()
        precondition(audioHardware.listeners.count == 2)
        audioHardware.currentDeviceID = 20
        audioHardware.notify(kAudioHardwarePropertyDefaultInputDevice)
        let status = await selection.value
        precondition(status == noErr)
        precondition(notifications == 0)
        precondition(audioHardware.listeners.isEmpty)
        print("PASS adapter/stop-observing-finishes-pending-change")
    }

    @MainActor private static func checkRejectedSetterCompletesChange() async {
        audioHardware.reset()
        audioHardware.setterStatus = kAudioHardwareUnspecifiedError
        let input = SystemAudioInput()

        let status = await input.setDefaultInputDevice(20)
        precondition(status == kAudioHardwareUnspecifiedError)
        precondition(audioHardware.currentDeviceID == 10)
        precondition(audioHardware.listeners.isEmpty)
        print("PASS adapter/rejected-setter")
    }

    @MainActor private static func checkAlreadySelectedInputNeedsNoNotification() async {
        audioHardware.reset()
        let input = SystemAudioInput()

        let status = await input.setDefaultInputDevice(10)
        precondition(status == noErr)
        precondition(audioHardware.requestedDeviceID == nil)
        precondition(audioHardware.listeners.isEmpty)
        print("PASS adapter/already-selected")
    }

    @MainActor private static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
        precondition(condition(), "Expected asynchronous work did not complete")
    }
}
