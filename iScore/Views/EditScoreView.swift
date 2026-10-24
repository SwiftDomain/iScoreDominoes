//
//  EditScoreView.swift
//  iScore
//
//  Created by BeastMode on 2/8/24.
//
//  Sheet for fixing one round (long-press on the Game screen). Mirrors Add
//  score: the keypad only produces positive points, and removing a round is
//  the trash button, which deletes its row so Undo keeps working.
//

import SwiftUI
import SwiftData

struct EditScoreView: View {

    @Environment(\.dismiss) private var dismiss

    let game: Game
    let round: Round

    @State private var entry = ScoreEntry()
    @State private var showDeleteConfirmation = false

    private var palette: TeamPalette { Theme.palette(for: round.team) }

    /// The team's total without this round, and with the points typed so far
    /// (or the round's current points while nothing is typed).
    private var baseTotal: Int { game.total(for: round.team, replacing: round, with: 0) }
    private var previewTotal: Int { game.total(for: round.team, replacing: round, with: entry.value ?? round.points) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textMuted)

                    DuoProgressBar(
                        value: Double(baseTotal) / game.maxScore,
                        preview: Double(previewTotal) / game.maxScore,
                        tint: palette.fill,
                        previewTint: palette.wash
                    )
                }

                TeamSpeechBubble(names: game.names(for: round.team), palette: palette, text: round.editPrompt)
                    .padding(.top, 6)

                VStack(spacing: 8) {
                    Text(round.editLabel)
                        .duoLabel()

                    ScoreWell(entry: entry, palette: palette, accessibilityLabel: "New points for round \(round.number)")
                }

                Text(game.editProjectionSummary(for: round, newPoints: entry.value ?? round.points))
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

                HStack(alignment: .top, spacing: 10) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.danger)
                            .frame(width: 54, height: 46)
                    }
                    .buttonStyle(.duoCard)
                    .accessibilityLabel("Delete round")
                    .confirmationDialog(
                        "Delete round \(round.number)?",
                        isPresented: $showDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete round", role: .destructive, action: deleteRound)
                    } message: {
                        Text("Removes +\(round.points) from \(game.displayName(for: round.team)).")
                    }

                    Button(entry.title(.save), action: save)
                        .buttonStyle(.duo(palette))
                        .disabled(entry.value == nil)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: 500)
            }
            .background(Theme.background)
        }
    }

    // MARK: - Actions

    private func save() {
        guard let value = entry.take() else { return }
        game.editRound(round, to: value)
        dismiss()
    }

    private func deleteRound() {
        game.deleteRound(round)
        dismiss()
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        let round = previewer.game.rounds[2]
        return EditScoreView(game: previewer.game, round: round)
            .modelContainer(previewer.container)
            .fontDesign(.rounded)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
