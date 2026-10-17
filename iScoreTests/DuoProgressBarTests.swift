import Testing
@testable import iScore

struct DuoProgressBarTests {

    @Test(arguments: [
        (0.525, 0.525), (1.4, 1.0), (-0.2, 0.0),
        (Double.nan, 0.0), (Double.infinity, 0.0)
    ])
    func clampsToUnitRange(_ input: Double, _ expected: Double) {
        #expect(DuoProgressBar.clamped(input) == expected)
    }
}
