//
//  ScoreboardLockScreenView.swift
//  iScoreWidgets
//
//  The scoreboard as it appears on the Lock Screen, and — unchanged — in the
//  expanded Dynamic Island: both totals, each recent round's score (display
//  only) and a mic that opens the app listening for a score. Tapping
//  anywhere else opens the app too.
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
        // header and the mic row from being clipped.
        VStack(alignment: .leading, spacing: 6) {
            header
            teamRow(.team1, name: attributes.name1, palette: Theme.palette(for: .team1))
            teamRow(.team2, name: attributes.name2, palette: Theme.palette(for: .team2))
            micControl
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // The app's own green, white type on it. The expanded Dynamic Island
        // keeps its black; everything here reads on both.
        .activityBackgroundTint(Theme.teamA)
        .activitySystemActionForegroundColor(Theme.surface)
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
                .foregroundStyle(Theme.surface)
            Spacer(minLength: 8)
            // Team 1's pill is its darker edge: its own fill is the background.
            total(state.total1, color: Theme.teamAShadow)
            total(state.total2, color: Theme.teamB)
        }
    }

    /// A total in white on its team's color, so the two still read as two
    /// teams on the green.
    private func total(_ value: Int, color: Color) -> some View {
        Text("\(value)")
            .font(DuoFont.score(18))
            .foregroundStyle(Theme.surface)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .background(color, in: RoundedRectangle(cornerRadius: 8))
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
                .foregroundStyle(Theme.surface)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 62, alignment: .leading)

            HStack(spacing: 4) {
                if columns.isEmpty {
                    Text(WidgetLanguage.text("No rounds yet"))
                        .font(DuoFont.label)
                        .foregroundStyle(Theme.surface)
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

    /// A round's points in the team's color on white, or a dash on the
    /// darker green when the other team scored that round. Not a button.
    private func roundCell(_ points: Int?, palette: TeamPalette) -> some View {
        Text(points.map { "\($0)" } ?? "—")
            .font(DuoFont.score(15))
            .foregroundStyle(points == nil ? Theme.teamAWash : palette.edge)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(points == nil ? Theme.teamAShadow : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Mic

    /// Opens the app on this game with its mic already listening — the tap
    /// here is the push-to-talk tap. A Lock Screen widget cannot use the
    /// microphone itself, so this is a link, and iOS asks for the unlock.
    private var micControl: some View {
        Link(destination: ScoreLink.voice(gameID: attributes.gameID)) {
            ScoreButtonFace(
                title: WidgetLanguage.text("Say a score"),
                fill: Theme.surface,
                edge: Theme.teamAShadow,
                titleColor: Theme.teamAShadow,
                height: 30,
                systemImage: "mic.fill"
            )
        }
    }
}
