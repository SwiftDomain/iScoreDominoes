//
//  ScoreboardLiveActivity.swift
//  iScoreWidgets
//
//  The Lock Screen scoreboard. The compact Dynamic Island shows the two
//  totals and nothing else; the expanded island reuses the Lock Screen view,
//  so no scoring control is exclusive to an island-equipped phone.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct ScoreboardLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScoreboardActivityAttributes.self) { context in
            ScoreboardLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ScoreboardLockScreenView(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                Text("\(context.state.total1)")
                    .font(DuoFont.body)
                    .foregroundStyle(Theme.teamA)
            } compactTrailing: {
                Text("\(context.state.total2)")
                    .font(DuoFont.body)
                    .foregroundStyle(Theme.teamB)
            } minimal: {
                minimalView(context.state)
            }
        }
    }

    /// The leader's total in their color; team 1's while tied.
    private func minimalView(_ state: ScoreboardState) -> some View {
        let side = state.leader ?? .team1
        return Text("\(state.total(side))")
            .font(DuoFont.body)
            .foregroundStyle(Theme.palette(for: side.team).fill)
    }
}
