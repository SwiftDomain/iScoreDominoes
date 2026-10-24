import Foundation
import Testing
@testable import iScore

struct SpectateSnapshotTests {

    @Test func roundTripsAGame() throws {
        let game = makeTestGame(rows: demoGameRows)
        let snapshot = SpectateSnapshot(game: game)
        #expect(SpectateSnapshot.decode(try snapshot.encoded()) == snapshot)
        #expect(snapshot.gameID == game.id)
        #expect(snapshot.isFinal == false)
    }

    @Test func aFinishedGameIsFinal() {
        let game = makeTestGame(rows: demoGameRows, state: .finished)
        #expect(SpectateSnapshot(game: game).isFinal)
    }

    /// Guests render through a Game that no context ever sees, so the copy
    /// and the cards are the scorekeeper's own and nothing reaches the store.
    @Test func theDetachedGameScoresLikeTheOriginal() {
        let game = makeTestGame(rows: demoGameRows)
        let copy = SpectateSnapshot(game: game).makeDetachedGame()
        #expect(copy.totalScore1 == game.totalScore1)
        #expect(copy.totalScore2 == game.totalScore2)
        #expect(String(localized: copy.headline) == String(localized: game.headline))
        #expect(copy.modelContext == nil)
    }

    /// Review Focus 3.
    @Test func garbageAndOversizeAreIgnored() {
        #expect(SpectateSnapshot.decode(Data("not json".utf8)) == nil)
        #expect(SpectateSnapshot.decode(Data(count: SpectateSnapshot.maxBytes + 1)) == nil)
    }

    @Test func anotherVersionIsIgnored() throws {
        var snapshot = SpectateSnapshot(game: makeTestGame())
        snapshot.version = 2
        #expect(SpectateSnapshot.decode(try snapshot.encoded()) == nil)
    }

    @Test func implausibleShapesAreIgnored() throws {
        let base = SpectateSnapshot(game: makeTestGame())
        var a = base; a.scoreTeam = [[0, 0], [5]]
        var b = base; b.scoreTeam = [[0, 0], [-5, 0]]
        var c = base; c.target = 990
        var d = base; d.team1 = ["Ana", "Luis", "Rafa"]
        var e = base; e.team2 = [String(repeating: "x", count: 40)]
        var f = base; f.scoreTeam = []
        var g = base; g.scoreTeam = [[0, 0], [SpectateSnapshot.maxRoundPoints + 1, 0]]
        for bad in [a, b, c, d, e, f, g] {
            #expect(SpectateSnapshot.decode(try bad.encoded()) == nil)
        }
    }
}
