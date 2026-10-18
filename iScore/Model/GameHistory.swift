//
//  GameHistory.swift
//  iScore
//
//  What the Lock Screen point grid learns from: the round values this user
//  actually scores, per game type.
//

import Foundation

enum GameHistory {

    /// Every round value recorded for `type`, in the order they were played.
    static func roundValues(in games: [Game], type: GameType) -> [Int] {
        games
            .filter { $0.gameType == type }
            .flatMap { $0.rounds.map(\.points) }
    }
}
