//
//  RoundFeedbackBanner.swift
//  iScore
//
//  "Nice round!" confirmation that briefly replaces the Game screen's bottom
//  bar after a round is added. Tinted with the scoring team's wash color.
//  With a `GameDrama` highlight it calls out the moment instead.
//

import SwiftUI

struct RoundFeedbackBanner: View {

    let round: Round
    let game: Game
    /// A big moment in this round; nil for a plain "Nice round!".
    var highlight: GameDrama.Highlight? = nil
    /// The banner is the undo affordance for the round it is celebrating.
    /// nil leaves the banner purely informational, as other callers expect.
    var onUndo: (() -> Void)? = nil

    private var palette: TeamPalette { Theme.palette(for: round.team) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: highlight == nil ? "checkmark" : "sparkles")
                .font(.title3.weight(.black))
                .foregroundStyle(highlight == nil ? palette.fill : Theme.gold)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.map(game.dramaTitle) ?? "Nice round!")
                    .font(DuoFont.score(20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(highlight.map(game.dramaDetail) ?? game.feedbackDetail(for: round))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(palette.edge)

            Spacer(minLength: 0)

            if let onUndo {
                Button(action: onUndo) {
                    Label(String(localized: "Undo"), systemImage: "arrow.uturn.backward")
                        .duoLabel(palette.edge)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Theme.surface, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Undo this round"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(palette.wash, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: onUndo == nil ? .combine : .contain)
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
                RoundFeedbackBanner(round: blue, game: game, onUndo: {})
            }
        }
        .padding()
        .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
