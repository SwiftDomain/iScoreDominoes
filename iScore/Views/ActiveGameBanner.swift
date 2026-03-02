//
//  ActiveGameBanner.swift
//  iScore
//
//  Prominent banner shown when a game is in progress.
//  Tapping navigates directly to the active GameView.
//

import SwiftUI

/// A card that shows the active game's current score.
/// Only visible when a game has `inProcess == true`.
struct ActiveGameBanner: View {

    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "play.fill")
                    .foregroundStyle(Theme.accent)

                Text("Resume Game")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack {
                PlayerPairLabel(
                    player1: game.team1.first ?? "?",
                    player2: game.team1.last ?? "?"
                )

                Text("vs")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.caption)

                PlayerPairLabel(
                    player1: game.team2.first ?? "?",
                    player2: game.team2.last ?? "?"
                )

                Spacer()

                Text("\(game.totalScore1) – \(game.totalScore2)")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("Double \(game.gameType.rawValue) · Score to win: \(game.maxScore, format: .number.precision(.fractionLength(0)))")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding()
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
        )
    }
}

/// Shows two player names side-by-side, truncating if needed.
struct PlayerPairLabel: View {

    let player1: String
    let player2: String

    var body: some View {
        Text("\(player1) & \(player2)")
            .font(.subheadline)
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
