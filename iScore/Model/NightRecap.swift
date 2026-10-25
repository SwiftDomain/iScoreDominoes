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

    /// Two players who sat together, and their record tonight. Names keep the
    /// spelling and seat order of their first game together.
    struct Pair: Equatable {
        let names: [String]
        let won: Int
        let lost: Int
    }

    struct BigRound: Equatable {
        let points: Int
        let names: [String]
    }

    struct Streak: Equatable {
        let name: String
        let wins: Int
    }

    let date: Date
    let gamesPlayed: Int
    let standings: [Standing]
    let pairs: [Pair]
    let biggestRound: BigRound?
    /// The longest run of wins in a row tonight; nil below 2.
    let longestStreak: Streak?

    /// Nil when the night has fewer than `minimumGames` games.
    init?(tonightWith game: Game, in games: [Game], calendar: Calendar = .current) {
        let night = Self.games(tonightWith: game, in: games, calendar: calendar)
        guard night.count >= Self.minimumGames else { return nil }
        date = game.timestamp
        gamesPlayed = night.count
        standings = Leaderboard.standings(Self.records(night))
        pairs = Self.pairs(night)
        biggestRound = Self.biggestRound(night)
        longestStreak = Self.longestStreak(night)
    }

    // MARK: - Counting

    /// Each player's games and wins tonight, under their first spelling.
    private static func records(_ night: [Game]) -> [PlayerRecord] {
        var names: [String] = []
        var played: [Int] = [], won: [Int] = []
        for game in night {
            for team in [Team.team1, .team2] {
                for name in game.names(for: team) {
                    let index = names.firstIndex { PlayerName.isSame($0, name) } ?? {
                        names.append(name); played.append(0); won.append(0)
                        return names.count - 1
                    }()
                    played[index] += 1
                    if game.winningTeam == team { won[index] += 1 }
                }
            }
        }
        return names.indices.map { PlayerRecord(name: names[$0], played: played[$0], won: won[$0]) }
    }

    private static func pairs(_ night: [Game]) -> [Pair] {
        var pairs: [Pair] = []
        for game in night {
            for team in [Team.team1, .team2] {
                let names = game.names(for: team)
                let won = game.winningTeam == team
                if let index = pairs.firstIndex(where: { isSamePair($0.names, names) }) {
                    let old = pairs[index]
                    pairs[index] = Pair(names: old.names, won: old.won + (won ? 1 : 0), lost: old.lost + (won ? 0 : 1))
                } else {
                    pairs.append(Pair(names: names, won: won ? 1 : 0, lost: won ? 0 : 1))
                }
            }
        }
        // Stable: equal records keep the order they first sat down in.
        return pairs.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.won != rhs.element.won { return lhs.element.won > rhs.element.won }
                if lhs.element.lost != rhs.element.lost { return lhs.element.lost < rhs.element.lost }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func isSamePair(_ lhs: [String], _ rhs: [String]) -> Bool {
        lhs.count == rhs.count
            && lhs.allSatisfy { name in rhs.contains { PlayerName.isSame($0, name) } }
    }

    /// The first of the largest rounds, if any round was played.
    private static func biggestRound(_ night: [Game]) -> BigRound? {
        var best: BigRound?
        for game in night {
            for round in game.rounds where round.points > (best?.points ?? 0) {
                best = BigRound(points: round.points, names: game.names(for: round.team))
            }
        }
        return best
    }

    private static func longestStreak(_ night: [Game]) -> Streak? {
        var best: Streak?
        for record in records(night) {
            var run = 0, longest = 0
            for game in night {
                let team: Team = game.team1.contains { PlayerName.isSame($0, record.name) } ? .team1
                    : game.team2.contains { PlayerName.isSame($0, record.name) } ? .team2 : .none
                guard team != .none else { continue }
                run = game.winningTeam == team ? run + 1 : 0
                longest = max(longest, run)
            }
            if longest >= 2, longest > (best?.wins ?? 0) { best = Streak(name: record.name, wins: longest) }
        }
        return best
    }

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
