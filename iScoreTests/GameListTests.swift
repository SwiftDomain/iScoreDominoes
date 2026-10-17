import Foundation
import SwiftData
import Testing
@testable import iScore

struct GameListTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    @Test func filters() {
        let playing = makeTestGame(state: .playing)
        let finished = makeTestGame(state: .finished)
        let cancelled = makeTestGame(state: .cancelled)
        let games = [playing, finished, cancelled]

        #expect(games.filter(GameFilter.all.includes).count == 3)
        #expect(games.filter(GameFilter.playing.includes) == [playing])
        #expect(games.filter(GameFilter.finished.includes) == [finished])
        #expect(games.filter(GameFilter.cancelled.includes) == [cancelled])
        #expect(GameFilter.allCases.map(\.title) == ["All", "Playing", "Finished", "Cancelled"])
    }

    @Test func searchMatchesAnyPlayer() {
        let game = makeTestGame(team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"])
        #expect(game.matches(search: ""))
        #expect(game.matches(search: "  "))
        #expect(game.matches(search: "mia"))
        #expect(game.matches(search: "Lu"))
        #expect(!game.matches(search: "Tito"))
    }

    /// The old search indexed team1[0] and team1[1] directly and crashed on short teams.
    @Test func searchToleratesShortTeams() {
        let game = makeTestGame(team1: ["Ana"], team2: [])
        #expect(game.matches(search: "ana"))
        #expect(!game.matches(search: "Rafa"))
    }

    @Test func groupsByMonthKeepingOrder() {
        let games = [
            makeTestGame(timestamp: date(10, 16)),
            makeTestGame(timestamp: date(10, 2)),
            makeTestGame(timestamp: date(9, 28))
        ]
        let sections = GameList.sections(games, calendar: calendar)
        #expect(sections.count == 2)
        #expect(sections.map(\.games.count) == [2, 1])
        #expect(sections[0].month == date(10, 1).startOfMonth(calendar))
        #expect(sections[1].games == [games[2]])
    }

    @Test func counts() {
        #expect(GameList.countLabel(1) == "1 game")
        #expect(GameList.countLabel(12) == "12 games")
        #expect(GameList.summary(total: 12, playing: 1) == "12 games · 1 in progress")
        #expect(GameList.summary(total: 3, playing: 0) == "3 games")
    }
}

private extension Date {
    func startOfMonth(_ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: self)!.start
    }
}

@MainActor
struct GameDeletionTests {

    /// `Game.players` cascades on delete, but players are shared between games.
    @Test func deletingAGameKeepsItsPlayers() throws {
        let container = try ModelContainer(
            for: Game.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let ana = Player(name: "Ana")
        let luis = Player(name: "Luis")

        let first = Game(gameType: .nine, maxScore: 200)
        let second = Game(gameType: .nine, maxScore: 200)
        context.insert(first)
        context.insert(second)
        first.players?.append(contentsOf: [ana, luis])
        second.players?.append(contentsOf: [ana, luis])
        try context.save()

        context.deleteGameKeepingPlayers(first)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Player>()).count == 2)
        #expect(second.players?.count == 2)
    }
}
