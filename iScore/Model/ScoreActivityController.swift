//
//  ScoreActivityController.swift
//  iScore
//
//  The app half of the Lock Screen scoreboard: it starts the activity for a
//  game in progress, drains the taps the widget left behind, and republishes
//  the authoritative state. Everything it decides lives in tested types
//  (`PendingRoundsDrain`, `ScoreboardState`); this is plumbing.
//

import Foundation
import SwiftData
import ActivityKit

@MainActor
final class ScoreActivityController {

    static let shared = ScoreActivityController()

    private var ledger = AppliedRoundsLedger(defaults: AppGroup.defaults)

    private func activity(for game: Game) -> Activity<ScoreboardActivityAttributes>? {
        Activity<ScoreboardActivityAttributes>.activities.first { $0.attributes.gameID == game.id }
    }

    private func state(for game: Game) -> ScoreboardState {
        ScoreboardState.make(
            from: game,
            requiresUnlock: LockScreenScoring.requiresUnlock(AppGroup.defaults)
        )
    }

    // MARK: - Lifecycle

    /// Starts the activity for a game in progress, or refreshes the one
    /// already running for it.
    func start(for game: Game) async {
        guard game.state == .playing,
              ActivityAuthorizationInfo().areActivitiesEnabled
        else {
            await end(game)
            return
        }
        if activity(for: game) != nil {
            await refresh(game)
            return
        }

        let attributes = ScoreboardActivityAttributes(
            gameID: game.id,
            name1: game.displayName(for: .team1),
            name2: game.displayName(for: .team2),
            gameType: game.gameType
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state(for: game), staleDate: nil)
        )
    }

    func refresh(_ game: Game) async {
        guard let activity = activity(for: game) else { return }
        guard game.state == .playing else {
            await end(game)
            return
        }
        await activity.update(
            ActivityContent(state: state(for: game), staleDate: nil)
        )
    }

    func end(_ game: Game) async {
        guard let activity = activity(for: game) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    /// Ends every activity, whichever game it belongs to — used when the
    /// game that owned one is gone.
    func endAll() async {
        for activity in Activity<ScoreboardActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Draining

    /// Applies the Lock Screen taps waiting in the App Group file to `game`,
    /// saves, and republishes the activity. Returns how many rounds changed.
    @discardableResult
    func drain(into game: Game, context: ModelContext) -> Int {
        guard let store = PendingRoundsStore.shared,
              let entries = try? store.drain(), !entries.isEmpty
        else { return 0 }

        let changed = PendingRoundsDrain.apply(entries, to: game, ledger: &ledger)
        guard changed > 0 else { return 0 }

        try? context.save()
        Task { await refresh(game) }
        return changed
    }
}
