//
//  GameList.swift
//  iScore
//
//  All Games: status filters, player search, month sections and counts.
//

import Foundation

enum GameFilter: CaseIterable, Identifiable {
    case all, playing, finished, cancelled

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .playing: "Playing"
        case .finished: "Finished"
        case .cancelled: "Cancelled"
        }
    }

    func includes(_ game: Game) -> Bool {
        switch self {
        case .all: true
        case .playing: game.state == .playing
        case .finished: game.state == .finished
        case .cancelled: game.state == .cancelled
        }
    }
}

extension Game {

    /// Any player's name contains the search text; empty search matches all.
    func matches(search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return (team1 + team2).contains { $0.localizedStandardContains(query) }
    }
}

/// Games that started in the same month, in list order.
struct GameMonthSection: Identifiable {

    let month: Date
    let games: [Game]

    var id: Date { month }

    /// "October 2026"
    var title: String {
        month.formatted(.dateTime.month(.wide).year())
    }
}

enum GameList {

    /// Groups games (already sorted newest first) by month, keeping order.
    static func sections(_ games: [Game], calendar: Calendar = .current) -> [GameMonthSection] {
        var sections: [GameMonthSection] = []
        for game in games {
            let month = calendar.dateInterval(of: .month, for: game.timestamp)?.start ?? game.timestamp
            if let last = sections.last, last.month == month {
                sections[sections.count - 1] = GameMonthSection(month: month, games: last.games + [game])
            } else {
                sections.append(GameMonthSection(month: month, games: [game]))
            }
        }
        return sections
    }

    /// "1 game" / "12 games"
    static func countLabel(_ count: Int) -> String {
        count == 1 ? "1 game" : "\(count) games"
    }

    /// "12 games · 1 in progress"
    static func summary(total: Int, playing: Int) -> String {
        playing > 0 ? "\(countLabel(total)) · \(playing) in progress" : countLabel(total)
    }
}
