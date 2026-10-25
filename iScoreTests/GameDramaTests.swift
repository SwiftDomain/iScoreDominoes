//
//  GameDramaTests.swift
//  iScoreTests
//
//  The moments the app calls out: zero most of the time, one at most, the
//  best one, and never the same kind twice in a game.
//

import Foundation
import Testing
@testable import iScore

private func game(_ target: Double = 200, _ rounds: [(Int, Team)] = [], type: GameType = .nine) -> Game {
    let game = Game(gameType: type, maxScore: target)
    game.team1 = ["Ana", "Luis"]
    game.team2 = ["Rafa", "Mia"]
    for (points, team) in rounds { game.addRound(points, for: team) }
    return game
}

private let quietNight = [10, 20, 25, 30, 35]

struct GameDramaTests {

    // MARK: - Round highlights

    @Test func nothingHappenedIsNothing() {
        let g = game(200, [(25, .team1), (30, .team2)])
        let h = GameDrama.roundHighlight(after: g.rounds.last!, in: g, capicua: false,
                                         earlierRoundsTonight: quietNight, alreadyShown: [])
        #expect(h == nil)
    }

    @Test func capicuaOutranksEverything() {
        let g = game(200, [(60, .team2), (70, .team1)])
        let h = GameDrama.roundHighlight(after: g.rounds.last!, in: g, capicua: true,
                                         earlierRoundsTonight: quietNight, alreadyShown: [])
        #expect(h == .capicua(.team1))
    }

    @Test func comebackWhenATeamTrailingByAQuarterTakesTheLead() {
        let g = game(200, [(60, .team2), (70, .team1)])
        let h = GameDrama.roundHighlight(after: g.rounds.last!, in: g, capicua: false,
                                         earlierRoundsTonight: [], alreadyShown: [])
        #expect(h == .comeback(.team1, deficit: 60))

        let small = game(200, [(45, .team2), (50, .team1)])
        #expect(GameDrama.roundHighlight(after: small.rounds.last!, in: small, capicua: false,
                                         earlierRoundsTonight: [], alreadyShown: []) == nil)
    }

    /// Already in front: a later round is not a comeback again.
    @Test func aComebackIsTheRoundThatTakesTheLead() {
        let g = game(200, [(60, .team2), (70, .team1), (10, .team1)])
        #expect(GameDrama.roundHighlight(after: g.rounds.last!, in: g, capicua: false,
                                         earlierRoundsTonight: [], alreadyShown: []) == nil)
    }

    @Test func comebackDeficitIsAQuarterRoundedToFive() {
        #expect(GameDrama.comebackDeficit(target: 100) == 25)
        #expect(GameDrama.comebackDeficit(target: 200) == 50)
        #expect(GameDrama.comebackDeficit(target: 150) == 40)
        #expect(GameDrama.comebackDeficit(target: 10) == 5)
    }

    @Test func biggestRoundNeedsFiveEarlierRoundsAndMustBeatThemAll() {
        let g = game(200, [(90, .team1)])
        let round = g.rounds.last!
        #expect(GameDrama.roundHighlight(after: round, in: g, capicua: false,
                                         earlierRoundsTonight: [10, 20, 30, 40], alreadyShown: []) == nil)
        #expect(GameDrama.roundHighlight(after: round, in: g, capicua: false,
                                         earlierRoundsTonight: [10, 20, 30, 40, 50], alreadyShown: [])
                == .biggestRound(.team1, points: 90))
        #expect(GameDrama.roundHighlight(after: round, in: g, capicua: false,
                                         earlierRoundsTonight: [10, 20, 90, 40, 50], alreadyShown: []) == nil)
    }

    /// RF1: undo does not reset what was shown.
    @Test func aKindShownOnceIsNotShownAgain() {
        let g = game(200, [(60, .team2), (70, .team1)])
        #expect(GameDrama.roundHighlight(after: g.rounds.last!, in: g, capicua: false,
                                         earlierRoundsTonight: [], alreadyShown: [.comeback]) == nil)
    }

    /// RF4: earlier days do not count toward tonight.
    @Test func onlyTodaysRoundsCount() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let yesterday = game(200, [(95, .team1)])
        yesterday.timestamp = now.addingTimeInterval(-86_400)
        let earlierToday = game(200, [(40, .team2), (15, .team1)])
        earlierToday.timestamp = now.addingTimeInterval(-3_600)
        let current = game(200, [(20, .team1), (30, .team2), (70, .team1)])
        current.timestamp = now

        let points = GameDrama.roundsTonight(in: [yesterday, earlierToday, current],
                                             before: current.rounds.last!, of: current,
                                             now: now, calendar: calendar)
        #expect(points.sorted() == [15, 20, 30, 40])
    }
}
