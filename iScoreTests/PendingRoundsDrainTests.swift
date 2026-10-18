//
//  PendingRoundsDrainTests.swift
//  iScoreTests
//
//  The app is the single owner of the store: every Lock Screen tap reaches
//  SwiftData through here, in order and exactly once.
//

import Foundation
import Testing
@testable import iScore

struct PendingRoundsDrainTests {

    private func ledger() -> AppliedRoundsLedger {
        let defaults = UserDefaults(suiteName: "drain-tests-\(UUID().uuidString)")!
        return AppliedRoundsLedger(defaults: defaults)
    }

    private func playingGame() -> Game {
        Game(gameType: .nine, maxScore: 200)
    }

    private func add(_ points: Int, _ team: TeamSide, game: UUID) -> PendingRound {
        PendingRound(gameID: game, action: .add(points: points, team: team))
    }

    private func undo(game: UUID) -> PendingRound {
        PendingRound(gameID: game, action: .undo)
    }

    @Test func appliesRoundsInOrder() {
        let game = playingGame()
        var book = ledger()
        let applied = PendingRoundsDrain.apply(
            [add(25, .team1, game: game.id), add(30, .team2, game: game.id), add(10, .team1, game: game.id)],
            to: game, ledger: &book
        )
        #expect(applied == 3)
        #expect(game.rounds.map(\.points) == [25, 30, 10])
        #expect(game.rounds.map(\.team) == [.team1, .team2, .team1])
        #expect(game.totalScore1 == 35)
        #expect(game.totalScore2 == 30)
    }

    @Test func undoTakesBackTheLastRound() {
        let game = playingGame()
        var book = ledger()
        PendingRoundsDrain.apply(
            [add(25, .team1, game: game.id), add(30, .team2, game: game.id), undo(game: game.id)],
            to: game, ledger: &book
        )
        #expect(game.rounds.map(\.points) == [25])
        #expect(game.totalScore2 == 0)
    }

    /// Review Focus 3.
    @Test func anUndoWithNothingToUndoIsANoOp() {
        let game = playingGame()
        var book = ledger()
        let applied = PendingRoundsDrain.apply([undo(game: game.id), undo(game: game.id)], to: game, ledger: &book)
        #expect(applied == 0)
        #expect(game.rounds.isEmpty)
        #expect(game.totalScore1 == 0)
        #expect(game.totalScore2 == 0)
    }

    @Test func extraUndosAfterARoundStopAtEmpty() {
        let game = playingGame()
        var book = ledger()
        PendingRoundsDrain.apply(
            [add(20, .team1, game: game.id), undo(game: game.id), undo(game: game.id)],
            to: game, ledger: &book
        )
        #expect(game.rounds.isEmpty)
        #expect(game.totalScore1 == 0)
    }

    /// Review Focus 2: a crash between saving and truncating must not
    /// count the same taps twice.
    @Test func replayingTheSameEntriesDoesNotDoubleCount() {
        let game = playingGame()
        var book = ledger()
        let entries = [add(25, .team1, game: game.id), add(30, .team2, game: game.id)]
        PendingRoundsDrain.apply(entries, to: game, ledger: &book)
        let applied = PendingRoundsDrain.apply(entries, to: game, ledger: &book)

        #expect(applied == 0)
        #expect(game.rounds.count == 2)
        #expect(game.totalScore1 == 25)
        #expect(game.totalScore2 == 30)
    }

    /// Review Focus 5.
    @Test func entriesForAnotherGameAreIgnored() {
        let game = playingGame()
        var book = ledger()
        let applied = PendingRoundsDrain.apply([add(25, .team1, game: UUID())], to: game, ledger: &book)
        #expect(applied == 0)
        #expect(game.rounds.isEmpty)
    }

    @Test func anotherGamesEntriesAreLeftForThatGame() {
        let game = playingGame()
        var book = ledger()
        let stranger = add(25, .team1, game: UUID())
        PendingRoundsDrain.apply([stranger], to: game, ledger: &book)
        #expect(book.contains(stranger.id) == false)
    }

    @Test func aFinishedGameAcceptsNothing() {
        let game = playingGame()
        game.state = .finished
        var book = ledger()
        let applied = PendingRoundsDrain.apply([add(25, .team1, game: game.id)], to: game, ledger: &book)
        #expect(applied == 0)
        #expect(game.rounds.isEmpty)
    }

    @Test func nonPositivePointsAreIgnored() {
        let game = playingGame()
        var book = ledger()
        PendingRoundsDrain.apply(
            [add(0, .team1, game: game.id), add(-5, .team2, game: game.id)], to: game, ledger: &book
        )
        #expect(game.rounds.isEmpty)
    }

    @Test func theLedgerForgetsOldIDsButKeepsRecentOnes() {
        let defaults = UserDefaults(suiteName: "ledger-\(UUID().uuidString)")!
        var book = AppliedRoundsLedger(defaults: defaults, limit: 3)
        let ids = (0..<4).map { _ in UUID() }
        book.record(ids)
        #expect(book.contains(ids[0]) == false)
        #expect(book.contains(ids[1]))
        #expect(book.contains(ids[3]))
    }

    @Test func theLedgerSurvivesANewInstanceOverTheSameDefaults() {
        let defaults = UserDefaults(suiteName: "ledger-\(UUID().uuidString)")!
        var book = AppliedRoundsLedger(defaults: defaults)
        let id = UUID()
        book.record([id])
        #expect(AppliedRoundsLedger(defaults: defaults).contains(id))
    }
}
