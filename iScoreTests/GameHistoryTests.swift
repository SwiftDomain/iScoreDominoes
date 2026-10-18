//
//  GameHistoryTests.swift
//  iScoreTests
//
//  What the point grid learns from: every round value this user has
//  actually recorded for a game type.
//

import Foundation
import Testing
@testable import iScore

struct GameHistoryTests {

    private func game(_ type: GameType, rounds: [(Int, Team)]) -> Game {
        let g = Game(gameType: type, maxScore: type == .six ? 100 : 200)
        for (points, team) in rounds { g.addRound(points, for: team) }
        return g
    }

    @Test func collectsEveryRoundValueForTheType() {
        let games = [
            game(.nine, rounds: [(25, .team1), (30, .team2)]),
            game(.nine, rounds: [(25, .team2)]),
            game(.six, rounds: [(15, .team1)])
        ]
        #expect(GameHistory.roundValues(in: games, type: .nine) == [25, 30, 25])
        #expect(GameHistory.roundValues(in: games, type: .six) == [15])
    }

    @Test func noGamesGivesNoHistory() {
        #expect(GameHistory.roundValues(in: [], type: .six).isEmpty)
    }

    @Test func theSeedRowIsNotARound() {
        #expect(GameHistory.roundValues(in: [game(.six, rounds: [])], type: .six).isEmpty)
    }

    @Test func historyFeedsTheGrid() {
        let games = (0..<20).map { _ in game(.six, rounds: [(47, .team1)]) }
        let grid = PointGrid.values(for: .six, history: GameHistory.roundValues(in: games, type: .six))
        #expect(grid.contains(47))
    }
}
