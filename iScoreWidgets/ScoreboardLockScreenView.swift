//
//  ScoreboardLockScreenView.swift
//  iScoreWidgets
//
//  The scoreboard as it appears on the Lock Screen, and — unchanged — in the
//  expanded Dynamic Island: both totals, each recent round's score (display
//  only) and Undo. Tapping the activity opens the app to add a round.
//

import SwiftUI
import WidgetKit
import AppIntents

struct ScoreboardLockScreenView: View {

    let attributes: ScoreboardActivityAttributes
    let state: ScoreboardState

    var body: some View {
        // The Lock Screen gives an activity about 160pt. Names sit beside
        // their round row rather than above it, which is what keeps the
        // header and the Undo row from being clipped.
        VStack(alignment: .leading, spacing: 6) {
            header
            teamRow(.team1, name: attributes.name1, palette: Theme.palette(for: .team1))
            teamRow(.team2, name: attributes.name2, palette: Theme.palette(for: .team2))
            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .activityBackgroundTint(Theme.surface)
        .activitySystemActionForegroundColor(Theme.textPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(statusLine)
                // `duoLabel()` lives in the app's DuoStyle; the widget
                // reproduces it rather than pulling that file in.
                .font(DuoFont.label)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text("\(state.total1)")
                .font(DuoFont.score(20))
                .foregroundStyle(Theme.teamA)
            Text("—")
                .font(DuoFont.body)
                .foregroundStyle(Theme.textMuted)
            Text("\(state.total2)")
                .font(DuoFont.score(20))
                .foregroundStyle(Theme.teamB)
        }
    }

    /// "Round 4 · 80 to win" for the leader; no "to win" while tied.
    /// Resolved in the app's chosen language, not the widget process's.
    private var statusLine: String {
        guard let leader = state.leader else {
            return WidgetLanguage.text("Round \(state.roundNumber)")
        }
        return WidgetLanguage.text("Round \(state.roundNumber) · \(state.pointsToWin(leader)) to win")
    }

    // MARK: - Teams

    /// The latest rounds' scores, display only — the Lock Screen no longer
    /// adds points; tapping the activity opens the app for that.
    private static let roundsShown = 6

    private func teamRow(_ side: TeamSide, name: String, palette: TeamPalette) -> some View {
        let columns = state.roundColumns(limit: Self.roundsShown)
        return HStack(spacing: 6) {
            Text(name)
                .font(DuoFont.label)
                .foregroundStyle(palette.edge)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 62, alignment: .leading)

            HStack(spacing: 4) {
                if columns.isEmpty {
                    Text(WidgetLanguage.text("No rounds yet"))
                        .font(DuoFont.label)
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(columns.indices, id: \.self) { index in
                        roundCell(side == .team1 ? columns[index].team1 : columns[index].team2, palette: palette)
                    }
                    // Keep columns the same width however many rounds there are.
                    ForEach(columns.count..<Self.roundsShown, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 28)
                    }
                }
            }
        }
    }

    /// A round's points in the team's wash, or a muted dash when the other
    /// team scored that round. Not a button.
    private func roundCell(_ points: Int?, palette: TeamPalette) -> some View {
        Text(points.map { "\($0)" } ?? "—")
            .font(DuoFont.score(15))
            .foregroundStyle(points == nil ? Theme.textMuted : palette.edge)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(points == nil ? Theme.surfaceSecondary : palette.wash,
                        in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Footer

    private var footer: some View {
        undoControl
    }

    @ViewBuilder
    private var undoControl: some View {
        let face = ScoreButtonFace(title: WidgetLanguage.text("Undo"), fill: Theme.textMuted, edge: Theme.textSecondary, height: 30)

        if state.requiresUnlock {
            Link(destination: ScoreLink.undo(gameID: attributes.gameID)) { face }
        } else {
            Button(intent: UndoRoundIntent(gameID: attributes.gameID)) { face }
                .buttonStyle(.plain)
                .disabled(!state.canUndo)
        }
    }
}
