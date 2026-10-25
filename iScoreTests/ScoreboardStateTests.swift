//
//  ScoreboardStateTests.swift
//  iScoreTests
//
//  What the Live Activity shows, and the optimistic arithmetic the widget
//  does on a tap before the app has drained anything. `recent` is what makes
//  undo possible in a process that may not open the store.
//

import Foundation
import Testing
@testable import iScore

struct ScoreboardStateTests {

    private func state(_ t1: Int, _ t2: Int, recent: [Int] = [], target: Int = 200) -> ScoreboardState {
        ScoreboardState(
            target: target, total1: t1, total2: t2, recent: recent
        )
    }

    // MARK: - Round display

    /// The Lock Screen shows each round's score, display only: one column per
    /// round, the scoring team's points in its row, nothing in the other's.
    @Test func eachRoundIsAColumnWithTheScoringTeamsPoints() {
        let columns = state(55, 30, recent: [25, -30, 30]).roundColumns(limit: 6)
        #expect(columns == [
            .init(team1: 25, team2: nil),
            .init(team1: nil, team2: 30),
            .init(team1: 30, team2: nil),
        ])
    }

    /// Only the latest rounds fit; the newest is last (rightmost).
    @Test func onlyTheLatestRoundsAreShown() {
        let recent = [10, -20, 30, -40, 50, -60, 70, -80]
        let columns = state(160, 200, recent: recent).roundColumns(limit: 6)
        #expect(columns.count == 6)
        #expect(columns.first == .init(team1: 30, team2: nil))
        #expect(columns.last == .init(team1: nil, team2: 80))
    }

    @Test func noRoundsNoColumns() {
        #expect(state(0, 0).roundColumns(limit: 6).isEmpty)
    }

    @Test func roundNumberIsOneMoreThanRoundsPlayed() {
        #expect(state(0, 0).roundNumber == 1)
        #expect(state(55, 30, recent: [25, -30, 30]).roundNumber == 4)
    }

    @Test func leaderAndPointsToWin() {
        #expect(state(120, 80).leader == .team1)
        #expect(state(80, 120).leader == .team2)
        #expect(state(100, 100).leader == nil)
        #expect(state(120, 80).pointsToWin(.team1) == 80)
        #expect(state(120, 80).pointsToWin(.team2) == 120)
        #expect(state(220, 80).pointsToWin(.team1) == 0)
    }

    @Test func applyingARoundUpdatesTotalAndRecent() {
        let next = state(25, 0, recent: [25]).applyingRound(30, for: .team2)
        #expect(next.total1 == 25)
        #expect(next.total2 == 30)
        #expect(next.recent == [25, -30])
        #expect(next.roundNumber == 3)
    }

    @Test func applyingAnUndoReversesTheLastRound() {
        let next = state(25, 30, recent: [25, -30]).applyingUndo()
        #expect(next.total1 == 25)
        #expect(next.total2 == 0)
        #expect(next.recent == [25])
    }

    @Test func undoIsUnavailableWithNothingToTakeBack() {
        #expect(state(0, 0).canUndo == false)
        #expect(state(0, 0).applyingUndo() == state(0, 0))
        #expect(state(25, 0, recent: [25]).canUndo)
    }

    @Test func recentIsCappedButTotalsStayWhole() {
        var s = state(0, 0)
        for _ in 0..<15 { s = s.applyingRound(10, for: .team1) }
        #expect(s.total1 == 150)
        #expect(s.recent.count == ScoreboardState.recentLimit)
        #expect(s.recent.allSatisfy { $0 == 10 })
    }

    @Test func nonPositivePointsChangeNothing() {
        let s = state(25, 0, recent: [25])
        #expect(s.applyingRound(0, for: .team1) == s)
        #expect(s.applyingRound(-10, for: .team2) == s)
    }

    @Test func madeFromAGameItMatchesTheGame() {
        let game = Game(gameType: .nine, maxScore: 200)
        game.addRound(25, for: .team1)
        game.addRound(30, for: .team2)
        let s = ScoreboardState.make(from: game)

        #expect(s.total1 == 25)
        #expect(s.total2 == 30)
        #expect(s.recent == [25, -30])
        #expect(s.target == 200)
        #expect(s.roundNumber == game.currentRoundNumber)
        #expect(s.leader == .team2)
        #expect(s.pointsToWin(.team2) == game.pointsToWin(for: .team2))
    }
}
