//
//  RoundFeedbackBanner.swift
//  iScore
//
//  "Nice round!" confirmation that briefly replaces the Game screen's bottom
//  bar after a round is added. Tinted with the scoring team's wash color.
//

import SwiftUI

struct RoundFeedbackBanner: View {

    let round: Round
    let game: Game

    private var palette: TeamPalette { Theme.palette(for: round.team) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.title3.weight(.black))
                .foregroundStyle(palette.fill)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nice round!")
                    .font(DuoFont.score(20))
                Text(game.feedbackDetail(for: round))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(palette.edge)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(palette.wash, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        let game = previewer.game
        return VStack(spacing: 12) {
            if let last = game.rounds.last {
                RoundFeedbackBanner(round: last, game: game)
            }
            if let blue = game.rounds.last(where: { $0.team == .team2 }) {
                RoundFeedbackBanner(round: blue, game: game)
            }
        }
        .padding()
        .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
