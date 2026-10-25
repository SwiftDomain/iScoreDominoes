//
//  ScoreLinkHandler.swift
//  iScore
//
//  Where an iscoredominoes:// link lands: the Lock Screen mic, or a link
//  written by an earlier version (a recorded round, undo, "Other…"). Scoring
//  goes through the same pending file as a Lock Screen tap, so the ordering
//  and exactly-once rules are the ones already tested.
//

import Foundation
import SwiftData

@MainActor
enum ScoreLinkHandler {

    /// What the app should show after handling `url`, if anything.
    enum Outcome: Equatable {
        /// Open this game's Add Score sheet for this team.
        case openAddScore(gameID: UUID, team: TeamSide)
        /// Open this game with its mic listening: the Lock Screen mic tap.
        case startVoice(gameID: UUID)
        case handled
        case ignored
    }

    @discardableResult
    static func handle(_ url: URL, context: ModelContext) -> Outcome {
        guard let action = ScoreLink.parse(url) else { return .ignored }

        switch action {
        case let .other(gameID, team):
            return .openAddScore(gameID: gameID, team: team)

        case let .voice(gameID):
            return .startVoice(gameID: gameID)

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

/// Carries a deep link's request — open Add Score, or listen — from the app
/// entry point to the game's own screen, which owns that sheet and that mic.
@MainActor
@Observable
final class ScoreLinkRouter {

    enum Request: Equatable {
        case addScore(TeamSide)
        case listen
    }

    struct Pending: Equatable {
        let gameID: UUID
        let request: Request

        init(gameID: UUID, request: Request) {
            self.gameID = gameID
            self.request = request
        }

        /// Nil for an outcome that needs no screen.
        init?(_ outcome: ScoreLinkHandler.Outcome) {
            switch outcome {
            case let .openAddScore(gameID, team): self.init(gameID: gameID, request: .addScore(team))
            case let .startVoice(gameID): self.init(gameID: gameID, request: .listen)
            case .handled, .ignored: return nil
            }
        }
    }

    var pending: Pending?
    /// The game whose screen is up, so a link for it is taken there rather
    /// than pushing a second copy of the screen.
    var showingGameID: UUID?

    /// Hands `pending` to its game, once.
    func take(for gameID: UUID) -> Request? {
        guard let pending, pending.gameID == gameID else { return nil }
        self.pending = nil
        return pending.request
    }

    /// Whether Home must push the game's screen for `pending`.
    func needsPush(for gameID: UUID) -> Bool {
        showingGameID != gameID
    }
}
