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

    // MARK: - A finished game

    private func finished(_ target: Double, _ rounds: [(Int, Team)], type: GameType = .nine,
                          team1: [String] = ["Ana", "Luis"], at time: TimeInterval = 0) -> Game {
        let g = game(target, rounds, type: type)
        g.team1 = team1
        g.state = .finished
        g.inProcess = false
        g.timestamp = Date(timeIntervalSince1970: 1_800_000_000 + time)
        return g
    }

    @Test func aShutoutIsAZapato() {
        let g = finished(100, [(50, .team1), (50, .team1)], type: .six)
        #expect(GameDrama.finale(of: g, history: [g]) == .shutout(winner: .team1))
    }

    /// RF5: the totals decide, not what was once scored and undone.
    @Test func totalsDecideTheShutoutNotHistory() {
        let g = game(100, [(10, .team2)], type: .six)
        g.undoLastRound()
        g.addRound(100, for: .team1)
        g.state = .finished
        #expect(GameDrama.finale(of: g, history: [g]) == .shutout(winner: .team1))
    }

    @Test func comebackWinOutranksALastRoundWin() {
        let g = finished(150, [(60, .team2), (70, .team1), (20, .team2), (80, .team1)])
        #expect(GameDrama.finale(of: g, history: [g]) == .comebackWin(.team1, deficit: 60))
    }

    @Test func lastRoundWin() {
        let g = finished(100, [(20, .team1), (15, .team2), (90, .team2)], type: .six)
        #expect(GameDrama.finale(of: g, history: [g]) == .lastRoundWin(.team2))
    }

    /// Tied before the last round, the loser on the board: nothing else to say.
    private let plainWin: [(Int, Team)] = [(10, .team2), (10, .team1), (90, .team1)]

    @Test func threeWinsInARowIsAStreak() {
        let older = (1...3).map { finished(100, plainWin, type: .six,
                                           team1: ["ana", "Luis"], at: Double($0) * 100) }
        let now = finished(100, plainWin, type: .six, at: 1_000)
        #expect(GameDrama.finale(of: now, history: older + [now]) == .streak(name: "Ana", wins: 4))

        // A loss in between: only the wins since count, and two is not a streak.
        let lost = finished(100, [(100, .team2)], type: .six, at: 150)
        let recent = (2...3).map { finished(100, plainWin, type: .six, at: Double($0) * 100) }
        #expect(GameDrama.finale(of: now, history: [older[0], lost] + recent + [now]) == .streak(name: "Ana", wins: 3))
        #expect(GameDrama.finale(of: now, history: [lost, recent[1], now]) == nil)
    }

    @Test func noFinaleWhilePlaying() {
        let g = game(100, [(100, .team1)], type: .six)
        #expect(GameDrama.finale(of: g, history: [g]) == nil)
    }
}
