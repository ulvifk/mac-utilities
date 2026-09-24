import IOKit.pwr_mgt

/// One IOKit power assertion, held from init until release().
final class PowerAssertion {
    private var assertionID = IOPMAssertionID(0)

    init(type: String) {
        IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "MacUtilities Keep awake" as CFString, &assertionID)
    }

    func release() {
        IOPMAssertionRelease(assertionID)
    }
}
