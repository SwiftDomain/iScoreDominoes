import Testing
@testable import iScore

/// Builds an unmanaged game: scoreTeam rows include the `[0, 0]` seed row the app starts with.
private func makeGame(
    maxScore: Double = 200,
    rows: [[Int]],
    team1: [String] = ["Ana", "Luis"],
    team2: [String] = ["Rafa", "Mia"],
    state: GameState = .playing
) -> Game {
    let game = Game(gameType: .nine, maxScore: maxScore)
    game.scoreTeam = rows
    game.team1 = team1
    game.team2 = team2
    game.state = state
    return game
}

private let demoRows = [[0, 0], [25, 0], [0, 30], [45, 0], [0, 15], [35, 0]]

struct GameScoreboardTests {

    @Test func totalsAndProgress() {
        let game = makeGame(rows: demoRows)
        #expect(game.total(for: .team1) == 105)
        #expect(game.total(for: .team2) == 45)
        #expect(game.total(for: .none) == 0)
        #expect(game.progress(for: .team1) == 0.525)
        #expect(game.pointsToWin(for: .team2) == 155)
        #expect(game.leader == .team1)
        #expect(game.lead == 60)
        #expect(game.currentRoundNumber == 6)
        #expect(game.headline == "Ana & Luis lead by 60")
    }

    @Test func progressClampsPastTarget() {
        let game = makeGame(rows: [[0, 0], [230, 0]])
        #expect(game.progress(for: .team1) == 1.0)
        #expect(game.pointsToWin(for: .team1) == 0)
    }

    @Test func zeroMaxScoreIsSafe() {
        let game = makeGame(maxScore: 0, rows: demoRows)
        #expect(game.progress(for: .team1) == 0)
    }

    @Test func tieHasNoLeader() {
        let game = makeGame(rows: [[0, 0], [20, 0], [0, 20]])
        #expect(game.leader == .none)
        #expect(game.lead == 0)
        #expect(game.headline == "All tied up")
    }

    @Test func emptyGame() {
        let game = makeGame(rows: [[0, 0]])
        #expect(game.rounds.isEmpty)
        #expect(game.headline == "Let's play!")
        #expect(game.currentRoundNumber == 1)
    }

    @Test func finishedHeadline() {
        let game = makeGame(rows: [[0, 0], [200, 0]], state: .finished)
        #expect(game.headline == "Ana & Luis won!")
    }

    @Test func cancelledHeadline() {
        let game = makeGame(rows: [[0, 0], [80, 0], [0, 95]], state: .cancelled)
        #expect(game.headline == "Game cancelled")

        let empty = makeGame(rows: [[0, 0]], state: .cancelled)
        #expect(empty.headline == "Game cancelled")
    }

    @Test func statusLabelWhilePlaying() {
        #expect(makeGame(rows: demoRows).statusLabel == "Round 6 · First to 200")
        #expect(makeGame(rows: [[0, 0]]).statusLabel == "Round 1 · First to 200")
    }

    /// Once a game is over there is no next round: count the rounds played.
    @Test func statusLabelCountsRoundsWhenOver() {
        let finished = makeGame(rows: [[0, 0], [120, 0], [0, 145], [80, 0]], state: .finished)
        #expect(finished.statusLabel == "3 rounds · First to 200")

        let cancelled = makeGame(rows: [[0, 0], [80, 0]], state: .cancelled)
        #expect(cancelled.statusLabel == "1 round · First to 200")

        let cancelledEmpty = makeGame(rows: [[0, 0]], state: .cancelled)
        #expect(cancelledEmpty.statusLabel == "0 rounds · First to 200")
    }

    @Test func progressLabels() {
        let game = makeGame(rows: demoRows)
        #expect(game.progressLabel(for: .team1) == "Ana & Luis progress")
        #expect(game.progressLabel(for: .team2) == "Rafa & Mia progress")
        #expect(game.progressLabel(for: .none) == "Game progress")
    }

    @Test func roundsSkipSeedAndZeroRows() {
        let game = makeGame(rows: [[0, 0], [10, 0], [0, 0], [0, 5]])
        #expect(game.rounds.map(\.number) == [1, 2])
        #expect(game.rounds.map(\.team) == [.team1, .team2])
        #expect(game.rounds.map(\.points) == [10, 5])
        #expect(game.rounds.map(\.id) == [1, 3])
    }

    @Test func displayNameFallbacks() {
        let game = makeGame(rows: [[0, 0]], team1: [], team2: [])
        #expect(game.displayName(for: .team1) == "Team 1")
        #expect(game.displayName(for: .team2) == "Team 2")
        #expect(game.displayName(for: .none) == "")
        #expect(game.names(for: .none).isEmpty)

        game.team2 = ["Solo"]
        #expect(game.displayName(for: .team2) == "Solo")
    }

    @Test func initials() {
        #expect(Game.initials(of: "ana") == "A")
        #expect(Game.initials(of: "  ") == "?")
        #expect(Game.initials(of: "") == "?")
    }

    @Test func projection() {
        let game = makeGame(rows: demoRows)
        #expect(game.projectionSummary(adding: 35, to: .team1) == "105 → 140 · 60 to win")
        #expect(game.projectionSummary(adding: 100, to: .team1) == "105 → 205 · Wins the game!")
    }

    @Test func feedback() throws {
        let game = makeGame(rows: demoRows)
        let last = try #require(game.rounds.last)
        #expect(game.feedbackDetail(for: last) == "Ana & Luis +35 · 95 to win")
    }

    @Test func addRound() {
        let game = makeGame(rows: demoRows)
        game.addRound(35, for: .team2)
        #expect(game.scoreTeam.last == [0, 35])

        let count = game.scoreTeam.count
        game.addRound(0, for: .team1)
        game.addRound(5, for: .none)
        #expect(game.scoreTeam.count == count)
    }

    @Test func undoRemovesLastVisibleRound() {
        // Round 2 was edited down to 0 after being scored: the trailing row is hidden.
        let game = makeGame(rows: [[0, 0], [10, 0], [0, 5], [0, 0]])
        #expect(game.canUndo)
        game.undoLastRound()
        #expect(game.scoreTeam == [[0, 0], [10, 0]])
        #expect(game.rounds.map(\.points) == [10])
    }

    @Test(arguments: [GameState.finished, .cancelled])
    func undoIsUnavailableOnceGameIsOver(_ state: GameState) {
        let game = makeGame(rows: demoRows, state: state)
        #expect(!game.canUndo)
    }

    @Test func undoIsUnavailableWithoutVisibleRounds() {
        let game = makeGame(rows: [[0, 0], [0, 0]])
        #expect(!game.canUndo)
        game.undoLastRound()
        #expect(game.scoreTeam == [[0, 0], [0, 0]])
    }

    @Test func pips() {
        #expect(GameType.six.pips == 6)
        #expect(GameType.nine.pips == 9)
    }
}
