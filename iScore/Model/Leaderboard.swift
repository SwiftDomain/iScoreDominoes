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
    var summary: String {
        guard played > 0 else { return "No finished games yet" }
        return "\(played) played · \(Int((winRate * 100).rounded()))%"
    }

    /// "9 wins" / "1 win"
    var winsLabel: String {
        won == 1 ? "1 win" : "\(won) wins"
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
