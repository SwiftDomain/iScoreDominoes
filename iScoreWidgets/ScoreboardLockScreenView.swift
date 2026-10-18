//
//  ScoreboardLockScreenView.swift
//  iScoreWidgets
//
//  The scoreboard as it appears on the Lock Screen, and — unchanged — in the
//  expanded Dynamic Island. The point grid lives HERE rather than only in
//  the island, so scoring without unlocking works on every iPhone.
//

import SwiftUI
import WidgetKit
import AppIntents

struct ScoreboardLockScreenView: View {

    let attributes: ScoreboardActivityAttributes
    let state: ScoreboardState

    var body: some View {
        // The Lock Screen gives an activity about 160pt. Names sit beside
        // their button row rather than above it, which is what keeps the
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
    private var statusLine: String {
        guard let leader = state.leader else { return "Round \(state.roundNumber)" }
        return "Round \(state.roundNumber) · \(state.pointsToWin(leader)) to win"
    }

    // MARK: - Teams

    private func teamRow(_ side: TeamSide, name: String, palette: TeamPalette) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(DuoFont.label)
                .foregroundStyle(palette.edge)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 62, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(state.grid, id: \.self) { points in
                    scoreControl(points, side: side, palette: palette)
                }
            }
        }
    }

    @ViewBuilder
    private func scoreControl(_ points: Int, side: TeamSide, palette: TeamPalette) -> some View {
        let face = ScoreButtonFace(title: "\(points)", fill: palette.fill, edge: palette.edge, height: 30)

        // With "Require unlock to score" on, the same control becomes a link,
        // so scoring costs an unlock instead of happening on the Lock Screen.
        if state.requiresUnlock {
            Link(destination: ScoreLink.record(gameID: attributes.gameID, points: points, team: side)) {
                face
            }
        } else {
            Button(intent: RecordRoundIntent(gameID: attributes.gameID, points: points, team: side)) {
                face
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            undoControl
            Link(destination: ScoreLink.other(gameID: attributes.gameID, team: .team1)) {
                ScoreButtonFace(
                    title: "Other…", fill: Theme.surfaceSecondary,
                    edge: Theme.divider, titleColor: Theme.textSecondary, height: 30
                )
            }
        }
    }

    @ViewBuilder
    private var undoControl: some View {
        let face = ScoreButtonFace(title: "Undo", fill: Theme.textMuted, edge: Theme.textSecondary, height: 30)

        if state.requiresUnlock {
            Link(destination: ScoreLink.undo(gameID: attributes.gameID)) { face }
        } else {
            Button(intent: UndoRoundIntent(gameID: attributes.gameID)) { face }
                .buttonStyle(.plain)
                .disabled(!state.canUndo)
        }
    }
}
