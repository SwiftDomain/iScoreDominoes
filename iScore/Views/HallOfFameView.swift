//
//  HallOfFameView.swift
//  iScore
//
//  Created by BeastMode on 2/9/24.
//
//  Players ranked by wins, then win rate: the top three on a podium,
//  everyone else in rows below.
//

import SwiftUI
import SwiftData

struct HallOfFameView: View {

    @Query(sort: \Player.name) private var players: [Player]

    var body: some View {
        let board = Leaderboard.split(Leaderboard.standings(players.map(PlayerRecord.init)))

        ScrollView {
            VStack(spacing: 0) {
                SheetHeader(title: "Hall of fame")
                    .padding(.bottom, 8)

                if board.podium.isEmpty {
                    EmptyHallOfFame()
                } else {
                    PodiumView(leaders: board.podium)
                }

                if !board.rest.isEmpty {
                    Rectangle()
                        .fill(Theme.divider)
                        .frame(height: 2)

                    ForEach(Array(board.rest.enumerated()), id: \.offset) { _, standing in
                        LeaderRow(standing: standing)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Background())
    }
}

/// A player below the podium: rank, avatar, name, record, wins.
private struct LeaderRow: View {

    let standing: Standing

    private var record: PlayerRecord { standing.record }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(standing.rank)")
                .font(.body.weight(.black))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 28)

            PlayerAvatar(name: record.name, size: 40, fill: record.played > 0 ? nil : Theme.textMuted)

            VStack(alignment: .leading, spacing: 0) {
                Text(record.name)
                    .font(DuoFont.body)
                    .foregroundStyle(record.played > 0 ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                Text(record.summary)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer(minLength: 8)

            if record.played > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(record.won)")
                        .font(DuoFont.score(22))
                        .foregroundStyle(Theme.textPrimary)
                    Text(record.won == 1 ? "Win" : "Wins")
                        .duoLabel()
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.divider).frame(height: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(standing.rank): \(record.name), \(record.winsLabel), \(record.summary)")
    }
}

/// Nobody has won a game yet.
private struct EmptyHallOfFame: View {

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.surface)
                .frame(width: 72, height: 72)
                .duoSolid(fill: Theme.gold, edge: Theme.goldShadow, radius: 20)
                .accessibilityHidden(true)

            Text("Finish a game to get on the board.")
                .font(DuoFont.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return HallOfFameView()
            .modelContainer(previewer.container)
            .fontDesign(.rounded)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
