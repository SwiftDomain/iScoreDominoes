//
//  ActiveGameBanner.swift
//  iScore
//
//  Green "Continue" card shown on Home while a game is in progress.
//  The whole card is the navigation link; the white button is its label.
//

import SwiftUI

/// The game in progress: teams, score, progress toward the target.
/// Only visible when a game has `inProcess == true`.
struct ActiveGameBanner: View {

    let game: Game

    /// The bar follows the leader (team 1 when tied).
    private var progressTeam: Team {
        game.leader == .none ? .team1 : game.leader
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game in progress · Double \(game.gameType.pips)")
                .duoLabel(Theme.teamAWash)

            Text("\(game.displayName(for: .team1)) vs \(game.displayName(for: .team2))")
                .font(DuoFont.body)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .firstTextBaseline) {
                Text("\(game.totalScore1) – \(game.totalScore2)")
                    .font(DuoFont.score(32))
                Spacer()
                Text("to \(Int(game.maxScore))")
                    .duoLabel(Theme.teamAWash)
            }

            DuoProgressBar(
                value: game.progress(for: progressTeam),
                tint: Theme.surface,
                track: Theme.teamAShadow,
                height: 12
            )

            Text("Continue")
                .font(DuoFont.label)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Theme.teamA)
                .frame(maxWidth: .infinity, minHeight: 46)
                .duoSolid(fill: Theme.surface, edge: Theme.teamAWash)
                .padding(.top, 4)
        }
        .foregroundStyle(Theme.surface)
        .padding(14)
        .duoSolid(fill: Theme.teamA, edge: Theme.teamAShadow, radius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the game in progress")
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return ActiveGameBanner(game: previewer.game)
            .padding()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
