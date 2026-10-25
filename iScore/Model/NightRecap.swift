//
//  NightRecap.swift
//  iScore
//
//  The night's card: which games make up the night, and every number on it.
//  A night is inferred, never stored — finished games on the same calendar
//  day that share at least three players with this one. The rule lives here
//  and is easy to change.
//

import Foundation

struct NightRecap {

    /// A night needs more than one game; one game has its own share card.
    static let minimumGames = 2
    /// Players a game must share with this one to be the same table.
    static let sharedPlayers = 3
    /// The app's App Store page, once it has one. The share text links it
    /// only when set.
    static let appStoreURL: URL? = nil

    /// The night's finished games, oldest first, `game` included when finished.
    static func games(tonightWith game: Game, in games: [Game], calendar: Calendar = .current) -> [Game] {
        let players = game.team1 + game.team2
        return games
            .filter { candidate in
                candidate.state == .finished
                    && calendar.isDate(candidate.timestamp, inSameDayAs: game.timestamp)
                    && shared(players, candidate.team1 + candidate.team2) >= sharedPlayers
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// How many of `lhs` are also in `rhs`, compared as names are elsewhere.
    private static func shared(_ lhs: [String], _ rhs: [String]) -> Int {
        lhs.filter { name in rhs.contains { PlayerName.isSame($0, name) } }.count
    }
}
