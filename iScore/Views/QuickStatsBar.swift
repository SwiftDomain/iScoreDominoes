//
//  QuickStatsBar.swift
//  iScore
//
//  Aggregated quick stats shown at the bottom of the home screen.
//

import SwiftUI
import SwiftData

/// Shows aggregate game statistics across all players as three tiles.
struct QuickStatsBar: View {

    let totalGames: Int
    let totalWins: Int
    let winPercentage: Double

    var body: some View {
        HStack(spacing: 8) {
            StatTile(icon: "square.stack.fill", tint: Theme.teamB, value: "\(totalGames)", label: "Games")
            StatTile(icon: "trophy.fill", tint: Theme.gold, value: "\(totalWins)", label: "Wins")
            StatTile(icon: "target", tint: Theme.streak, value: "\(Int(winPercentage))%", label: "Win rate")
        }
    }
}

/// A single stat: colored icon, big number, label.
private struct StatTile: View {

    let icon: String
    let tint: Color
    let value: String
    let label: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(value)
                .font(DuoFont.score(20))
                .foregroundStyle(Theme.textPrimary)

            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .duoCard(edge: 2)
        .accessibilityElement(children: .combine)
    }
}
