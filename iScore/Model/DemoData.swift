//
//  DemoData.swift
//  iScore
//
//  Sample games for previews and simulator checks. Debug builds launched
//  with `-demoData` start on an in-memory store seeded with these games
//  (real data and CloudKit are left untouched). The launch-argument check in
//  `iScoreApp` is DEBUG-only; this file is not, because `#Preview` blocks
//  (via `Previewer`) also compile in Release.
//

import Foundation
import SwiftData

enum DemoData {

    static let launchArgument = "-demoData"

    /// Inserts one game in progress, three finished games (one last month)
    /// and a cancelled one, with a Player record per name (plus Carlos, who
    /// hasn't played yet). Returns the game in progress.
    @MainActor
    @discardableResult
    static func seed(into context: ModelContext) -> Game {
        let active = makeGame(
            .nine, team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"],
            rows: [[0, 0], [25, 0], [0, 30], [45, 0], [0, 15], [35, 0]],
            state: .playing, daysAgo: 0
        )
        let games = [
            active,
            makeGame(
                .nine, team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"],
                rows: [[0, 0], [120, 0], [0, 145], [80, 0]],
                state: .finished, daysAgo: 4
            ),
            makeGame(
                .six, team1: ["Rafa", "Mia"], team2: ["Tito", "Eva"],
                rows: [[0, 0], [80, 0], [0, 95]],
                state: .cancelled, daysAgo: 7
            ),
            makeGame(
                .nine, team1: ["Rafa", "Mia"], team2: ["Tito", "Eva"],
                rows: [[0, 0], [0, 60], [110, 0], [95, 0]],
                state: .finished, daysAgo: 12
            ),
            makeGame(
                .six, team1: ["Ana", "Mia"], team2: ["Luis", "Tito"],
                rows: [[0, 0], [150, 0], [0, 40], [60, 0]],
                state: .finished, daysAgo: 40
            )
        ]
        games.forEach(context.insert)

        var players: [String: Player] = [:]
        for game in games {
            for name in game.team1 + game.team2 {
                let player = players[name] ?? Player(name: name)
                players[name] = player
                game.players?.append(player)
            }
        }
        context.insert(Player(name: "Carlos"))
        // So the Home presets row has something to show.
        context.insert(GamePreset(PresetSetup(name: "Friday night", gameType: .six, target: 100,
                                              playerNames: ["Rafa", "Mia", "Tito", "Eva"])))

        return active
    }

    private static func makeGame(
        _ type: GameType, team1: [String], team2: [String],
        rows: [[Int]], state: GameState, daysAgo: Int
    ) -> Game {
        let game = Game(gameType: type, maxScore: 200)
        game.team1 = team1
        game.team2 = team2
        game.scoreTeam = rows
        game.state = state
        game.inProcess = state == .playing
        game.timestamp = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return game
    }
}
