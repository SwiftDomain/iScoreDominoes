//
//  GameSummaryView.swift
//  iScore
//
//  Full-screen game summary shown as a sheet when a game finishes.
//

import SwiftUI

struct GameSummaryView: View {

    let game: Game

    @Environment(\.dismiss) private var dismiss

    @State private var trophyScale: CGFloat = 0.3
    @State private var trophyOpacity: Double = 0

    var body: some View {
        ScrollView {
            VStack {

                // MARK: - Trophy Icon

                TrophyHeader(
                    trophyScale: trophyScale,
                    trophyOpacity: trophyOpacity
                )

                // MARK: - Winning Team

                WinnerSection(game: game)

                Spacer()
                    .frame(height: 24)

                // MARK: - Final Score

                FinalScoreSection(game: game)

                Spacer()
                    .frame(height: 24)

                // MARK: - Round-by-Round Scores

                RoundScoreTable(game: game)

                Spacer()
                    .frame(height: 24)

                // MARK: - Game Metadata

                GameMetadataSection(game: game)

                Spacer()
                    .frame(height: 32)

                // MARK: - Actions

                ActionButtons(game: game, dismiss: dismiss)
            }
            .padding()
            .frame(maxWidth: 700)
        }
        .scrollIndicators(.hidden)
        .background(Background())
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.5)) {
                trophyScale = 1.0
                trophyOpacity = 1.0
            }
        }
    }
}

// MARK: - Trophy Header

private struct TrophyHeader: View {

    let trophyScale: CGFloat
    let trophyOpacity: Double

    var body: some View {
        Image(systemName: "trophy.fill")
            .font(.system(size: 72))
            .foregroundStyle(Theme.accent)
            .scaleEffect(trophyScale)
            .opacity(trophyOpacity)
            .padding(.top)
    }
}

// MARK: - Winner Section

private struct WinnerSection: View {

    let game: Game

    private var winnerNames: [String] {
        game.winningTeam == .team1 ? game.team1 : game.team2
    }

