//
//  ScoreLink.swift
//  iScore
//
//  The deep links the Lock Screen falls back to: "Other…" for a round the
//  grid does not carry, and every control once "Require unlock to score" is
//  on. Opening a link costs an unlock, which is exactly the point there.
//

import Foundation

enum ScoreLink {

    static let scheme = "iscoredominoes"

    enum Action: Equatable {
        case record(gameID: UUID, points: Int, team: TeamSide)
        case undo(gameID: UUID)
        case other(gameID: UUID, team: TeamSide)
    }

    private enum Host: String {
        case record, undo, other
    }

    // MARK: - Building

    static func record(gameID: UUID, points: Int, team: TeamSide) -> URL {
        url(.record, gameID: gameID, items: [
            URLQueryItem(name: "points", value: String(points)),
            URLQueryItem(name: "team", value: team.rawValue)
        ])
    }

    static func undo(gameID: UUID) -> URL {
        url(.undo, gameID: gameID, items: [])
    }

    static func other(gameID: UUID, team: TeamSide) -> URL {
        url(.other, gameID: gameID, items: [URLQueryItem(name: "team", value: team.rawValue)])
    }

    private static func url(_ host: Host, gameID: UUID, items: [URLQueryItem]) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host.rawValue
        components.queryItems = [URLQueryItem(name: "game", value: gameID.uuidString)] + items
        return components.url!
    }

    // MARK: - Parsing

    /// Nil for anything this app did not write: a foreign scheme, an unknown
    /// action, a bad id, a missing team, or a non-positive score.
    static func parse(_ url: URL) -> Action? {
        guard url.scheme == scheme,
              let host = url.host().flatMap(Host.init(rawValue:)),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        guard let gameID = value("game").flatMap(UUID.init(uuidString:)) else { return nil }

        switch host {
        case .undo:
            return .undo(gameID: gameID)
        case .other:
            guard let team = value("team").flatMap(TeamSide.init(rawValue:)) else { return nil }
            return .other(gameID: gameID, team: team)
        case .record:
            guard let team = value("team").flatMap(TeamSide.init(rawValue:)),
                  let points = value("points").flatMap(Int.init), points > 0
            else { return nil }
            return .record(gameID: gameID, points: points, team: team)
        }
    }
}
