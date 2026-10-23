import Foundation
import Testing
@testable import iScore

struct GameEndingTests {

    @Test func endingAPlayingGameFinishesIt() {
        let game = makeTestGame(rows: demoGameRows)
        game.endByUser()
        #expect(game.state == .finished)
        #expect(game.inProcess == false)
        // The score stands exactly as it was.
        #expect(game.scoreTeam == demoGameRows)
    }

    @Test func cancellingAPlayingGameCancelsIt() {
        let game = makeTestGame(rows: demoGameRows)
        game.cancelByUser()
        #expect(game.state == .cancelled)
        #expect(game.inProcess == false)
        #expect(game.scoreTeam == demoGameRows)
    }

    /// A second "end the game" must not reopen or re-decide a settled game.
    @Test func endingAndCancellingAreNoOpsOnASettledGame() {
        let finished = makeTestGame(rows: demoGameRows, state: .finished)
        finished.cancelByUser()
        #expect(finished.state == .finished)

        let cancelled = makeTestGame(rows: demoGameRows, state: .cancelled)
        cancelled.endByUser()
        #expect(cancelled.state == .cancelled)
    }

    /// Review Focus 2: a spoken round that reaches the target is a win, not a banner.
    /// `GameView` reads `winningTeam`; this pins the value the voice path relies on.
    @Test func aSpokenRoundThatReachesTheTargetWinsTheGame() {
        let game = makeTestGame(maxScore: 100, rows: [[0, 0], [75, 0]])
        #expect(game.winningTeam == .none)
        game.addRound(25, for: .team1)
        #expect(game.winningTeam == .team1)
    }
}
