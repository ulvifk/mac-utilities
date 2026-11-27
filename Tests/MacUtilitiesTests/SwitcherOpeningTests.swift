import Testing
@testable import MacUtilities

struct SwitcherOpeningTests {
    @Test
    func pressesAddUpToTheSelectionItOpensWith() {
        let opening = SwitcherOpening(listsWindows: false)

        opening.addPress(backward: false)
        opening.addPress(backward: false)
        opening.addPress(backward: true)

        #expect(opening.pendingAdvance == 1)
        #expect(!opening.isCommandReleased)
    }

    @Test
    func releasingCommandIsRemembered() {
        let opening = SwitcherOpening(listsWindows: true)

        opening.addPress(backward: true)
        opening.releaseCommand()

        #expect(opening.listsWindows)
        #expect(opening.pendingAdvance == -1)
        #expect(opening.isCommandReleased)
    }
}
