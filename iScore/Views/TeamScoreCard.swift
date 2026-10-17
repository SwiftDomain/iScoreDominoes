//
//  TeamScoreCard.swift
//  iScore
//
//  One team's card on the Game screen: avatars, names, total, progress
//  toward the target. The leader gets a team-colored border and a gold crown.
//

import SwiftUI

struct TeamScoreCard: View {

    let game: Game
    let team: Team

    private var palette: TeamPalette { Theme.palette(for: team) }
    private var isLeader: Bool { game.leader == team }

    var body: some View {
        VStack(spacing: 6) {
            TeamAvatars(names: game.names(for: team), palette: palette)

            Text(game.displayName(for: team))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(game.total(for: team))")
                .font(DuoFont.score(42))
                .foregroundStyle(palette.fill)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            DuoProgressBar(
                value: game.progress(for: team),
                tint: palette.fill,
                previewTint: palette.wash,
                height: 10
            )

            Text("\(game.pointsToWin(for: team)) to win")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .duoCard(border: isLeader ? palette.fill : Theme.divider)
        .overlay(alignment: .topTrailing) {
            if isLeader {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.surface)
                    .frame(width: 28, height: 28)
                    .background(Theme.gold, in: .circle)
                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2))
                    .offset(x: 6, y: -12)
                    .accessibilityHidden(true)
            }
        }
        .animation(.spring, value: game.total(for: team))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isLeader ? "Leading" : "")
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return HStack(spacing: 12) {
            TeamScoreCard(game: previewer.game, team: .team1)
            TeamScoreCard(game: previewer.game, team: .team2)
        }
        .padding()
        .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
