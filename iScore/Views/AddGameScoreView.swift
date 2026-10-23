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
    @Environment(\.dynamicTypeSize) private var typeSize

    let game: Game
    let team: Team

    @State private var entry = ScoreEntry()
    /// The last spoken answer or refusal, or the reason a command did nothing here.
    @State private var notice: String?
    /// What the mic has to say for itself, shown in the same band as `notice`.
    @State private var micLine: String?
    @AppStorage(OwnerIdentity.nameKey) private var ownerName: String = ""

    private var palette: TeamPalette { Theme.palette(for: team) }

    /// An answer to something the user just said outranks the mic's idle state.
    /// A live session outranks both — see `show(_:)`.
    private var voiceLine: String? { notice ?? micLine }

    /// "us"/"we" resolves through the owner the Settings screen stored.
    private var voiceContext: ScoreContext {
        let trimmed = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return game.scoreContext(owner: trimmed.isEmpty ? nil : trimmed)
    }

    private var voicePermissions: VoiceScoring.Permissions {
        VoiceScoring.Permissions(canScore: game.state == .playing, canUndo: game.canUndo)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                topRow

                TeamSpeechBubble(
                    names: game.names(for: team),
                    palette: palette,
                    text: "We dominoed! How many points did we make?"
                )
                .padding(.top, 6)

                ScoreWell(entry: entry, palette: palette, accessibilityLabel: "Points for \(game.displayName(for: team))")

                Text(game.projectionSummary(adding: entry.value ?? 0, to: team))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .opacity(entry.value == nil ? 0 : 1)
                    .accessibilityHidden(entry.value == nil)

                // The team is known here, so a bare number is enough. The bar speaks its own
                // answers; this screen only makes them readable.
                VoiceScoreBar(
                    context: voiceContext,
                    permissions: voicePermissions,
                    answers: game.voiceAnswers,
                    assumedTeam: team,
                    showsText: false,
                    onOutcome: handle,
                    onPrompt: show
                )

                // One band, always the same height, holding either the mic's own line or
                // this screen's answer. Reserved rather than conditional, so the keypad
                // never slides out from under a thumb that is mid-entry, and bounded, so
                // the longest reason cannot push the keys off a small phone.
                Text(voiceLine ?? "")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    // Bounded at ordinary sizes so the keys stay in reach; unbounded at
                    // accessibility sizes, where a truncated reason is worse than a scroll.
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .top)
                    .accessibilityHidden(voiceLine == nil)

                ScoreKeypad(entry: $entry)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        // Any keypad interaction retires a stale notice.
        .onChange(of: entry) { notice = nil }
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
                previewTint: palette.wash,
                label: game.progressLabel(for: team)
            )
        }
    }

    // MARK: - Actions

    /// The mic's own line. Nothing here clears `notice` on a timer, so without
    /// this a refusal would still be on screen through the whole next session,
    /// hiding `Listening…`, the transcript, and why that session heard nothing.
    private func show(_ report: VoiceBarState.Report) {
        if report.isLive { notice = nil }
        micLine = report.line
    }

    private func handle(_ outcome: VoiceScoring.Outcome) {
        notice = nil
        switch outcome {
        case let .recorded(points, spokenTeam):
            // An explicit team in the sentence outranks the sheet's. This sheet shows one team
            // only, so the other team is refused, never scored here unseen.
            guard spokenTeam == team else {
                let other = game.displayName(for: spokenTeam)
                notice = String(localized: "That's for \(other). Close this and say it again.")
                return
            }
            // Replace, never append, then take the Add button's own path.
            entry.set(points)
            // Fail safe: never record digits typed earlier if `set` declined the value.
            guard entry.value == points else { return }
            addScore()
        case .undone:
            // The round being entered does not exist yet, so there is nothing to undo here.
            notice = String(localized: "Close this first, then undo the last round")
        case .confirmEnd, .confirmCancel:
            // Ending a game from a score-entry sheet would be two decisions in one tap.
            // The sheet stays open so the line can be read.
            notice = String(localized: "Close this first, then end the game.")
        case let .said(text), let .refused(text):
            notice = text
        case .askTeam:
            notice = VoiceScoring.notUnderstood
        }
    }

    private func addScore() {
        notice = nil
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