    var body: some View {
        VStack {
            Text("\(game.winningTeam.description) Wins!")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(Theme.textPrimary)

            Text("\(winnerNames[0]) & \(winnerNames[1])")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Final Score

private struct FinalScoreSection: View {

    let game: Game

    var body: some View {
        HStack {
            VStack {
                Text("Team 1")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                Text(game.totalScore1, format: .number)
                    .font(.system(size: 48))
                    .bold()
                    .foregroundStyle(
                        game.winningTeam == .team1
                            ? Theme.success
                            : Theme.textPrimary
                    )
            }
            .frame(maxWidth: .infinity)

            Text("--")
                .font(.title2)
                .foregroundStyle(Theme.divider)

            VStack {
                Text("Team 2")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                Text(game.totalScore2, format: .number)
                    .font(.system(size: 48))
                    .bold()
                    .foregroundStyle(
                        game.winningTeam == .team2
                            ? Theme.success
                            : Theme.textPrimary
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Theme.surface.opacity(0.5))
        .clipShape(.rect(cornerRadius: CornerRadius.thirteen.value))
    }
}

// MARK: - Round-by-Round Table

private struct RoundScoreTable: View {

    let game: Game

    /// Filters out the initial [0,0] placeholder rows for display.
    private var scoredRounds: [(index: Int, scores: [Int])] {
        game.scoreTeam.enumerated()
            .filter { $0.element[0] > 0 || $0.element[1] > 0 }
            .map { (index: $0.offset, scores: $0.element) }
    }

    var body: some View {
        VStack {
            Text("Round-by-Round")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Column headers
            HStack {
                Text("Round")
                    .frame(width: 60, alignment: .leading)

                Spacer()

                Text("Team 1")
                    .frame(width: 80, alignment: .center)

                Spacer()

                Text("Team 2")
                    .frame(width: 80, alignment: .center)
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .padding(.bottom, 4)

            Divider()
                .overlay(Theme.divider)

            ForEach(scoredRounds, id: \.index) { round in
                HStack {
                    Text(round.index + 1, format: .number)
                        .frame(width: 60, alignment: .leading)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

                    Text(round.scores[0], format: .number)
                        .frame(width: 80, alignment: .center)
                        .foregroundStyle(
                            round.scores[0] > 0
                                ? Theme.textPrimary
                                : Theme.textSecondary
                        )

                    Spacer()

                    Text(round.scores[1], format: .number)
                        .frame(width: 80, alignment: .center)
                        .foregroundStyle(
                            round.scores[1] > 0
                                ? Theme.textPrimary
                                : Theme.textSecondary
                        )
                }

                Divider()
                    .overlay(Theme.divider)
            }
        }
        .padding()
        .background(Theme.surface.opacity(0.5))
        .clipShape(.rect(cornerRadius: CornerRadius.thirteen.value))
    }
}

// MARK: - Game Metadata

private struct GameMetadataSection: View {

    let game: Game

    private var gameTypeLabel: String {
        game.gameType == .six ? "Double Six" : "Double Nine"
    }

    var body: some View {
        VStack(alignment: .leading) {
            MetadataRow(label: "Game Type", value: gameTypeLabel)
            MetadataRow(
                label: "Score to Win",
                value: game.maxScore.formatted(.number.precision(.fractionLength(0)))
            )
            MetadataRow(
                label: "Date",
                value: game.timestamp.formatted(date: .long, time: .omitted)
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface.opacity(0.5))
        .clipShape(.rect(cornerRadius: CornerRadius.thirteen.value))
    }
}

private struct MetadataRow: View {

    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Text(value)
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: - Action Buttons

private struct ActionButtons: View {

    let game: Game
    let dismiss: DismissAction

    var body: some View {
        VStack {
            ShareLink(
                item: shareImage,
                preview: SharePreview(
                    "Game Results",
                    image: shareImage
                )
            ) {
                Label("Share Results", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.surface)
                    .foregroundStyle(Theme.textPrimary)
                    .clipShape(.rect(cornerRadius: CornerRadius.thirteen.value))
            }

            Button("Done", systemImage: "checkmark") {
                dismiss()
            }
            .bold()
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.accent)
            .foregroundStyle(Theme.background)
            .clipShape(.rect(cornerRadius: CornerRadius.thirteen.value))
        }
    }

    /// Renders a shareable summary image using ImageRenderer.
    @MainActor
    private var shareImage: Image {
        let renderer = ImageRenderer(content: ShareableGameSummary(game: game))
        renderer.scale = 3.0
        if let cgImage = renderer.cgImage {
            return Image(decorative: cgImage, scale: 3.0)
        }
        return Image(systemName: "trophy.fill")
    }
}

// MARK: - Shareable Summary (rendered to image)

/// A simplified view rendered via ImageRenderer for sharing.
private struct ShareableGameSummary: View {

    let game: Game

    private var winnerNames: [String] {
        game.winningTeam == .team1 ? game.team1 : game.team2
    }

    private var gameTypeLabel: String {
        game.gameType == .six ? "Double Six" : "Double Nine"
    }

    var body: some View {
        VStack {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("\(game.winningTeam.description) Wins!")
                .font(.title)
                .bold()

            Text("\(winnerNames[0]) & \(winnerNames[1])")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
                .frame(height: 16)

            HStack {
                Text("Team 1: \(game.totalScore1)")
                    .frame(maxWidth: .infinity)

                Text("Team 2: \(game.totalScore2)")
                    .frame(maxWidth: .infinity)
            }
            .font(.title3)

            Spacer()
                .frame(height: 8)

            Text("\(gameTypeLabel) | Score to \(game.maxScore, format: .number.precision(.fractionLength(0)))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("iScore Dominoes")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(width: 360)
        .background(.white)
    }
}

// MARK: - Preview

#Preview {
    do {
        let previewer = try Previewer()

        // Simulate a finished game for the preview.
        previewer.game.scoreTeam.append([120, 0])
        previewer.game.scoreTeam.append([0, 45])
        previewer.game.scoreTeam.append([85, 0])
        previewer.game.state = .finished
        previewer.game.inProcess = false

        return GameSummaryView(game: previewer.game)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
