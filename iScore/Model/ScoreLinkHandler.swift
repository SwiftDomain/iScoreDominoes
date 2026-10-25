//
//  ScoreLinkHandler.swift
//  iScore
//
//  Where an iscoredominoes:// link lands: Undo once "Require unlock to
//  score" is on, or a link written by an earlier version (a recorded round,
//  "Other…"). Scoring goes through the same pending file as a Lock Screen tap,
//  so the ordering and exactly-once rules are the ones already tested.
//

import Foundation
import SwiftData

@MainActor
enum ScoreLinkHandler {

    /// What the app should show after handling `url`, if anything.
    enum Outcome: Equatable {
        /// Open this game's Add Score sheet for this team.
        case openAddScore(gameID: UUID, team: TeamSide)
        case handled
        case ignored
    }

    @discardableResult
    static func handle(_ url: URL, context: ModelContext) -> Outcome {
        guard let action = ScoreLink.parse(url) else { return .ignored }

        switch action {
        case let .other(gameID, team):
            return .openAddScore(gameID: gameID, team: team)

        case let .record(gameID, points, team):
            append(PendingRound(gameID: gameID, action: .add(points: points, team: team)))
            drain(gameID: gameID, context: context)
            return .handled

        case let .undo(gameID):
            append(PendingRound(gameID: gameID, action: .undo))
            drain(gameID: gameID, context: context)
            return .handled
        }
    }

    private static func append(_ round: PendingRound) {
        try? PendingRoundsStore.shared?.append(round)
    }

    private static func drain(gameID: UUID, context: ModelContext) {
        let games = (try? context.fetch(FetchDescriptor<Game>())) ?? []
        guard let game = games.first(where: { $0.id == gameID }) else { return }
        ScoreActivityController.shared.drain(into: game, context: context)
    }
}

/// Carries a deep link's "open Add Score" request from the app entry point
/// to the game's own screen, which owns that sheet.
@MainActor
@Observable
final class ScoreLinkRouter {

    var pendingAddScore: (gameID: UUID, team: TeamSide)?

    /// Returns the team to open Add Score for on `gameID`, once.
    func takeAddScore(for gameID: UUID) -> Team? {
        guard let pending = pendingAddScore, pending.gameID == gameID else { return nil }
        pendingAddScore = nil
        return pending.team.team
    }
}
