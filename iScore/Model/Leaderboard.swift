//
//  Leaderboard.swift
//  iScore
//
//  Hall of Fame ranking: by wins, then win rate. Ties share a rank
//  ("1, 1, 3"); players with no finished games sort last.
//

import Foundation

/// A player's finished-game record.
struct PlayerRecord: Equatable {

    let name: String
    let played: Int
    let won: Int

    /// 0…1
    var winRate: Double {
        played > 0 ? Double(won) / Double(played) : 0
    }

    /// "12 played · 75%"
    var summary: LocalizedStringResource {
        guard played > 0 else { return "No finished games yet" }
        return "\(played) played · \(Int((winRate * 100).rounded()))%"
    }

    /// "9 wins" / "1 win" — pluralized by the catalog, not by Swift.
    var winsLabel: LocalizedStringResource {
        "\(won) wins"
    }
}

extension PlayerRecord {
    init(_ player: Player) {
        self.init(name: player.name, played: player.gamesPlayed, won: player.gamesWon)
    }
}

struct Standing: Equatable {
    let record: PlayerRecord
    let rank: Int
}

enum Leaderboard {

    static func standings(_ records: [PlayerRecord]) -> [Standing] {
        let sorted = records.sorted { lhs, rhs in
            if (lhs.played > 0) != (rhs.played > 0) { return lhs.played > 0 }
            if lhs.won != rhs.won { return lhs.won > rhs.won }
            if lhs.winRate != rhs.winRate { return lhs.winRate > rhs.winRate }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        var standings: [Standing] = []
        for (index, record) in sorted.enumerated() {
            if let previous = standings.last, ties(previous.record, record) {
                standings.append(Standing(record: record, rank: previous.rank))
            } else {
                standings.append(Standing(record: record, rank: index + 1))
            }
        }
        return standings
    }

    /// Up to three leaders with at least one win go on the podium.
    static func split(_ standings: [Standing]) -> (podium: [Standing], rest: [Standing]) {
        let podium = Array(standings.prefix { $0.record.won > 0 }.prefix(3))
        return (podium, Array(standings.dropFirst(podium.count)))
    }

    private static func ties(_ lhs: PlayerRecord, _ rhs: PlayerRecord) -> Bool {
        (lhs.played > 0) == (rhs.played > 0) && lhs.won == rhs.won && lhs.winRate == rhs.winRate
    }
}

/// Home's "Your stats": the record of the player set as "That's me" in
/// Settings, counted as Hall of Fame counts a player — every game no longer
/// in progress is played, and a win is that player's team reaching the target.
struct OwnerStats: Equatable {

    let played: Int
    let won: Int

    /// 0–100; 0 before any game.
    var winPercentage: Double {
        played > 0 ? Double(won) / Double(played) * 100 : 0
    }

    /// Nil when nobody is set as "That's me": there is no "you" to count.
    static func compute(owner: String?, games: [Game]) -> OwnerStats? {
        guard let owner else { return nil }
        let seated = { (names: [String]) in names.contains { PlayerName.isSame($0, owner) } }
        let mine = games.filter { !$0.inProcess && seated($0.team1 + $0.team2) }
        let won = mine.filter { game in
            switch game.winningTeam {
            case .team1: seated(game.team1)
            case .team2: seated(game.team2)
            default: false
            }
        }
        return OwnerStats(played: mine.count, won: won.count)
    }
}
