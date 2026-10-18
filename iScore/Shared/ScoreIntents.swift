//
//  ScoreIntents.swift
//  iScore
//
//  What a Lock Screen button runs. `LiveActivityIntent` keeps this in the
//  widget process — no app launch, no unlock — so it appends the tap to the
//  pending-rounds file and updates the activity optimistically. The app
//  drains the file and has the last word on the score.
//

import Foundation
import AppIntents
import ActivityKit

struct RecordRoundIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Record a round"
    static var description = IntentDescription("Adds points to a team without unlocking the phone.")

    @Parameter(title: "Game") var gameID: String
    @Parameter(title: "Points") var points: Int
    @Parameter(title: "Team") var team: String

    init() { }

    init(gameID: UUID, points: Int, team: TeamSide) {
        self.gameID = gameID.uuidString
        self.points = points
        self.team = team.rawValue
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: gameID), let side = TeamSide(rawValue: team) else {
            return .result()
        }
        try? PendingRoundsStore.shared?.append(
            PendingRound(gameID: id, action: .add(points: points, team: side))
        )
        await ScoreActivityUpdate.apply(gameID: id) { $0.applyingRound(points, for: side) }
        return .result()
    }
}

struct UndoRoundIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Undo the last round"
    static var description = IntentDescription("Takes back the round just recorded.")

    @Parameter(title: "Game") var gameID: String

    init() { }

    init(gameID: UUID) {
        self.gameID = gameID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: gameID) else { return .result() }
        try? PendingRoundsStore.shared?.append(PendingRound(gameID: id, action: .undo))
        await ScoreActivityUpdate.apply(gameID: id) { $0.applyingUndo() }
        return .result()
    }
}

/// Moves the running activity to its next state straight away, so the Lock
/// Screen answers the tap instead of waiting for the app to wake up.
enum ScoreActivityUpdate {

    static func apply(gameID: UUID, _ next: (ScoreboardState) -> ScoreboardState) async {
        for activity in Activity<ScoreboardActivityAttributes>.activities
        where activity.attributes.gameID == gameID {
            await activity.update(ActivityContent(state: next(activity.content.state), staleDate: nil))
        }
    }
}
