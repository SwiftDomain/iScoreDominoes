import Testing
@testable import iScore

/// One listening session yields one result. Finishing by tap stops the
/// recognizer, and that stop also reads as the session ending by itself; both
/// paths reached the scoring step, so a spoken round was added twice.
struct VoiceSessionGateTests {

    @Test func aSessionConcludesOnce() {
        var gate = VoiceSessionGate()
        gate.begin()
        let byTap = gate.claim()            // the tap that finishes listening
        let byRecognizer = gate.claim()     // the recognizer ending because of that stop
        #expect(byTap)
        #expect(!byRecognizer)
    }

    @Test func theNextSessionConcludesAgain() {
        var gate = VoiceSessionGate()
        gate.begin()
        _ = gate.claim()
        gate.begin()
        let next = gate.claim()
        #expect(next)
    }

    /// Nothing was listening, so there is nothing to conclude.
    @Test func noSessionNoConclusion() {
        var gate = VoiceSessionGate()
        let claimed = gate.claim()
        #expect(!claimed)
    }
}
