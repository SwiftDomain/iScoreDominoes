import Testing
@testable import iScore

struct GameEditingTests {

    /// Round 3 of the demo game: Ana & Luis +45 (row index 3).
    private func roundThree(of game: Game) -> Round {
        game.rounds[2]
    }

    @Test func editRoundChangesPointsInPlace() {
        let game = makeTestGame(rows: demoGameRows)
        let round = roundThree(of: game)
        #expect(round.points == 45)

        game.editRound(round, to: 50)

        #expect(game.total(for: .team1) == 110)
        #expect(game.rounds.count == 5)
        #expect(game.rounds[2] == Round(id: 3, number: 3, team: .team1, points: 50))
    }

    @Test(arguments: [0, -5])
    func editRoundIgnoresNonPositivePoints(_ points: Int) {
        let game = makeTestGame(rows: demoGameRows)
        game.editRound(roundThree(of: game), to: points)
        #expect(game.scoreTeam == demoGameRows)
    }

    @Test func editRoundIgnoresStaleRound() {
        let game = makeTestGame(rows: demoGameRows)
        game.editRound(Round(id: 42, number: 9, team: .team1, points: 10), to: 20)
        #expect(game.scoreTeam == demoGameRows)
    }

    @Test func deleteRoundRemovesTheRowAndRenumbers() {
        let game = makeTestGame(rows: demoGameRows)
        game.deleteRound(game.rounds[1]) // Rafa & Mia +30

        #expect(game.total(for: .team2) == 15)
        #expect(game.rounds.map(\.number) == [1, 2, 3, 4])
        #expect(game.rounds.map(\.points) == [25, 45, 15, 35])
    }

    @Test func deleteRoundIgnoresStaleRound() {
        let game = makeTestGame(rows: demoGameRows)
        game.deleteRound(Round(id: 42, number: 9, team: .team1, points: 10))
        #expect(game.scoreTeam == demoGameRows)
    }

    @Test func undoAfterDeletingTheLastRoundTakesBackTheNewLastRound() {
        let game = makeTestGame(rows: demoGameRows)
        game.deleteRound(game.rounds[4]) // +35, the last round
        game.undoLastRound()             // takes back +15
        #expect(game.rounds.map(\.points) == [25, 30, 45])
    }

    @Test func totalReplacingARound() {
        let game = makeTestGame(rows: demoGameRows)
        let round = roundThree(of: game)
        #expect(game.total(for: .team1, replacing: round, with: 0) == 60)
        #expect(game.total(for: .team1, replacing: round, with: 50) == 110)
        // Rounds only count toward their own team.
        #expect(game.total(for: .team2, replacing: round, with: 50) == 45)
    }

    @Test func editProjection() {
        let game = makeTestGame(rows: demoGameRows)
        let round = roundThree(of: game)
        #expect(String(localized: game.editProjectionSummary(for: round, newPoints: 50)) == "105 → 110 · 90 to win")
        #expect(String(localized: game.editProjectionSummary(for: round, newPoints: 140)) == "105 → 200 · Wins the game!")
        #expect(String(localized: game.editProjectionSummary(for: round, newPoints: 5)) == "105 → 65 · 135 to win")
    }

    @Test func roundEditCopy() {
        let round = Round(id: 3, number: 3, team: .team1, points: 45)
        #expect(round.editPrompt == "Fixing round 3? What should it be?")
        #expect(round.editLabel == "Round 3 · was +45")
    }

    @Test func outcomes() {
        let playing = makeTestGame(rows: demoGameRows)
        #expect(playing.outcome(for: .team1) == .playing)

        let finished = makeTestGame(rows: [[0, 0], [200, 0], [0, 145]], state: .finished)
        #expect(finished.outcome(for: .team1) == .won)
        #expect(finished.outcome(for: .team2) == .lost)

        let cancelled = makeTestGame(rows: [[0, 0], [80, 0]], state: .cancelled)
        #expect(cancelled.outcome(for: .team1) == .cancelled)
        #expect(cancelled.outcome(for: .team2) == .cancelled)
    }

    @Test func setupSummary() {
        #expect(makeTestGame(.nine, maxScore: 200).setupSummary == "Double 9 · First to 200")
        #expect(makeTestGame(.six, maxScore: 20).setupSummary == "Double 6 · First to 20")
    }
}
