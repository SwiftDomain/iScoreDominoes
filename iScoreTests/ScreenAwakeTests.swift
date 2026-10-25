import Testing
@testable import iScore

@MainActor
struct ScreenAwakeTests {

    private final class Recorder {
        var calls: [Bool] = []
    }

    private func make() -> (ScreenAwake, Recorder) {
        let recorder = Recorder()
        return (ScreenAwake { recorder.calls.append($0) }, recorder)
    }

    @Test func oneReasonKeepsTheScreenAwake() {
        let (awake, recorder) = make()
        awake.set(.tableMode, true)
        #expect(awake.keepsAwake)
        #expect(recorder.calls == [true])
    }

    /// Review Focus 1: leaving table mode while still sharing keeps the screen on.
    @Test func releasingOneOfTwoReasonsStaysAwake() {
        let (awake, recorder) = make()
        awake.set(.sharing, true)
        awake.set(.tableMode, true)
        awake.set(.tableMode, false)
        #expect(awake.keepsAwake)
        #expect(recorder.calls == [true])
    }

    @Test func releasingTheLastReasonLetsItSleep() {
        let (awake, recorder) = make()
        awake.set(.watching, true)
        awake.set(.watching, false)
        #expect(!awake.keepsAwake)
        #expect(recorder.calls == [true, false])
    }

    @Test func repeatsChangeNothing() {
        let (awake, recorder) = make()
        awake.set(.sharing, true)
        awake.set(.sharing, true)
        awake.set(.tableMode, false)
        #expect(recorder.calls == [true])
    }
}
