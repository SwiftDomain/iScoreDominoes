//
//  QuickStatsBar.swift
//  iScore
//
//  Aggregated quick stats shown at the bottom of the home screen.
//

import SwiftUI
import SwiftData

/// Shows aggregate game statistics across all players.
struct QuickStatsBar: View {

    let totalGames: Int
    let totalWins: Int
    let winPercentage: Double

    var body: some View {
        HStack {
            StatItem(
                value: "\(totalGames)",
                label: "Games"
            )

            Divider()
                .frame(height: 30)
                .overlay(Theme.divider)

            StatItem(
                value: "\(totalWins)",
                label: "Wins"
            )

            Divider()
                .frame(height: 30)
                .overlay(Theme.divider)

            StatItem(
                value: "\(Int(winPercentage))%",
                label: "Win Rate"
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.surface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 12))
    }
}

/// A single stat item with value and label.
private struct StatItem: View {

    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
