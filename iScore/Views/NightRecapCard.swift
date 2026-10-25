//
//  NightRecapCard.swift
//  iScore
//
//  The night's card, rendered to an image and shared to the group chat, and
//  the sheet that shows and shares it. Built for a thumbnail in a chat
//  thread: big numerals, few words, high contrast — and Duo, so it looks
//  like the app.
//

import SwiftUI

/// The card itself. Fixed width so the rendered image is the same everywhere.
struct NightRecapCard: View {

    let recap: NightRecap

    static let width: CGFloat = 360
    private static let standingsShown = 6
    private static let pairsShown = 4

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("dominoes")
                    .font(DuoFont.score(22))
                    .foregroundStyle(Theme.teamA)
                Text("Tonight · \(recap.gamesPlayed) games")
                    .duoLabel()
                Text(recap.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }

            section("Standings") {
                ForEach(Array(recap.standings.prefix(Self.standingsShown).enumerated()), id: \.offset) { _, standing in
                    standingRow(standing)
                }
            }

            section("Pairs") {
                ForEach(Array(recap.pairs.prefix(Self.pairsShown).enumerated()), id: \.offset) { index, pair in
                    pairRow(pair, palette: Theme.palette(for: index.isMultiple(of: 2) ? .team1 : .team2))
                }
            }

            if recap.biggestRound != nil || recap.longestStreak != nil {
                HStack(alignment: .top, spacing: 10) {
                    if let big = recap.biggestRound {
                        stat("Biggest round", value: "\(big.points)", caption: big.names.joined(separator: " & "),
                             palette: TeamPalette(fill: Theme.gold, edge: Theme.goldShadow, wash: Theme.surfaceSecondary))
                    }
                    if let streak = recap.longestStreak {
                        stat("Streak", value: "\(streak.wins)", caption: streak.name,
                             palette: TeamPalette(fill: Theme.streak, edge: Theme.streakShadow, wash: Theme.surfaceSecondary))
                    }
                }
            }
        }
        .padding(20)
        .frame(width: Self.width)
        .background(Theme.surface)
        .fontDesign(.rounded)
        .environment(\.colorScheme, .light)
    }

    private func section<Content: View>(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .duoLabel()
            VStack(spacing: 6) { content() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Rank, name and wins as a big numeral; the leader on a gold edge.
    private func standingRow(_ standing: Standing) -> some View {
        let leads = standing.rank == 1 && standing.record.won > 0
        return HStack(spacing: 10) {
            Text("\(standing.rank)")
                .font(DuoFont.body)
                .foregroundStyle(leads ? Theme.surface : Theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(leads ? Theme.gold : Theme.surfaceSecondary, in: .circle)
            Text(standing.record.name)
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Text("\(standing.record.won)")
                .font(DuoFont.score(28))
                .foregroundStyle(leads ? Theme.goldShadow : Theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .duoCard(edge: 2, border: leads ? Theme.gold : Theme.divider)
    }

    private func pairRow(_ pair: NightRecap.Pair, palette: TeamPalette) -> some View {
        HStack(spacing: 10) {
            Text(pair.names.joined(separator: " & "))
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Text("\(pair.won)–\(pair.lost)")
                .font(DuoFont.score(22))
                .foregroundStyle(Theme.surface)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(palette.fill, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .duoCard(edge: 2)
    }

    private func stat(_ label: LocalizedStringResource, value: String, caption: String, palette: TeamPalette) -> some View {
        VStack(spacing: 4) {
            SummaryStatTile(label: label, value: value, palette: palette)
            Text(caption)
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Shows the card and shares it as an image.
struct NightRecapView: View {

    let recap: NightRecap

    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?

    var body: some View {
        ScrollView {
            NightRecapCard(recap: recap)
                .duoCard()
                .padding(16)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Background())
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(DuoFont.label)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.duoCard)

                if let image {
                    ShareLink(item: image, message: Text(recap.shareText),
                              preview: SharePreview("Night recap", image: image)) {
                        Label("Share the night", systemImage: "square.and.arrow.up")
                            .font(DuoFont.label)
                            .foregroundStyle(Theme.surface)
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.duo(Theme.palette(for: .team1)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.background)
        }
        .task { image = render() }
    }

    /// 2x, per the spec: sharp in a chat thread, small enough to send.
    private func render() -> Image? {
        let renderer = ImageRenderer(content: NightRecapCard(recap: recap))
        renderer.scale = 2
        return renderer.cgImage.map { Image(decorative: $0, scale: 2) }
    }
}
