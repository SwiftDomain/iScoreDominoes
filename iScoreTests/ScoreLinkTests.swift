//
//  ScoreLinkTests.swift
//  iScoreTests
//
//  The URL vocabulary the Lock Screen opens the app with: the mic today;
//  record, undo and "Other…" from activities an earlier version started.
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

    @Test func voiceRoundTrips() {
        let url = ScoreLink.voice(gameID: game)
        #expect(url.scheme == ScoreLink.scheme)
        #expect(ScoreLink.parse(url) == .voice(gameID: game))
    }

    @Test func foreignOrMalformedURLsParseToNil() {
        #expect(ScoreLink.parse(URL(string: "https://example.com/record")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=notauuid&points=25&team=team1")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=\(game.uuidString)&points=0&team=team1")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=\(game.uuidString)&points=25&team=team9")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://wat?game=\(game.uuidString)")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://voice")!) == nil)
    }
}

/// How a link's request reaches the game's own screen.
@MainActor
struct ScoreLinkRouterTests {

    private let game = UUID()

    @Test func theMicLinkAsksTheGameToListen() {
        #expect(ScoreLinkRouter.Pending(.startVoice(gameID: game)) == .init(gameID: game, request: .listen))
        #expect(ScoreLinkRouter.Pending(.openAddScore(gameID: game, team: .team2)) == .init(gameID: game, request: .addScore(.team2)))
        #expect(ScoreLinkRouter.Pending(.handled) == nil)
        #expect(ScoreLinkRouter.Pending(.ignored) == nil)
    }

    /// One tap, one listening session: the request is taken once, and only
    /// by its own game.
    @Test func theRequestIsTakenOnceByItsOwnGame() {
        let router = ScoreLinkRouter()
        router.pending = .init(gameID: game, request: .listen)

        #expect(router.take(for: UUID()) == nil)
        #expect(router.take(for: game) == .listen)
        #expect(router.take(for: game) == nil)
    }

    /// The phone was locked on this game: its screen takes the request
    /// instead of a second copy being pushed on top.
    @Test func aGameAlreadyOnScreenIsNotPushedAgain() {
        let router = ScoreLinkRouter()
        #expect(router.needsPush(for: game))

        router.showingGameID = game
        #expect(router.needsPush(for: game) == false)
        #expect(router.needsPush(for: UUID()))
    }
}
