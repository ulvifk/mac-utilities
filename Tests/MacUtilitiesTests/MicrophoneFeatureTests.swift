import CoreAudio
import Testing
@testable import MacUtilities

@MainActor
struct MicrophoneFeatureTests {
    private let builtIn = AudioInputDevice(id: 1, uid: "built-in", name: "Mac microphone")
    private let iPhone = AudioInputDevice(id: 2, uid: "iphone", name: "My iPhone Microphone")
    private let headset = AudioInputDevice(id: 3, uid: "headset", name: "Headset")

    @Test
    func enablingFeatureOnlyObservesInputs() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)

        feature.start()

        #expect(audioInput.onChange != nil)
        #expect(audioInput.selectedDeviceIDs.isEmpty)
        #expect(feature.canSelect)
        #expect(feature.statusText == "Using \(builtIn.name)")
        #expect(feature.defaultInput == builtIn)
        #expect(!feature.isActive)
        #expect(!feature.canRestore)
    }

    @Test
    func selectionRestoresPreviousInput() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()

        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        #expect(feature.canSelect)
        #expect(feature.defaultInput == iPhone)
        #expect(feature.isActive)

        feature.restorePreviousInput()
        await waitForInputChange(feature)

        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
        #expect(feature.defaultInput == builtIn)
        #expect(!feature.isActive)
    }

    @Test
    func disablingFeatureRestoresInputAndStopsObserving() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        feature.stop()
        await waitForInputChange(feature)

        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(audioInput.onChange == nil)
        #expect(!feature.isActive)
    }

    @Test @MainActor
    func terminationRestoresInputAfterFeatureWasDisabled() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError
        feature.stop()
        await waitForInputChange(feature)
        #expect(feature.isActive)

        audioInput.selectionStatus = noErr
        await feature.prepareForTermination()

        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(!feature.isActive)
    }

    @Test
    func externalSelectionReleasesControlWithoutRestoring() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone, headset], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        audioInput.defaultInputDeviceID = headset.id
        audioInput.onChange!()
        feature.stop()
        await waitForInputChange(feature)

        #expect(!feature.isActive)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
        #expect(audioInput.defaultInputDeviceID == headset.id)
    }

    @Test
    func disconnectReleasesControlAndReconnectDoesNotSelectAutomatically() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        audioInput.devices = [builtIn]
        audioInput.onChange!()
        #expect(!feature.isActive)
        #expect(feature.canSelect)

        audioInput.defaultInputDeviceID = builtIn.id
        audioInput.devices = [builtIn, iPhone]
        audioInput.onChange!()

        #expect(feature.canSelect)
        #expect(!feature.isActive)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
    }

    @Test
    func restorationUsesPersistentDeviceIdentifierAfterReconnect() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        let reconnectedInput = AudioInputDevice(id: 4, uid: builtIn.uid, name: builtIn.name)
        audioInput.devices = [reconnectedInput, iPhone]
        feature.restorePreviousInput()
        await waitForInputChange(feature)

        #expect(audioInput.defaultInputDeviceID == reconnectedInput.id)
        #expect(!feature.isActive)
    }

    @Test
    func failedSelectionLeavesPreviousInputAndPermitsRetry() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError

        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        #expect(!feature.isActive)
        #expect(feature.statusText.hasPrefix("Couldn't select microphone"))
        #expect(feature.defaultInput == builtIn)

        audioInput.selectionStatus = noErr
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        #expect(feature.isActive)
        #expect(feature.statusText == "Using \(iPhone.name)")
    }

    @Test
    func failedRestorationKeepsSessionForRetry() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError

        feature.restorePreviousInput()
        await waitForInputChange(feature)

        #expect(feature.isActive)
        #expect(feature.canSelect)
        #expect(feature.statusText.hasPrefix("Couldn't restore previous microphone"))
        #expect(feature.defaultInput == iPhone)

        audioInput.selectionStatus = noErr
        feature.restorePreviousInput()
        await waitForInputChange(feature)

        #expect(!feature.isActive)
        #expect(feature.statusText == "Using \(builtIn.name)")
        #expect(feature.defaultInput == builtIn)
    }

    @Test
    func missingPreviousInputShowsMessageAndPreservesSelection() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        audioInput.devices = [iPhone]
        feature.restorePreviousInput()
        await waitForInputChange(feature)

        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
        #expect(feature.isActive)
        #expect(feature.canSelect)
        #expect(feature.statusText.hasPrefix("Previous microphone disconnected"))
    }

    @Test
    func inputCanBeSelectedWhenMacHasNoOtherMicrophone() async {
        let audioInput = FakeAudioInput(devices: [iPhone], defaultInputDeviceID: AudioDeviceID(kAudioObjectUnknown))
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()

        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)
        #expect(feature.defaultInput == iPhone)

        feature.restorePreviousInput()
        await waitForInputChange(feature)
        #expect(feature.isActive)
        #expect(feature.canSelect)
        #expect(feature.statusText.hasPrefix("No previous microphone to restore"))
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
    }

    @Test
    func selectingCurrentInputDoesNotTakeOwnership() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: iPhone.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()

        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)
        feature.restorePreviousInput()
        await waitForInputChange(feature)

        #expect(feature.canSelect)
        #expect(!feature.canRestore)
        #expect(!feature.isActive)
        #expect(feature.defaultInput == iPhone)
        #expect(audioInput.selectedDeviceIDs.isEmpty)
    }

    @Test
    func deferredSelectionRetainsControlUntilConfirmed() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        audioInput.defersSelection = true
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()

        feature.selectInput(iPhone.uid)
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id] }
        audioInput.onChange!()
        #expect(feature.statusText == "Switching microphone…")
        #expect(!feature.canSelect)

        audioInput.completeSelection()
        await waitForInputChange(feature)
        #expect(feature.isActive)
        #expect(feature.canSelect)
        #expect(feature.statusText == "Using \(iPhone.name)")

        audioInput.defersSelection = false
        feature.restorePreviousInput()
        await waitForInputChange(feature)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
        #expect(feature.defaultInput == builtIn)
    }

    @Test
    func disablingDuringSelectionWaitsForRestoration() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        audioInput.defersSelection = true
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id] }

        feature.stop()
        #expect(audioInput.onChange != nil)
        audioInput.completeSelection()
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id] }
        #expect(audioInput.onChange != nil)
        #expect(feature.isActive)

        audioInput.completeSelection()
        await waitForInputChange(feature)
        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(audioInput.onChange == nil)
    }

    @Test
    func terminationWaitsForPendingSelectionAndRestoration() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        audioInput.defersSelection = true
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id] }

        var terminationStarted = false
        var didTerminate = false
        let termination = Task {
            terminationStarted = true
            await feature.prepareForTermination()
            didTerminate = true
        }
        await waitUntil { terminationStarted }
        #expect(!didTerminate)

        audioInput.completeSelection()
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id] }
        #expect(!didTerminate)

        audioInput.completeSelection()
        await termination.value
        #expect(didTerminate)
        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(audioInput.onChange == nil)

        feature.start()
        feature.selectInput(iPhone.uid)
        await Task.yield()
        #expect(!feature.canSelect)
        #expect(audioInput.onChange == nil)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
    }

    @Test
    func turningOffWaitsForRestorationConfirmation() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        audioInput.defersSelection = true
        feature.restorePreviousInput()
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id] }
        #expect(feature.isActive)
        #expect(!feature.canSelect)
        #expect(feature.statusText == "Switching microphone…")

        audioInput.completeSelection()
        await waitForInputChange(feature)
        #expect(feature.defaultInput == builtIn)
        #expect(feature.canSelect)
    }

    @Test
    func reusedDeviceIDDoesNotRetainOwnershipOfExternalInput() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone, headset], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        let reconnectedIPhone = AudioInputDevice(id: 4, uid: iPhone.uid, name: iPhone.name)
        let reassignedHeadset = AudioInputDevice(id: iPhone.id, uid: headset.uid, name: headset.name)
        audioInput.devices = [builtIn, reconnectedIPhone, reassignedHeadset]
        audioInput.defaultInputDeviceID = reassignedHeadset.id
        audioInput.onChange!()

        feature.stop()
        await waitForInputChange(feature)
        #expect(audioInput.defaultInputDeviceID == reassignedHeadset.id)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
    }

    @Test
    func sameSelectedInputKeepsOwnershipAfterDeviceIDChanges() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        let reconnectedIPhone = AudioInputDevice(id: 4, uid: iPhone.uid, name: iPhone.name)
        audioInput.devices = [builtIn, reconnectedIPhone]
        audioInput.defaultInputDeviceID = reconnectedIPhone.id
        audioInput.onChange!()
        #expect(feature.canSelect)

        feature.restorePreviousInput()
        await waitForInputChange(feature)
        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
    }

    @Test
    func selectorListsAndSelectsEveryConnectedInput() async {
        let usb = AudioInputDevice(id: 5, uid: "usb", name: "USB microphone")
        let devices = [builtIn, usb, headset, iPhone]
        let audioInput = FakeAudioInput(devices: devices, defaultInputDeviceID: iPhone.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        #expect(feature.inputDevices == devices)

        for input in devices {
            feature.selectInput(input.uid)
            await waitForInputChange(feature)
            #expect(feature.defaultInput == input)
            #expect(feature.statusText == "Using \(input.name)")
        }

        #expect(audioInput.selectedDeviceIDs == devices.map { $0.id })
        feature.restorePreviousInput()
        await waitForInputChange(feature)
        #expect(feature.defaultInput == iPhone)
        #expect(!feature.isActive)
    }

    @Test
    func switchingBetweenInputsRestoresOriginalMicrophone() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone, headset], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)
        feature.selectInput(headset.uid)
        await waitForInputChange(feature)

        feature.restorePreviousInput()
        await waitForInputChange(feature)

        #expect(audioInput.selectedDeviceIDs == [iPhone.id, headset.id, builtIn.id])
        #expect(feature.defaultInput == builtIn)
        #expect(!feature.isActive)
    }

    @Test
    func externalChangeBecomesPreviousInputForNextSelection() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone, headset], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)

        audioInput.defaultInputDeviceID = headset.id
        audioInput.onChange!()
        #expect(feature.defaultInput == headset)
        #expect(!feature.canRestore)
        feature.selectInput(builtIn.uid)
        await waitForInputChange(feature)
        await feature.prepareForTermination()

        #expect(audioInput.defaultInputDeviceID == headset.id)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id, headset.id])
    }

    @Test
    func deviceListRefreshesWithoutChangingCurrentInput() async {
        let audioInput = FakeAudioInput(devices: [builtIn], defaultInputDeviceID: builtIn.id)
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()

        audioInput.devices = [builtIn, headset, iPhone]
        audioInput.onChange!()
        #expect(feature.inputDevices == [builtIn, headset, iPhone])
        #expect(feature.defaultInput == builtIn)

        audioInput.devices = [builtIn, iPhone]
        audioInput.onChange!()
        #expect(feature.inputDevices == [builtIn, iPhone])
        #expect(audioInput.selectedDeviceIDs.isEmpty)
    }

    @Test
    func switchingWithoutPreviousInputDoesNotInventOne() async {
        let audioInput = FakeAudioInput(devices: [iPhone, headset], defaultInputDeviceID: AudioDeviceID(kAudioObjectUnknown))
        let feature = MicrophoneFeature(audioInput: audioInput)
        feature.start()
        feature.selectInput(iPhone.uid)
        await waitForInputChange(feature)
        feature.selectInput(headset.uid)
        await waitForInputChange(feature)
        feature.restorePreviousInput()
        await waitForInputChange(feature)

        #expect(feature.defaultInput == headset)
        #expect(feature.statusText.hasPrefix("No previous microphone to restore"))
        #expect(audioInput.selectedDeviceIDs == [iPhone.id, headset.id])
    }

    private func waitForInputChange(_ feature: MicrophoneFeature) async {
        await waitUntil { feature.statusText != "Switching microphone…" }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
        #expect(condition())
    }
}
