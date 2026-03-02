//
//  RecentGameCard.swift
//  iScore
//
//  Compact card for the horizontal recent games scroll on the home screen.
//

import SwiftUI

/// Displays a completed game's result in a compact card.
struct RecentGameCard: View {

    let game: Game

    private var outcomeIcon: String {
        game.state == .finished ? "checkmark.circle.fill" : "xmark.circle"
    }

    private var outcomeColor: Color {
        game.state == .finished ? Theme.success : Theme.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(game.team1.first ?? "?") & \(game.team1.last ?? "?")")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: outcomeIcon)
                    .foregroundStyle(outcomeColor)
                    .font(.caption)
            }

            Text("vs \(game.team2.first ?? "?") & \(game.team2.last ?? "?")")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            Divider()
                .overlay(Theme.divider)

            HStack {
                Text("\(game.totalScore1) – \(game.totalScore2)")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Text("D\(game.gameType.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(game.timestamp.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding()
        .frame(width: 200)
        .background(Theme.surface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.divider, lineWidth: 0.5)
        )
    }
}
