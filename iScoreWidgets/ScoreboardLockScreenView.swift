//
//  ScoreboardLockScreenView.swift
//  iScoreWidgets
//
//  The scoreboard as it appears on the Lock Screen, and — unchanged — in the
//  expanded Dynamic Island. A gold header with both totals in their team's
//  color and a bar each toward the target; below, each team's initials and
//  its score for the latest rounds (display only), and a mic that opens the
//  app listening for a score. Tapping anywhere else opens the app too.
//
//  Unlike the app's Duo screens, the Lock Screen uses light and shadow (a
//  top highlight, soft glows) so it reads as raised on a busy wallpaper.
//

import SwiftUI
import WidgetKit
import AppIntents

struct ScoreboardLockScreenView: View {

    let attributes: ScoreboardActivityAttributes
    let state: ScoreboardState

    private let team1 = Theme.palette(for: .team1)
    private let team2 = Theme.palette(for: .team2)

    var body: some View {
        // The Lock Screen gives an activity about 160pt; past that the header
        // and the rounds are clipped. Initials, not names, keep rows short.
        VStack(spacing: 0) {
            header
            HStack(spacing: 8) {
                VStack(spacing: 6) {
                    teamRow(.team1, initials: attributes.initials1 ?? Self.fallbackInitials(attributes.name1), palette: team1)
                    teamRow(.team2, initials: attributes.initials2 ?? Self.fallbackInitials(attributes.name2), palette: team2)
                }
                micControl
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            // Painted here, not only as the tint, so the expanded Dynamic
            // Island shows the same and not black.
            .background(Theme.surface)
        }
        .activityBackgroundTint(Theme.surface)
        .activitySystemActionForegroundColor(Theme.goldShadow)
    }

    /// An activity started before initials were sent: the display name's first letter.
    private static func fallbackInitials(_ name: String) -> String {
        name.first.map { String($0).uppercased() } ?? "?"
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 7) {
            HStack(alignment: .center) {
                total(state.total1, palette: team1)
                Spacer(minLength: 6)
                VStack(spacing: 1) {
                    Text(WidgetLanguage.text("Round \(state.roundNumber)"))
                        .font(DuoFont.label)
                        .tracking(0.8)
                    Text(toWinLine)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .opacity(0.9)
                }
                .textCase(.uppercase)
                .foregroundStyle(Theme.surface)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                total(state.total2, palette: team2)
            }
            HStack(spacing: 14) {
                LitBar(value: state.progress(.team1), fill: team1.fill, track: Theme.goldShadow)
                // Team 2's bar grows from the right, toward the middle.
                LitBar(value: state.progress(.team2), fill: team2.fill, track: Theme.goldShadow)
                    .scaleEffect(x: -1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
            // Gold face over a darker edge, lit from the top.
            ZStack {
                Theme.goldShadow
                Theme.gold.padding(.bottom, 4)
                LinearGradient(colors: [Theme.surface.opacity(0.4), Theme.surface.opacity(0)],
                               startPoint: .top, endPoint: .center)
                    .padding(.bottom, 4)
            }
        }
    }

    /// "95 to win" for the leader; "All tied up" while tied.
    /// Resolved in the app's chosen language, not the widget process's.
    private var toWinLine: String {
        guard let leader = state.leader else { return WidgetLanguage.text("All tied up") }
        return WidgetLanguage.text("\(state.pointsToWin(leader)) to win")
    }

    /// A total in its team's color on a white tile.
    private func total(_ value: Int, palette: TeamPalette) -> some View {
        Text("\(value)")
            .font(DuoFont.score(24))
            .foregroundStyle(palette.fill)
            .shadow(color: palette.fill.opacity(0.25), radius: 2, y: 1)
            .padding(.horizontal, 10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: Theme.goldShadow.opacity(0.6), radius: 3, y: 2)
    }

    // MARK: - Teams

    /// The latest rounds' scores, display only — the Lock Screen no longer
    /// adds points; tapping the activity opens the app for that.
    private static let roundsShown = 6

    private func teamRow(_ side: TeamSide, initials: String, palette: TeamPalette) -> some View {
        let columns = state.roundColumns(limit: Self.roundsShown)
        return HStack(spacing: 5) {
            RaisedKey(fill: palette.fill, edge: palette.edge, radius: 10) {
                Text(initials)
                    .font(DuoFont.score(13))
                    .foregroundStyle(Theme.surface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 36, height: 28)

            if columns.isEmpty {
                Text(WidgetLanguage.text("No rounds yet"))
                    .font(DuoFont.label)
                    .foregroundStyle(Theme.textSecondary)
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

    /// A round's points on a raised key in the team's wash, or a faint dash
    /// when the other team scored that round. Not a button.
    @ViewBuilder
    private func roundCell(_ points: Int?, palette: TeamPalette) -> some View {
        if let points {
            RaisedKey(fill: palette.wash, edge: palette.fill.opacity(0.55), radius: 8, drop: 3) {
                Text("\(points)")
                    .font(DuoFont.score(14))
                    .foregroundStyle(palette.edge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        } else {
            Text("—")
                .font(DuoFont.score(12))
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
        }
    }

    // MARK: - Mic

    /// Opens the app on this game with its mic already listening — the tap
    /// here is the push-to-talk tap. A Lock Screen widget cannot use the
    /// microphone itself, so this is a link, and iOS asks for the unlock.
    private var micControl: some View {
        Link(destination: ScoreLink.voice(gameID: attributes.gameID)) {
            ZStack {
                Circle().fill(team1.edge)
                Circle().fill(team1.fill).padding(.bottom, 3)
                Circle()
                    .fill(LinearGradient(colors: [Theme.surface.opacity(0.45), Theme.surface.opacity(0)],
                                         startPoint: .top, endPoint: .center))
                    .padding(.bottom, 3)
                    .padding(4)
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.surface)
                    .padding(.bottom, 3)
            }
            .frame(width: 40, height: 43)
            .shadow(color: team1.edge.opacity(0.45), radius: 5, y: 3)
        }
        .accessibilityLabel(WidgetLanguage.text("Say a score"))
    }
}

/// A Duo key: a face over a darker bottom edge, so it reads as raised.
private struct RaisedKey<Content: View>: View {
    let fill: Color
    let edge: Color
    var radius: CGFloat = 8
    var drop: CGFloat = 3
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(edge)
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill).padding(.bottom, drop)
            content.padding(.horizontal, 2).padding(.bottom, drop)
        }
    }
}

/// The game screen's progress bar look — track, fill, a light strip on top —
/// with a soft glow in the team's color.
private struct LitBar: View {
    let value: Double
    let fill: Color
    let track: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: width)
                    .overlay(alignment: .top) {
                        if width > height * 2 {
                            Capsule()
                                .fill(Theme.surface.opacity(0.45))
                                .frame(height: 2)
                                .padding(.horizontal, height * 0.6)
                                .padding(.top, height * 0.18)
                        }
                    }
                    .shadow(color: fill.opacity(0.5), radius: 4, y: 1)
            }
        }
        .frame(height: height)
    }
}
