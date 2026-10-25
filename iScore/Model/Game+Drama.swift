//
//  Game+Drama.swift
//  iScore
//
//  What a `GameDrama.Highlight` says, on screen and out loud. Spanish uses
//  the table's own words: capicúa, zapato, remontada.
//

import Foundation

extension Game {

    func dramaTitle(_ highlight: GameDrama.Highlight) -> LocalizedStringResource {
        switch highlight {
        case .capicua: "Capicúa!"
        case .biggestRound: "Biggest round tonight!"
        case .comeback: "Comeback!"
        case .shutout: "Zapato!"
        case .comebackWin: "Comeback win!"
        case .lastRoundWin: "Won it in the last round!"
        case .streak: "On a streak!"
        }
    }

    func dramaDetail(_ highlight: GameDrama.Highlight) -> LocalizedStringResource {
        switch highlight {
        case let .capicua(team):
            "\(displayName(for: team)) closed it at both ends"
        case let .biggestRound(team, points):
            "\(displayName(for: team)) +\(points)"
        case let .comeback(team, deficit):
            "\(displayName(for: team)) were down \(deficit) and now lead"
        case let .shutout(winner):
            "\(displayName(for: winner == .team1 ? .team2 : .team1)) didn't score"
        case let .comebackWin(_, deficit):
            "Won from \(deficit) down"
        case let .lastRoundWin(team):
            "\(displayName(for: team)) were behind until the end"
        case let .streak(name, wins):
            "\(name): \(wins) wins in a row"
        }
    }

    /// "Title. Detail", in `locale` — the voice language, for the spoken line.
    func dramaLine(_ highlight: GameDrama.Highlight, in locale: Locale) -> String {
        "\(dramaTitle(highlight).resolved(in: locale)) \(dramaDetail(highlight).resolved(in: locale))."
    }
}
