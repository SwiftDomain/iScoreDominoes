//
//  RoundRow.swift
//  iScore
//
//  One round in the Game screen's list: number badge, then team 1 and team 2
//  columns. Only the scoring team's column shows points.
//

import SwiftUI

struct RoundRow: View {

    let round: Round
    /// Display name of the scoring team, for VoiceOver.
    let teamName: String

    /// "Round 5, Ana & Luis, 35 points" — read aloud by VoiceOver, so it is
    /// localized like anything else on screen. The point count pluralizes on
    /// its own key.
    static func spokenLabel(for round: Round, teamName: String) -> LocalizedStringResource {
        let points = String(localized: "\(round.points) points")
        return "Round \(round.number), \(teamName), \(points)"
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(round.number)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Theme.surfaceSecondary, in: .circle)
                .overlay(Circle().strokeBorder(Theme.divider, lineWidth: 2))
                .frame(width: 44, alignment: .leading)

            cell(for: .team1)
            cell(for: .team2)
        }
        .font(.body.weight(.heavy))
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.divider).frame(height: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spokenLabel(for: round, teamName: teamName))
    }

    @ViewBuilder
    private func cell(for team: Team) -> some View {
        Group {
            if round.team == team {
                Text("+\(round.points)")
                    .foregroundStyle(Theme.palette(for: team).fill)
            } else {
                Text("—")
                    .foregroundStyle(Theme.divider)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 0) {
        RoundRow(round: Round(id: 5, number: 5, team: .team1, points: 35), teamName: "Ana & Luis")
        RoundRow(round: Round(id: 4, number: 4, team: .team2, points: 15), teamName: "Rafa & Mia")
    }
    .padding()
}
