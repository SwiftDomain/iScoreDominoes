//
//  ScoreLinkTests.swift
//  iScoreTests
//
//  The URL vocabulary the Lock Screen falls back to: "Other…" for a value
//  off the grid, and every control when the unlock toggle is on.
//

import Foundation
import Testing
@testable import iScore

struct ScoreLinkTests {

    private let game = UUID()

    @Test func recordRoundTrips() {
        let url = ScoreLink.record(gameID: game, points: 25, team: .team2)
        #expect(url.scheme == ScoreLink.scheme)
        #expect(ScoreLink.parse(url) == .record(gameID: game, points: 25, team: .team2))
    }

    @Test func undoRoundTrips() {
        #expect(ScoreLink.parse(ScoreLink.undo(gameID: game)) == .undo(gameID: game))
    }

    /// Review Focus 6.
    @Test func otherOpensTheAppForAValueOffTheGrid() {
        #expect(ScoreLink.parse(ScoreLink.other(gameID: game, team: .team1)) == .other(gameID: game, team: .team1))
    }

    @Test func foreignOrMalformedURLsParseToNil() {
        #expect(ScoreLink.parse(URL(string: "https://example.com/record")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=notauuid&points=25&team=team1")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=\(game.uuidString)&points=0&team=team1")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=\(game.uuidString)&points=25&team=team9")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://wat?game=\(game.uuidString)")!) == nil)
    }
}
