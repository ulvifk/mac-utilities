import CoreAudio
import Testing
@testable import MacUtilities

@MainActor
struct IPhoneMicFeatureTests {
    private let builtIn = AudioInputDevice(id: 1, uid: "built-in", name: "Mac microphone", isIPhone: false)
    private let iPhone = AudioInputDevice(id: 2, uid: "iphone", name: "My iPhone Microphone", isIPhone: true)
    private let headset = AudioInputDevice(id: 3, uid: "headset", name: "Headset", isIPhone: false)

    @Test
    func enablingFeatureOnlyObservesInputs() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)

        feature.start()

        #expect(audioInput.onChange != nil)
        #expect(audioInput.selectedDeviceIDs.isEmpty)
        #expect(feature.canToggle)
        #expect(feature.statusText == "Ready · \(iPhone.name)")
        #expect(feature.defaultInput == builtIn)
        #expect(!feature.isIPhoneSelected)
    }

    @Test
    func toggleSelectsIPhoneAndRestoresPreviousInput() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()

        feature.toggle()
        await waitForInputChange(feature)

        #expect(feature.canToggle)
        #expect(feature.defaultInput == iPhone)
        #expect(feature.isIPhoneSelected)

        feature.toggle()
        await waitForInputChange(feature)

        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
        #expect(feature.defaultInput == builtIn)
        #expect(!feature.isIPhoneSelected)
    }

    @Test
    func disablingFeatureRestoresInputAndStopsObserving() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)

        feature.stop()
        await waitForInputChange(feature)

        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(audioInput.onChange == nil)
        #expect(!feature.isIPhoneSelected)
    }

    @Test @MainActor
    func terminationRestoresInputAfterFeatureWasDisabled() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError
        feature.stop()
        await waitForInputChange(feature)
        #expect(feature.isIPhoneSelected)

        audioInput.selectionStatus = noErr
        await feature.prepareForTermination()

        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(!feature.isIPhoneSelected)
    }

    @Test
    func externalSelectionReleasesControlWithoutRestoring() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone, headset], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)

        audioInput.defaultInputDeviceID = headset.id
        audioInput.onChange!()
        feature.stop()
        await waitForInputChange(feature)

        #expect(!feature.isIPhoneSelected)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
        #expect(audioInput.defaultInputDeviceID == headset.id)
    }

    @Test
    func disconnectReleasesControlAndReconnectDoesNotSelectAutomatically() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)

        audioInput.devices = [builtIn]
        audioInput.onChange!()
        #expect(!feature.isIPhoneSelected)
        #expect(!feature.canToggle)

        audioInput.defaultInputDeviceID = builtIn.id
        audioInput.devices = [builtIn, iPhone]
        audioInput.onChange!()

        #expect(feature.canToggle)
        #expect(!feature.isIPhoneSelected)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
    }

    @Test
    func restorationUsesPersistentDeviceIdentifierAfterReconnect() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)

        let reconnectedInput = AudioInputDevice(id: 4, uid: builtIn.uid, name: builtIn.name, isIPhone: false)
        audioInput.devices = [reconnectedInput, iPhone]
        feature.toggle()
        await waitForInputChange(feature)

        #expect(audioInput.defaultInputDeviceID == reconnectedInput.id)
        #expect(!feature.isIPhoneSelected)
    }

    @Test
    func failedSelectionLeavesPreviousInputAndPermitsRetry() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError

        feature.toggle()
        await waitForInputChange(feature)

        #expect(!feature.isIPhoneSelected)
        #expect(feature.statusText.hasPrefix("Couldn't select iPhone microphone"))
        #expect(feature.defaultInput == builtIn)

        audioInput.selectionStatus = noErr
        feature.toggle()
        await waitForInputChange(feature)

        #expect(feature.isIPhoneSelected)
        #expect(feature.statusText == "Using \(iPhone.name)")
    }

    @Test
    func failedRestorationKeepsSessionForRetry() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError

        feature.toggle()
        await waitForInputChange(feature)

        #expect(feature.isIPhoneSelected)
        #expect(feature.canToggle)
        #expect(feature.statusText.hasPrefix("Couldn't restore previous microphone"))
        #expect(feature.defaultInput == iPhone)

        audioInput.selectionStatus = noErr
        feature.toggle()
        await waitForInputChange(feature)

        #expect(!feature.isIPhoneSelected)
        #expect(feature.statusText == "Ready · \(iPhone.name)")
        #expect(feature.defaultInput == builtIn)
    }

    @Test
    func missingPreviousInputShowsMessageAndPreservesIPhoneSelection() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)

        audioInput.devices = [iPhone]
        feature.toggle()
        await waitForInputChange(feature)

        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
        #expect(feature.isIPhoneSelected)
        #expect(feature.canToggle)
        #expect(feature.statusText.hasPrefix("Previous microphone disconnected"))
    }

    @Test
    func iPhoneCanBeSelectedWhenMacHasNoOtherMicrophone() async {
        let audioInput = FakeAudioInput(devices: [iPhone], defaultInputDeviceID: AudioDeviceID(kAudioObjectUnknown))
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()

        feature.toggle()
        await waitForInputChange(feature)
        #expect(feature.defaultInput == iPhone)

        feature.toggle()
        await waitForInputChange(feature)
        #expect(feature.isIPhoneSelected)
        #expect(feature.canToggle)
        #expect(feature.statusText.hasPrefix("No previous microphone to restore"))
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
    }

    @Test
    func unavailableOrAlreadySelectedIPhoneDoesNotChangeInput() async {
        let audioInput = FakeAudioInput(devices: [builtIn], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()

        feature.toggle()
        await waitForInputChange(feature)
        #expect(!feature.canToggle)
        #expect(audioInput.selectedDeviceIDs.isEmpty)

        audioInput.devices = [builtIn, iPhone]
        audioInput.defaultInputDeviceID = iPhone.id
        audioInput.onChange!()
        feature.toggle()
        await waitForInputChange(feature)

        #expect(!feature.canToggle)
        #expect(feature.isIPhoneSelected)
        #expect(audioInput.selectedDeviceIDs.isEmpty)
    }

    @Test
    func deferredSelectionRetainsControlUntilConfirmed() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        audioInput.defersSelection = true
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()

        feature.toggle()
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id] }
        audioInput.onChange!()
        #expect(feature.statusText == "Switching microphone…")
        #expect(!feature.canToggle)

        audioInput.completeSelection()
        await waitForInputChange(feature)
        #expect(feature.isIPhoneSelected)
        #expect(feature.canToggle)
        #expect(feature.statusText == "Using \(iPhone.name)")

        audioInput.defersSelection = false
        feature.toggle()
        await waitForInputChange(feature)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
        #expect(feature.defaultInput == builtIn)
    }

    @Test
    func disablingDuringSelectionWaitsForRestoration() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        audioInput.defersSelection = true
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id] }

        feature.stop()
        #expect(audioInput.onChange != nil)
        audioInput.completeSelection()
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id] }
        #expect(audioInput.onChange != nil)
        #expect(feature.isIPhoneSelected)

        audioInput.completeSelection()
        await waitForInputChange(feature)
        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(audioInput.onChange == nil)
    }

    @Test
    func terminationWaitsForPendingSelectionAndRestoration() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        audioInput.defersSelection = true
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
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
        feature.toggle()
        await Task.yield()
        #expect(!feature.canToggle)
        #expect(audioInput.onChange == nil)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
    }

    @Test
    func turningOffWaitsForRestorationConfirmation() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)

        audioInput.defersSelection = true
        feature.toggle()
        await waitUntil { audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id] }
        #expect(feature.isIPhoneSelected)
        #expect(!feature.canToggle)
        #expect(feature.statusText == "Switching microphone…")

        audioInput.completeSelection()
        await waitForInputChange(feature)
        #expect(feature.defaultInput == builtIn)
        #expect(feature.canToggle)
    }

    @Test
    func reusedDeviceIDDoesNotRetainOwnershipOfExternalInput() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone, headset], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)

        let reconnectedIPhone = AudioInputDevice(id: 4, uid: iPhone.uid, name: iPhone.name, isIPhone: true)
        let reassignedHeadset = AudioInputDevice(id: iPhone.id, uid: headset.uid, name: headset.name, isIPhone: false)
        audioInput.devices = [builtIn, reconnectedIPhone, reassignedHeadset]
        audioInput.defaultInputDeviceID = reassignedHeadset.id
        audioInput.onChange!()

        feature.stop()
        await waitForInputChange(feature)
        #expect(audioInput.defaultInputDeviceID == reassignedHeadset.id)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
    }

    @Test
    func sameSelectedIPhoneKeepsOwnershipAfterDeviceIDChanges() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        await waitForInputChange(feature)

        let reconnectedIPhone = AudioInputDevice(id: 4, uid: iPhone.uid, name: iPhone.name, isIPhone: true)
        audioInput.devices = [builtIn, reconnectedIPhone]
        audioInput.defaultInputDeviceID = reconnectedIPhone.id
        audioInput.onChange!()
        #expect(feature.canToggle)

        feature.toggle()
        await waitForInputChange(feature)
        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
    }

    private func waitForInputChange(_ feature: IPhoneMicFeature) async {
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
