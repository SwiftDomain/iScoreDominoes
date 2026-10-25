//
//  ScoreboardActivityAttributes.swift
//  iScore
//
//  What the Lock Screen scoreboard shows, and the arithmetic the widget does
//  on a tap before the app has drained anything.
//
//  `recent` carries the last few round values signed by team (positive for
//  team 1, negative for team 2). The Lock Screen shows them as each round's
//  score, and they let the widget undo without opening the store — the app
//  still owns the truth and overwrites this state on every drain.
//

import Foundation
import ActivityKit

struct ScoreboardState: Codable, Hashable {

    /// How many rounds the widget can undo before it needs the app.
    static let recentLimit = 12

    var target: Int
    var total1: Int
    var total2: Int
    var recent: [Int]
    /// Every round played, not only the ones `recent` keeps. Optional so an
    /// activity started by an earlier version, which lacks it, still decodes.
    var played: Int? = nil

    // MARK: - Derived

    private var roundsPlayed: Int {
        played ?? recent.count
    }

    var roundNumber: Int {
        roundsPlayed + 1
    }

    /// Nil when tied.
    var leader: TeamSide? {
        if total1 > total2 { return .team1 }
        if total2 > total1 { return .team2 }
        return nil
    }

    func total(_ side: TeamSide) -> Int {
        switch side {
        case .team1: total1
        case .team2: total2
        }
    }

    func pointsToWin(_ side: TeamSide) -> Int {
        max(0, target - total(side))
    }

    var canUndo: Bool {
        !recent.isEmpty
    }

    /// One round as the Lock Screen shows it: the scoring team's points, and
    /// nothing for the other team.
    struct RoundColumn: Hashable {
        let team1: Int?
        let team2: Int?
    }

    /// The latest `limit` rounds, oldest first, so the newest sits on the right.
    func roundColumns(limit: Int) -> [RoundColumn] {
        recent.suffix(max(0, limit)).map { value in
            value > 0 ? RoundColumn(team1: value, team2: nil) : RoundColumn(team1: nil, team2: -value)
        }
    }

    // MARK: - Optimistic updates

    func applyingRound(_ points: Int, for side: TeamSide) -> Self {
        guard points > 0 else { return self }
        var next = self
        switch side {
        case .team1: next.total1 += points
        case .team2: next.total2 += points
        }
        next.recent = Array((recent + [side == .team1 ? points : -points]).suffix(Self.recentLimit))
        next.played = roundsPlayed + 1
        return next
    }

    func applyingUndo() -> Self {
        guard let last = recent.last else { return self }
        var next = self
        if last > 0 {
            next.total1 = max(0, total1 - last)
        } else {
            next.total2 = max(0, total2 + last)
        }
        next.recent = Array(recent.dropLast())
        next.played = max(0, roundsPlayed - 1)
        return next
    }

    // Building one from a `Game` is app-only: see
    // iScore/Model/ScoreboardState+Game.swift.
}

struct ScoreboardActivityAttributes: ActivityAttributes {

    typealias ContentState = ScoreboardState

    let gameID: UUID
    let name1: String
    let name2: String
    let gameType: GameType
}
