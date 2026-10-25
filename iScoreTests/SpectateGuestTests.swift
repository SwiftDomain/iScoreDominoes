import Foundation
import SwiftData
import Testing
@testable import iScore

struct SpectateGuestTests {

    private func snapshot(_ game: Game) -> SpectateSnapshot { SpectateSnapshot(game: game) }

    private func data(_ game: Game) throws -> Data { try snapshot(game).encoded() }

    private let playing = makeTestGame(rows: demoGameRows)
    private let finished = makeTestGame(rows: demoGameRows, state: .finished)
    private let cancelled = makeTestGame(rows: demoGameRows, state: .cancelled)

    // MARK: - Reducer

    @Test func aSnapshotMakesTheGuestLive() throws {
        let phase = SpectateGuest.reduce(.searching, .received(try data(playing)))
        #expect(phase == .live(snapshot(playing)))
    }

    /// Review Focus 3: a bad message never replaces a good score.
    @Test func garbageLeavesThePhaseAlone() {
        let live = SpectateGuest.Phase.live(snapshot(playing))
        #expect(SpectateGuest.reduce(live, .received(Data("nope".utf8))) == live)
        #expect(SpectateGuest.reduce(.searching, .received(Data())) == .searching)
    }

    @Test func aFinishedFinalSnapshotFinishes() throws {
        #expect(SpectateGuest.reduce(.searching, .received(try data(finished))) == .finished(snapshot(finished)))
    }

    /// A cancelled game is over but there is nothing worth saving.
    @Test func aCancelledFinalSnapshotIsNotFinished() throws {
        #expect(SpectateGuest.reduce(.searching, .received(try data(cancelled))) == .live(snapshot(cancelled)))
    }

    /// Review Focus 2: a dropped host is never shown as live.
    @Test func losingTheHostWhileLiveIsLost() {
        #expect(SpectateGuest.reduce(.live(snapshot(playing)), .disconnected) == .lost(snapshot(playing)))
        #expect(SpectateGuest.reduce(.searching, .disconnected) == .searching)
        #expect(SpectateGuest.reduce(.lost(nil), .disconnected) == .lost(nil))
    }

    @Test func aFinishedGameStaysFinishedWithoutTheHost() {
        let done = SpectateGuest.Phase.finished(snapshot(finished))
        #expect(SpectateGuest.reduce(done, .disconnected) == done)
    }

    @Test func reconnectingChangesNothing() {
        let lost = SpectateGuest.Phase.lost(snapshot(playing))
        #expect(SpectateGuest.reduce(lost, .reconnecting) == lost)
    }

    @Test func aFreshSnapshotEndsTheLostState() throws {
        let phase = SpectateGuest.reduce(.lost(snapshot(playing)), .received(try data(playing)))
        #expect(phase == .live(snapshot(playing)))
    }

    /// The host started the next game: guests follow it.
    @Test func aNewGameReplacesTheFinishedOne() throws {
        let next = makeTestGame(rows: [[0, 0]], team1: ["Ana", "Rafa"], team2: ["Luis", "Mia"])
        let phase = SpectateGuest.reduce(.finished(snapshot(finished)), .received(try data(next)))
        #expect(phase == .live(snapshot(next)))
    }

    // MARK: - Status

    @Test func everyPhaseSaysWhereItStands() {
        let cases: [(SpectateGuest.Phase, String, String)] = [
            (.searching, "Looking for the game…", "Buscando la partida…"),
            (.live(snapshot(playing)), "Live", "En vivo"),
            (.lost(snapshot(playing)), "Lost connection. Reconnecting…", "Se perdió la conexión. Reconectando…"),
            (.finished(snapshot(finished)), "Final score", "Resultado final"),
            (.live(snapshot(cancelled)), "Game cancelled", "Partida cancelada"),
        ]
        for (phase, english, spanish) in cases {
            #expect(String(localized: SpectateGuest.status(for: phase)) == english)
            #expect(localized(SpectateGuest.status(for: phase), in: "es") == spanish)
        }
    }

    // MARK: - Saving

    @MainActor private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Game.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @MainActor @Test func savingAFinishedGameAddsOneGameAndReusesPlayers() throws {
        let context = try makeContext()
        let ana = Player(name: "ana")
        context.insert(ana)

        let saved = SpectateSave.save(snapshot(finished), existing: [ana], in: context)

        let games = try context.fetch(FetchDescriptor<Game>())
        let players = try context.fetch(FetchDescriptor<Player>())
        #expect(saved != nil)
        #expect(games.count == 1)
        #expect(players.count == 4)
        #expect(games.first?.state == .finished)
        #expect(games.first?.inProcess == false)
        #expect(games.first?.totalScore1 == 105)
    }

    @MainActor @Test func aGameStillPlayingIsNeverSaved() throws {
        let context = try makeContext()
        #expect(SpectateSave.save(snapshot(playing), existing: [], in: context) == nil)
        #expect(SpectateSave.save(snapshot(cancelled), existing: [], in: context) == nil)
        #expect(try context.fetch(FetchDescriptor<Game>()).isEmpty)
    }

    /// Review Focus 4: the same game, already here through iCloud or a second
    /// tap, is never saved twice.
    @MainActor @Test func theSameGameIsNotSavedTwice() throws {
        let context = try makeContext()
        SpectateSave.save(snapshot(finished), existing: [], in: context)
        let games = try context.fetch(FetchDescriptor<Game>())
        #expect(SpectateSave.isAlreadySaved(snapshot(finished), in: games))
        #expect(SpectateSave.save(snapshot(finished), existing: [], in: context) == nil)
        #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
    }

    /// The saved game keeps the host's id, so a copy that arrives later
    /// through iCloud is recognisably the same game.
    @MainActor @Test func aSavedGameKeepsTheHostsID() throws {
        let context = try makeContext()
        let saved = SpectateSave.save(snapshot(finished), existing: [], in: context)
        #expect(saved?.id == finished.id)
        let sameGameDifferentNames = makeTestGame(rows: [[0, 0]], team1: ["X"], state: .finished)
        #expect(!SpectateSave.isAlreadySaved(snapshot(finished), in: [sameGameDifferentNames]))
        #expect(SpectateSave.isAlreadySaved(snapshot(finished), in: [saved!]))
    }

    /// Two rows with one id can only be the same game twice; the earliest stays.
    @Test func duplicatesByIDAreFound() {
        let first = makeTestGame(state: .finished, timestamp: .now.addingTimeInterval(-60))
        let copy = SpectateSnapshot(game: first).makeDetachedGame()
        copy.timestamp = .now
        let other = makeTestGame(state: .finished)
        let extras = GameDedupe.extras(in: [copy, other, first])
        #expect(extras.count == 1)
        #expect(extras.first === copy)
    }

    @Test func aDifferentScoreIsADifferentGame() {
        let other = makeTestGame(rows: [[0, 0], [10, 0]], state: .finished)
        #expect(!SpectateSave.isAlreadySaved(snapshot(finished), in: [other]))
        #expect(SpectateSave.isAlreadySaved(snapshot(finished), in: [finished]))
    }
}
