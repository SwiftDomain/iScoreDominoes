//
//  ScoreboardState+Game.swift
//  iScore
//
//  The authoritative content state, built from the store. App-side only —
//  the widget has `ScoreboardState` but never `Game`.
//

import Foundation

extension ScoreboardState {

    static func make(from game: Game) -> Self {
        let recent = game.rounds
            .suffix(recentLimit)
            .map { $0.team == .team1 ? $0.points : -$0.points }

        return ScoreboardState(
            target: Int(game.maxScore),
            total1: game.totalScore1,
            total2: game.totalScore2,
            recent: recent
        )
    }
}
