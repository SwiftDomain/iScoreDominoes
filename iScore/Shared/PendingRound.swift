//
//  PendingRound.swift
//  iScore
//
//  One scoring tap made on the Lock Screen, on its way from the widget
//  process to the app. The widget may not touch SwiftData, so this is the
//  whole vocabulary of the handoff: add a one-sided round, or undo the last.
//

import Foundation

/// `Team` without the `.none` case: a pending round always has a side.
enum TeamSide: String, Codable, Equatable {

    case team1
    case team2

    init?(_ team: Team) {
        switch team {
        case .team1: self = .team1
        case .team2: self = .team2
        case .none: return nil
        }
    }

    var team: Team {
        switch self {
        case .team1: .team1
        case .team2: .team2
        }
    }
}

enum PendingAction: Codable, Equatable {

    case add(points: Int, team: TeamSide)
    case undo

    // Pinned keys: a file written by an older build must still decode.
    private enum CodingKeys: String, CodingKey {
        case kind, points, team
    }

    private enum Kind: String, Codable {
        case add, undo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .add:
            self = .add(
                points: try container.decode(Int.self, forKey: .points),
                team: try container.decode(TeamSide.self, forKey: .team)
            )
        case .undo:
            self = .undo
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .add(points, team):
            try container.encode(Kind.add, forKey: .kind)
            try container.encode(points, forKey: .points)
            try container.encode(team, forKey: .team)
        case .undo:
            try container.encode(Kind.undo, forKey: .kind)
        }
    }
}

struct PendingRound: Codable, Equatable, Identifiable {

    /// Identifies this tap for the applied-rounds ledger, so a drain that is
    /// interrupted after saving cannot count the same round twice.
    let id: UUID
    let gameID: UUID
    let action: PendingAction
    let date: Date

    init(id: UUID = UUID(), gameID: UUID, action: PendingAction, date: Date = Date()) {
        self.id = id
        self.gameID = gameID
        self.action = action
        self.date = date
    }
}
