//
//  GameListCard.swift
//  iScore
//
//  One game in All Games: status, type and date, then a row per team.
//  The winner gets a gold trophy; losing and cancelled sides are muted.
//  The list wraps it in a link styled `.duoCard`.
//

import SwiftUI
import SwiftData

struct GameListCard: View {

    let game: Game

    /// Red (`danger`) stays reserved for destructive actions: a loss is muted.
    static func scoreColor(for outcome: TeamOutcome) -> Color {
        switch outcome {
        case .won, .playing: Theme.textPrimary
        case .lost, .cancelled: Theme.textMuted
        }
    }

    /// The bar follows the leader; muted when tied.
    private var progressTeam: Team {
        game.leader == .none ? .team1 : game.leader
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusChip(state: game.state)
                Spacer()
                Text("D\(game.gameType.pips) · \(game.timestamp.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textMuted)
            }

            teamRow(.team1)
            teamRow(.team2)

            if game.state == .playing {
                HStack(spacing: 10) {
                    DuoProgressBar(
                        value: game.progress(for: progressTeam),
                        tint: game.leader == .none ? Theme.textMuted : Theme.palette(for: game.leader).fill,
                        height: 10
                    )
                    Text("First to \(Int(game.maxScore))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func teamRow(_ team: Team) -> some View {
        let outcome = game.outcome(for: team)
        let muted = outcome == .lost || outcome == .cancelled

        return HStack(spacing: 10) {
            TeamAvatars(names: game.names(for: team), palette: Theme.palette(for: team))

            Text(game.displayName(for: team))
                .font(DuoFont.body)
                .foregroundStyle(muted ? Theme.textSecondary : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            if outcome == .won {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.gold)
                    .accessibilityLabel("Winner")
            }

            Text("\(game.total(for: team))")
                .font(DuoFont.score(22))
                .foregroundStyle(Self.scoreColor(for: outcome))
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        let games = try previewer.container.mainContext.fetch(FetchDescriptor<Game>())
        return ScrollView {
            VStack(spacing: 12) {
                ForEach(games) { game in
                    Button {} label: { GameListCard(game: game) }
                }
            }
            .buttonStyle(.duoCard)
            .padding()
        }
        .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
