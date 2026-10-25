import Foundation
@testable import iScore

/// An unmanaged game; `rows` include the `[0, 0]` seed row the app starts with.
func makeTestGame(
    _ type: GameType = .nine,
    maxScore: Double = 200,
    rows: [[Int]] = [[0, 0]],
    team1: [String] = ["Ana", "Luis"],
    team2: [String] = ["Rafa", "Mia"],
    state: GameState = .playing,
    timestamp: Date = .now
) -> Game {
    let game = Game(gameType: type, maxScore: maxScore)
    game.scoreTeam = rows
    game.team1 = team1
    game.team2 = team2
    game.state = state
    game.inProcess = state == .playing
    game.timestamp = timestamp
    return game
}

/// Same rows as the demo game in progress: Ana & Luis 105, Rafa & Mia 45.
let demoGameRows = [[0, 0], [25, 0], [0, 30], [45, 0], [0, 15], [35, 0]]

/// Resolves a localized resource in a specific language. `String(localized:)`
/// has no `locale:` overload for `LocalizedStringResource` — the locale is set
/// on the resource — so every Spanish assertion goes through here.
func localized(_ resource: LocalizedStringResource, in identifier: String) -> String {
    var resource = resource
    resource.locale = Locale(identifier: identifier)
    return String(localized: resource)
}
