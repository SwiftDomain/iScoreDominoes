//
//  PendingRoundsDrain.swift
//  iScore
//
//  Where Lock Screen taps become real rounds. The app calls this and nothing
//  else writes the score, so order is the file's order and each entry is
//  applied at most once. App-side only: the widget must never see `Game`.
//

import Foundation

enum PendingRoundsDrain {

    /// Applies `entries` to `game` in order, skipping anything already
    /// applied, anything meant for another game, and anything a finished
    /// game cannot accept. Returns how many entries changed the game.
    ///
    /// The caller saves the context — this makes no store of its own.
    @discardableResult
    static func apply(_ entries: [PendingRound], to game: Game, ledger: inout AppliedRoundsLedger) -> Int {
        var changed = 0
        var consumed: [UUID] = []

        for entry in entries {
            // Another game's taps belong to that game's drain, so leave
            // them unrecorded; the ledger must not swallow them.
            guard entry.gameID == game.id else { continue }
            consumed.append(entry.id)
            guard !ledger.contains(entry.id), game.state == .playing else { continue }

            switch entry.action {
            case let .add(points, team):
                guard points > 0 else { continue }
                let before = game.rounds.count
                game.addRound(points, for: team.team)
                if game.rounds.count != before { changed += 1 }
            case .undo:
                guard !game.rounds.isEmpty else { continue }
                game.undoLastRound()
                changed += 1
            }
        }

        ledger.record(consumed)
        return changed
    }
}
