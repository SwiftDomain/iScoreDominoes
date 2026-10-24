//
//  SpectateSnapshot.swift
//  iScore
//
//  What a shared game sends to the phones watching it: the whole game, every
//  time it changes. Games are small, so there are no diffs to get out of step.
//  Whatever arrives is checked before it is believed — a guest only ever sees
//  a snapshot that could have come from a real game.
//

import Foundation

struct SpectateSnapshot: Codable, Equatable {

    static let currentVersion = 1
    static let maxBytes = 64 * 1024
    static let maxRounds = 500
    static let maxRoundPoints = 1000
    /// Sanity bounds, not today's input rules: players named before the
    /// 15-character cap and targets set before today's ranges are real games.
    static let maxNameLength = 64
    static let targetBounds = 1...1000

    var version: Int
    var gameID: UUID
    var gameType: GameType
    var target: Int
    var team1: [String]
    var team2: [String]
    var scoreTeam: [[Int]]
    var state: GameState
    /// The game is over and this is its last word.
    var isFinal: Bool

    init(game: Game) {
        version = Self.currentVersion
        gameID = game.id
        gameType = game.gameType
        target = Int(game.maxScore)
        team1 = game.team1
        team2 = game.team2
        scoreTeam = game.scoreTeam
        state = game.state
        isFinal = game.state != .playing
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Nil for anything too big, unreadable, from another version, or not
    /// shaped like a real game. The guest keeps its last good state instead.
    static func decode(_ data: Data) -> SpectateSnapshot? {
        guard data.count <= maxBytes,
              let snapshot = try? JSONDecoder().decode(SpectateSnapshot.self, from: data),
              snapshot.version == currentVersion,
              snapshot.isPlausible else { return nil }
        return snapshot
    }

    var isPlausible: Bool {
        let namesFit = [team1, team2].allSatisfy { names in
            names.count <= 2 && names.allSatisfy { $0.count <= Self.maxNameLength }
        }
        let roundsFit = !scoreTeam.isEmpty
            && scoreTeam.count <= Self.maxRounds + 1
            && scoreTeam.allSatisfy { row in
                row.count == 2 && row.allSatisfy { (0...Self.maxRoundPoints).contains($0) }
            }
        return Self.targetBounds.contains(target) && namesFit && roundsFit
    }

    /// A Game for the guest's screen that is never inserted into a context:
    /// the scoreboard reads it like any other game, and the store never sees it.
    func makeDetachedGame() -> Game {
        let game = Game(gameType: gameType, maxScore: Double(target), id: gameID)
        game.team1 = team1
        game.team2 = team2
        game.scoreTeam = scoreTeam
        game.state = state
        game.inProcess = state == .playing
        return game
    }
}
