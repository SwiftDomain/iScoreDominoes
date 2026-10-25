import Foundation
import Testing
@testable import iScore

@MainActor
struct ScreenAwakeTests {

    private let table = AwakeReason.tableMode(game: UUID())

    private final class Recorder {
        var calls: [Bool] = []
    }

    private func make() -> (ScreenAwake, Recorder) {
        let recorder = Recorder()
        return (ScreenAwake { recorder.calls.append($0) }, recorder)
    }

    @Test func oneReasonKeepsTheScreenAwake() {
        let (awake, recorder) = make()
        awake.set(table, true)
        #expect(awake.keepsAwake)
        #expect(recorder.calls == [true])
    }

    /// Review Focus 1: leaving table mode while still sharing keeps the screen on.
    @Test func releasingOneOfTwoReasonsStaysAwake() {
        let (awake, recorder) = make()
        awake.set(.sharing, true)
        awake.set(table, true)
        awake.set(table, false)
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

    /// The next game's screen sets its reason before the old screen goes away.
    @Test func eachGameHoldsItsOwnTableReason() {
        let (awake, recorder) = make()
        let first = AwakeReason.tableMode(game: UUID())
        let next = AwakeReason.tableMode(game: UUID())
        awake.set(first, true)
        awake.set(next, true)
        awake.set(first, false)
        #expect(awake.keepsAwake)
        #expect(recorder.calls == [true])
    }

    @Test func repeatsChangeNothing() {
        let (awake, recorder) = make()
        awake.set(.sharing, true)
        awake.set(.sharing, true)
        awake.set(table, false)
        #expect(recorder.calls == [true])
    }
}
