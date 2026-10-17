//
//  TeamSeatsCard.swift
//  iScore
//
//  One team on New Game: a colored "TEAM 1" label and a row per seat.
//  Tapping a seat opens the player picker for it.
//

import SwiftUI

struct TeamSeatsCard: View {

    let team: Team
    /// The two names in this team's seats ("" when empty).
    let names: [String]
    let onPick: (PlayerSeat) -> Void

    private var palette: TeamPalette { Theme.palette(for: team) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(team.description)
                .duoLabel(palette.edge)
                .padding(.bottom, 2)

            ForEach(0..<2, id: \.self) { position in
                let seat = PlayerSeat(team: team, position: position)
                Button {
                    onPick(seat)
                } label: {
                    SeatRow(
                        name: names[position],
                        fill: position == 0 ? palette.fill : palette.edge,
                        plusTint: palette.fill
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(seat.title): \(names[position].isEmpty ? "empty" : names[position])")
                .accessibilityHint("Pick a player")

                if position == 0 {
                    Rectangle()
                        .fill(Theme.divider)
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .duoCard()
    }
}

/// Avatar (or a dashed "+" when empty), name, chevron.
private struct SeatRow: View {

    let name: String
    let fill: Color
    let plusTint: Color

    var body: some View {
        HStack(spacing: 12) {
            if name.isEmpty {
                Image(systemName: "plus")
                    .font(.body.weight(.heavy))
                    .foregroundStyle(plusTint)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(Theme.textMuted, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                    .accessibilityHidden(true)
            } else {
                PlayerAvatar(name: name, fill: fill)
            }

            Text(name.isEmpty ? "Add player" : name)
                .font(DuoFont.body)
                .foregroundStyle(name.isEmpty ? Theme.textMuted : Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(Theme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}

#Preview {
    VStack(spacing: 10) {
        TeamSeatsCard(team: .team1, names: ["Ana", "Luis"]) { _ in }
        TeamSeatsCard(team: .team2, names: ["Rafa", ""]) { _ in }
    }
    .padding()
}
