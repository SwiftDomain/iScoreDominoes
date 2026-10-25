//
//  NightRecapTests.swift
//  iScoreTests
//
//  A night is inferred, never stored: finished games on the same day that
//  share at least three players. Then the card's numbers.
//

import Foundation
import Testing
@testable import iScore

private let calendar = Calendar(identifier: .gregorian)
private let tonight = Date(timeIntervalSince1970: 1_800_000_000)

/// A finished game; `winner` reaches the 100 target in its last round.
private func played(_ team1: [String], _ team2: [String], winner: Team = .team1,
                    rounds: [(Int, Team)] = [], minutes: Double = 0,
                    state: GameState = .finished) -> Game {
    let game = Game(gameType: .six, maxScore: 100)
    game.team1 = team1
    game.team2 = team2
    for (points, team) in rounds { game.addRound(points, for: team) }
    if state == .finished {
        game.addRound(100 - game.total(for: winner), for: winner)
    }
    game.state = state
    game.inProcess = state == .playing
    game.timestamp = tonight.addingTimeInterval(minutes * 60)
    return game
}

private let ana = ["Ana", "Luis"]
private let rafa = ["Rafa", "Mia"]

struct NightRecapTests {

    // MARK: - Which games

    @Test func sameDaySameGroupIsTheNight() {
        let first = played(ana, rafa, minutes: 0)
        let second = played(ana, rafa, winner: .team2, minutes: 40)
        let third = played(ana, rafa, minutes: 80)
        let night = NightRecap.games(tonightWith: third, in: [third, first, second], calendar: calendar)
        #expect(night.map(\.id) == [first.id, second.id, third.id])
    }

    /// RF2: a fifth player swapping in for one game still plays the same night.
    @Test func threeSharedPlayersIsEnough() {
        let usual = played(ana, rafa)
        let swapped = played(ana, ["Rafa", "Carlos"], minutes: 30)
        #expect(NightRecap.games(tonightWith: usual, in: [usual, swapped], calendar: calendar).count == 2)
    }

    /// One night, one card: players drifting in over the evening chain the
    /// games together, whichever summary opens it.
    @Test func everyGameOfTheNightSeesTheSameNight() {
        let a = played(ana, rafa, minutes: 0)
        let b = played(ana, ["Rafa", "Carlos"], minutes: 30)
        let c = played(ana, ["Carlos", "Pedro"], minutes: 60)
        let all = [a, b, c]
        for game in all {
            #expect(NightRecap.games(tonightWith: game, in: all, calendar: calendar).count == 3)
        }
    }

    @Test func twoSharedPlayersIsAnotherTable() {
        let usual = played(ana, rafa)
        let other = played(ana, ["Pedro", "Carlos"], minutes: 30)
        #expect(NightRecap.games(tonightWith: usual, in: [usual, other], calendar: calendar).count == 1)
    }

    /// RF1.
    @Test func namesMatchWhateverTheCase() {
        let usual = played(ana, rafa)
        let typed = played(["ana", "LUIS"], ["Rafa", "mia"], minutes: 30)
        #expect(NightRecap.games(tonightWith: usual, in: [usual, typed], calendar: calendar).count == 2)
    }

    /// RF3.
    @Test func yesterdayAndCancelledDoNotCount() {
        let usual = played(ana, rafa)
        let yesterday = played(ana, rafa, minutes: -24 * 60)
        let cancelled = played(ana, rafa, minutes: 30, state: .cancelled)
        let playing = played(ana, rafa, minutes: 60, state: .playing)
        let night = NightRecap.games(tonightWith: usual, in: [usual, yesterday, cancelled, playing], calendar: calendar)
        #expect(night.map(\.id) == [usual.id])
    }

    // MARK: - The numbers

    /// Ana & Luis beat Rafa & Mia, Rafa & Mia beat Luis & Ana, then Ana & Rafa
    /// beat Luis & Mia. The 95 in the first game is the night's biggest round.
    private func threeGames() -> [Game] {
        [played(ana, rafa, rounds: [(95, .team1)], minutes: 0),
         played(["Luis", "Ana"], rafa, winner: .team2, rounds: [(90, .team2)], minutes: 40),
         played(["Ana", "Rafa"], ["Luis", "Mia"], rounds: [(90, .team1)], minutes: 80)]
    }

    /// RF4.
    @Test func oneGameIsNotANight() {
        let only = played(ana, rafa)
        #expect(NightRecap(tonightWith: only, in: [only], calendar: calendar) == nil)
    }

    @Test func standingsCountTonightOnly() throws {
        let games = threeGames()
        let recap = try #require(NightRecap(tonightWith: games[2], in: games, calendar: calendar))
        #expect(recap.gamesPlayed == 3)
        let wins = Dictionary(uniqueKeysWithValues: recap.standings.map { ($0.record.name, $0.record.won) })
        #expect(wins == ["Ana": 2, "Rafa": 2, "Luis": 1, "Mia": 1])
        #expect(recap.standings.allSatisfy { $0.record.played == 3 })
        #expect(recap.standings.map(\.rank) == [1, 1, 3, 3])
    }

    @Test func pairsKeepTheirRecordInAnyOrder() throws {
        let games = threeGames()
        let recap = try #require(NightRecap(tonightWith: games[0], in: games, calendar: calendar))
        #expect(recap.pairs == [
            .init(names: ["Ana", "Rafa"], won: 1, lost: 0),
            .init(names: ["Ana", "Luis"], won: 1, lost: 1),
            .init(names: ["Rafa", "Mia"], won: 1, lost: 1),
            .init(names: ["Luis", "Mia"], won: 0, lost: 1),
        ])
    }

    @Test func theBiggestRoundAndWhoScoredIt() throws {
        let games = threeGames()
        let recap = try #require(NightRecap(tonightWith: games[1], in: games, calendar: calendar))
        #expect(recap.biggestRound == .init(points: 95, names: ["Ana", "Luis"]))
    }

    @Test func aStreakNeedsTwoInARow() throws {
        let games = threeGames()
        let recap = try #require(NightRecap(tonightWith: games[2], in: games, calendar: calendar))
        #expect(recap.longestStreak == .init(name: "Rafa", wins: 2))

        let split = Array(games.prefix(2))
        let short = try #require(NightRecap(tonightWith: split[1], in: split, calendar: calendar))
        #expect(short.longestStreak == nil)
    }

    @Test func theShareTextOnlyLinksWhenThereIsALink() throws {
        let games = threeGames()
        let recap = try #require(NightRecap(tonightWith: games[2], in: games, calendar: calendar))
        #expect(NightRecap.appStoreURL == nil)
        #expect(!recap.shareText.contains("http"))
        #expect(!recap.shareText.isEmpty)
    }
}
