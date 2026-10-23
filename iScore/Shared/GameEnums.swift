//
//  GameEnums.swift
//  iScore
//
//  The two game enums both processes need. They live here, not in Game.swift,
//  because the widget extension draws team colors and point grids but must
//  never link SwiftData — see AppGroup.swift for why the store is app-only.
//

import Foundation

enum GameType: String, Codable, RawRepresentable, CaseIterable, Equatable {

    case six
    case nine

}

enum Team: Identifiable {

    case team1
    case team2
    case none

    public var id: Team { self }

    /// Shared with the widget target, which resolves it against its own
    /// bundle — see Task 7 of the two-language-settings plan.
    var description: LocalizedStringResource {

        switch self {

        case .team1:
            return "Team 1"
        case .team2:
            return "Team 2"
        case .none:
            return "Game in progress"
        }
    }
}
