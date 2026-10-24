import Foundation
import Testing
@testable import iScore

struct JoinCodeTests {

    @Test func alphabetHasNoLookalikes() {
        for ch in "0O1I" { #expect(!JoinCode.alphabet.contains(ch)) }
        #expect(JoinCode.alphabet.count == 32)
    }

    @Test func randomCodesAreFourCharactersFromTheAlphabet() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let code = JoinCode.random(using: &rng)
            #expect(code.value.count == 4)
            #expect(code.value.allSatisfy(JoinCode.alphabet.contains))
        }
    }

    /// Read aloud across a table and typed in a hurry: case, spaces and a
    /// hyphen must not matter.
    @Test func typedCodesAreForgiving() {
        #expect(JoinCode(typed: " k7mq ")?.value == "K7MQ")
        #expect(JoinCode(typed: "K7-MQ")?.value == "K7MQ")
        #expect(JoinCode(typed: "k 7 m q")?.value == "K7MQ")
    }

    @Test func typedCodesRejectWhatCannotBeACode() {
        #expect(JoinCode(typed: "K7M") == nil)
        #expect(JoinCode(typed: "K7MQX") == nil)
        #expect(JoinCode(typed: "K0MQ") == nil)
        #expect(JoinCode(typed: "") == nil)
    }
}
