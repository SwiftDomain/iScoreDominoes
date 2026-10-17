//
//  PodiumView.swift
//  iScore
//
//  Hall of Fame's top three on gold / silver / bronze blocks, laid out
//  2nd · 1st · 3rd. Fewer leaders show fewer blocks.
//

import SwiftUI

struct PodiumView: View {

    /// Leaders in rank order (at most three).
    let leaders: [Standing]

    /// Display order: 2nd, 1st, 3rd.
    private var slots: [Int] {
        [1, 0, 2].filter { leaders.indices.contains($0) }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(slots, id: \.self) { slot in
                PodiumColumn(standing: leaders[slot], place: slot)
            }
        }
        .padding(.horizontal, 6)
    }
}

/// One leader: crown for first, avatar, name, wins, and the block.
private struct PodiumColumn: View {

    let standing: Standing
    /// 0 = tallest (center).
    let place: Int

    private var medal: TeamPalette {
        Theme.medal(forRank: standing.rank) ?? Theme.palette(for: .none)
    }

    private var blockHeight: CGFloat {
        [112, 78, 58][place]
    }

    private var avatarSize: CGFloat {
        place == 0 ? 62 : 52
    }

    var body: some View {
        VStack(spacing: 4) {
            if place == 0 {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.gold)
                    .accessibilityHidden(true)
            }

            PlayerAvatar(name: standing.record.name, size: avatarSize)

            Text(standing.record.name)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(standing.record.winsLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textMuted)

            Text("\(standing.rank)")
                .font(DuoFont.score(place == 0 ? 36 : 28))
                .foregroundStyle(Theme.surface)
                .frame(maxWidth: .infinity, minHeight: blockHeight, alignment: .top)
                .padding(.top, 8)
                .background(alignment: .bottom) {
                    VStack(spacing: 0) {
                        medal.fill
                        medal.edge.frame(height: 6)
                    }
                }
                .clipShape(.rect(topLeadingRadius: 14, topTrailingRadius: 14))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(standing.rank): \(standing.record.name), \(standing.record.winsLabel), \(standing.record.summary)")
    }
}

#Preview {
    PodiumView(leaders: Leaderboard.standings([
        PlayerRecord(name: "Ana", played: 12, won: 9),
        PlayerRecord(name: "Luis", played: 12, won: 8),
        PlayerRecord(name: "Rafa", played: 11, won: 5)
    ]))
    .padding()
}
