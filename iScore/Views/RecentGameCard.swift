//
//  RecentGameCard.swift
//  iScore
//
//  Compact card for the horizontal recent games scroll on the home screen.
//

import SwiftUI

/// A completed game's result: status chip, teams, final score, type and date.
struct RecentGameCard: View {

    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatusChip(state: game.state)
                .padding(.bottom, 2)

            Text(game.displayName(for: .team1))
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Text("vs \(game.displayName(for: .team2))")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            Text("\(game.totalScore1) – \(game.totalScore2)")
                .font(DuoFont.score(22))
                .foregroundStyle(Theme.textPrimary)

            Text("D\(game.gameType.pips) · \(game.timestamp.formatted(.dateTime.month(.abbreviated).day()))")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .frame(width: 170, alignment: .leading)
        .duoCard()
        .accessibilityElement(children: .combine)
    }
}
