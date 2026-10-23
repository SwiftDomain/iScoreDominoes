//
//  Game+Editing.swift
//  iScore
//
//  Editing and deleting rounds, per-team outcomes, and safe game deletion.
//  A `Round` points at its `scoreTeam` row by index (`Round.id`); a stale
//  round (index out of range) is ignored rather than crashing.
//

import Foundation
import SwiftData

/// How a team's game turned out, for list styling.
enum TeamOutcome: Equatable {
    case playing, won, lost, cancelled
}

extension Game {

    // MARK: - Editing rounds

    /// Replaces a round's points. Ignores non-positive points: removing a
    /// round is `deleteRound`, so no hidden 0-point rows are created.
    func editRound(_ round: Round, to points: Int) {
        guard points > 0, let column = column(for: round.team),
              scoreTeam.indices.contains(round.id), scoreTeam[round.id].count == 2 else { return }
        scoreTeam[round.id][column] = points
    }

    /// Removes a round's row, so later rounds renumber and Undo keeps taking
    /// back the last round on screen.
    func deleteRound(_ round: Round) {
        guard scoreTeam.indices.contains(round.id) else { return }
        scoreTeam.remove(at: round.id)
    }

    /// The team's total if `round` scored `points` instead.
    func total(for team: Team, replacing round: Round, with points: Int) -> Int {
        guard round.team == team else { return total(for: team) }
        return total(for: team) - round.points + points
    }

    func editProjectionSummary(for round: Round, newPoints: Int) -> LocalizedStringResource {
        projection(
            from: total(for: round.team),
            to: total(for: round.team, replacing: round, with: newPoints)
        )
    }

    /// "105 → 140 · 60 to win" / "105 → 200 · Wins the game!"
    func projection(from current: Int, to projected: Int) -> LocalizedStringResource {
        let target = Int(maxScore)
        let outcome = projected >= target
            ? String(localized: "Wins the game!")
            : String(localized: "\(target - projected) to win")
        return "\(current) → \(projected) · \(outcome)"
    }

    private func column(for team: Team) -> Int? {
        switch team {
        case .team1: 0
        case .team2: 1
        case .none: nil
        }
    }

    // MARK: - Outcome

    func outcome(for team: Team) -> TeamOutcome {
        switch state {
        case .playing: .playing
        case .cancelled: .cancelled
        case .finished: winningTeam == team ? .won : .lost
        }
    }

    /// "Double 9 · First to 200"
    var setupSummary: String {
        "\(gameType.title) · First to \(Int(maxScore))"
    }
}

extension Round {

    /// Edit Score speech bubble.
    var editPrompt: String {
        "Fixing round \(number)? What should it be?"
    }

    /// Edit Score label above the number well.
    var editLabel: String {
        "Round \(number) · was +\(points)"
    }
}

extension ModelContext {

    /// `Game.players` uses a cascade delete rule, but players are shared
    /// between games: detach them first so deleting a game never deletes them.
    func deleteGameKeepingPlayers(_ game: Game) {
        game.players?.removeAll()
        delete(game)
    }
}
