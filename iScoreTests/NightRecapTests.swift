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
}
