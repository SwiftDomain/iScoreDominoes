//
//  GameSummaryView.swift
//  iScore
//
//  Shown as a sheet when a team reaches the target: a "lesson complete"
//  celebration with the final score, round count and margin, then every
//  round (newest first) as on the Game screen.
//

import SwiftUI
import SwiftData

struct GameSummaryView: View {

    let game: Game
    /// Called with the new game after "Next game" creates it; the owner navigates to it.
    var onNextGame: (Game) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Player.name) private var players: [Player]

    @State private var shareImage: Image?
    @State private var isSpeaking = false

    private var winner: Team { game.winningTeam }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TrophyBurst()

                VStack(spacing: 4) {
                    Text(game.headline)
                        .font(DuoFont.score(28))
                        .foregroundStyle(winner == .none ? Theme.textPrimary : Theme.palette(for: winner).edge)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("\(game.setupSummary) · \(game.timestamp.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textMuted)
                }

                HStack(spacing: 8) {
                    SummaryStatTile(
                        label: "Final",
                        value: "\(game.totalScore1)–\(game.totalScore2)",
                        palette: TeamPalette(fill: Theme.gold, edge: Theme.goldShadow, wash: Theme.surfaceSecondary)
                    )
                    SummaryStatTile(
                        label: "Rounds",
                        value: "\(game.rounds.count)",
                        palette: TeamPalette(fill: Theme.learn, edge: Theme.learnShadow, wash: Theme.surfaceSecondary)
                    )
                    SummaryStatTile(
                        label: "Won by",
                        value: "\(game.lead)",
                        palette: TeamPalette(fill: Theme.streak, edge: Theme.streakShadow, wash: Theme.surfaceSecondary)
                    )
                }

                SummaryRounds(game: game)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Background())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 2)

                HStack(alignment: .top, spacing: 10) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("Game results", image: shareImage)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Theme.teamB)
                                .frame(width: 54, height: 46)
                        }
                        .buttonStyle(.duoCard)
                        .accessibilityLabel("Share results")
                    }

                    // Neutral on purpose: "Next game" carries the colour, and Done no longer
                    // paints team-2 blue over a team-1 win.
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(DuoFont.label)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.duoCard)

                    Button("Next game", systemImage: "mic.fill") {
                        isSpeaking = true
                    }
                    .buttonStyle(.duo(Theme.palette(for: .team1)))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: 500)
            }
            .background(Theme.background)
        }
        .task {
            shareImage = renderShareImage()
        }
        // The night keeps its settings: seed with this game's, not the saved defaults.
        .voiceGameSheet(
            isPresented: $isSpeaking,
            players: players,
            defaults: { (type: game.gameType, target: Int(game.maxScore)) },
            onConfirm: startNext
        )
    }

    private func startNext(_ resolved: ResolvedGame) {
        let next = GameFactory.make(resolved, existing: players, in: context)
        dismiss()
        onNextGame(next)
    }

    /// Renders the shareable card once, instead of on every body update.
    private func renderShareImage() -> Image? {
        let renderer = ImageRenderer(content: ShareableGameSummary(game: game))
        renderer.scale = 3
        return renderer.cgImage.map { Image(decorative: $0, scale: 3) }
    }
}

/// "Rounds" with each team's avatars and total as column headers.
private struct SummaryRounds: View {

    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rounds")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(game.rounds.count) played")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.textMuted)
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: 44, height: 1)
                columnHeader(for: .team1)
                columnHeader(for: .team2)
            }
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.divider).frame(height: 2)
            }

            ForEach(game.rounds.reversed()) { round in
                RoundRow(round: round, teamName: game.displayName(for: round.team))
            }
        }
    }

    private func columnHeader(for team: Team) -> some View {
        HStack(spacing: 6) {
            TeamAvatars(names: game.names(for: team), palette: Theme.palette(for: team), size: 22)
            Text("\(game.total(for: team))")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.displayName(for: team)): \(game.total(for: team))")
    }
}

// MARK: - Shareable Summary (rendered to image)

/// The card people share: wordmark, trophy, winner, team-colored scores.
private struct ShareableGameSummary: View {

    let game: Game

    var body: some View {
        VStack(spacing: 12) {
            Text("dominoes")
                .font(DuoFont.score(22))
                .foregroundStyle(Theme.teamA)

            Image(systemName: "trophy.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.surface)
                .frame(width: 68, height: 68)
                .background(Theme.gold, in: .circle)

            Text(game.headline)
                .font(DuoFont.score(26))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                score(for: .team1)
                score(for: .team2)
            }

            Text(game.setupSummary)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(24)
        .frame(width: 360)
        .background(Theme.surface)
        .fontDesign(.rounded)
        .environment(\.colorScheme, .light)
    }

    private func score(for team: Team) -> some View {
        VStack(spacing: 2) {
            Text("\(game.total(for: team))")
                .font(DuoFont.score(34))
                .foregroundStyle(Theme.palette(for: team).fill)
            Text(game.displayName(for: team))
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .duoCard(edge: 2, border: game.winningTeam == team ? Theme.palette(for: team).fill : Theme.divider)
    }
}

// MARK: - Preview

#Preview {
    do {
        let previewer = try Previewer()

        // Finish the demo game for the preview.
        previewer.game.addRound(95, for: .team1)
        previewer.game.state = .finished
        previewer.game.inProcess = false

        return GameSummaryView(game: previewer.game)
            .modelContainer(previewer.container)
            .fontDesign(.rounded)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
