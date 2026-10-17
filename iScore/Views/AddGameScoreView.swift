//
//  AddGameScoreView.swift
//  iScore
//
//  Created by BeastMode on 2/2/24.
//
//  Sheet for adding a round's points to one team: the team "asks" for its
//  points, a keypad enters them, and the new total is previewed before adding.
//

import SwiftUI
import SwiftData

struct AddGameScoreView: View {

    @Environment(\.dismiss) private var dismiss

    let game: Game
    let team: Team

    @State private var entry = ScoreEntry()

    private var palette: TeamPalette { Theme.palette(for: team) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                topRow
                speechBubble
                numberWell

                Text(game.projectionSummary(adding: entry.value ?? 0, to: team))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .opacity(entry.value == nil ? 0 : 1)
                    .accessibilityHidden(entry.value == nil)

                ScoreKeypad(entry: $entry)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(Background())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 2)

                Button(entry.buttonTitle, action: addScore)
                    .buttonStyle(.duo(palette))
                    .disabled(entry.value == nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: 500)
            }
            .background(Theme.background)
        }
    }

    // MARK: - Pieces

    private var topRow: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textMuted)
            }
            .accessibilityLabel("Close")

            DuoProgressBar(
                value: game.progress(for: team),
                preview: Double(game.total(for: team) + (entry.value ?? 0)) / game.maxScore,
                tint: palette.fill,
                previewTint: palette.wash
            )
        }
    }

    private var speechBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            TeamAvatars(names: game.names(for: team), palette: palette, size: 40)
                .padding(.top, 6)

            Text("We dominoed! How many points did we make?")
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoCard(edge: 2)
        }
        .padding(.top, 6)
    }

    private var numberWell: some View {
        Text(entry.digits.isEmpty ? "0" : entry.digits)
            .font(DuoFont.score(52))
            .foregroundStyle(entry.value == nil ? Theme.textMuted : Theme.textPrimary)
            .contentTransition(.numericText())
            .animation(.snappy, value: entry)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(Theme.surfaceSecondary, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(entry.value == nil ? Theme.divider : palette.fill, lineWidth: 2)
            )
            .accessibilityElement()
            .accessibilityLabel("Points for \(game.displayName(for: team))")
            .accessibilityValue(entry.digits.isEmpty ? "None" : entry.digits)
    }

    // MARK: - Actions

    private func addScore() {
        guard let value = entry.take() else { return }
        game.addRound(value, for: team)
        dismiss()
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return AddGameScoreView(game: previewer.game, team: .team1)
            .modelContainer(previewer.container)
            .fontDesign(.rounded)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
