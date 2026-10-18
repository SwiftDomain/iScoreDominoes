import Foundation
import Testing
@testable import iScore

struct ScoreCommandTests {

    private let en = Locale(identifier: "en_US")
    private let es = Locale(identifier: "es_US")

    /// Ana & Luis are team 1, Rafa & Mia are team 2, and Ana owns the phone.
    private let seated = ScoreContext(team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"], owner: "Ana")
    private let unseated = ScoreContext(team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"], owner: nil)

    // MARK: - Recording

    @Test func recordsPointsForTheOwnersTeam() {
        #expect(ScoreCommand.parse("twenty-five us", locale: en, context: seated)
                == .record(points: 25, team: .team1))
        #expect(ScoreCommand.parse("thirty them", locale: en, context: seated)
                == .record(points: 30, team: .team2))
    }

    @Test func recordsSpanishPointsForTheOwnersTeam() {
        #expect(ScoreCommand.parse("veinticinco nosotros", locale: es, context: seated)
                == .record(points: 25, team: .team1))
        #expect(ScoreCommand.parse("treinta ellos", locale: es, context: seated)
                == .record(points: 30, team: .team2))
    }

    @Test func digitsWorkAsWellAsWords() {
        #expect(ScoreCommand.parse("25 us", locale: en, context: seated)
                == .record(points: 25, team: .team1))
    }

    /// Word order is the speaker's, not ours.
    @Test func teamMayComeFirst() {
        #expect(ScoreCommand.parse("give Rafa fifteen", locale: en, context: seated)
                == .record(points: 15, team: .team2))
    }

    // MARK: - Team precedence

    @Test func aNamedPlayerOutranksUsAndThem() {
        // "us" would mean team 1; Rafa is named, so team 2 wins.
        #expect(ScoreCommand.parse("twenty for Rafa, not us", locale: en, context: seated)
                == .record(points: 20, team: .team2))
    }

    @Test func aTeamNameOutranksUsAndThem() {
        #expect(ScoreCommand.parse("twenty team two, not us", locale: en, context: seated)
                == .record(points: 20, team: .team2))
        #expect(ScoreCommand.parse("veinte equipo dos", locale: es, context: seated)
                == .record(points: 20, team: .team2))
    }

    @Test func teamColorsNameTheTeams() {
        #expect(ScoreCommand.team(in: "forty on green", locale: en, context: seated) == .team1)
        #expect(ScoreCommand.team(in: "forty on blue", locale: en, context: seated) == .team2)
        #expect(ScoreCommand.team(in: "cuarenta al azul", locale: es, context: seated) == .team2)
    }

    @Test func namesMatchCaseAndAccentInsensitively() {
        let context = ScoreContext(team1: ["José", "Luis"], team2: ["Rafa", "Mia"], owner: nil)
        #expect(ScoreCommand.team(in: "thirty jose", locale: en, context: context) == .team1)
    }

    /// The scorekeeper is often not one of the four players.
    @Test func withNoOwnerUsAndThemFallBackToSeatOrder() {
        #expect(ScoreCommand.parse("twenty-five us", locale: en, context: unseated)
                == .record(points: 25, team: .team1))
        #expect(ScoreCommand.parse("twenty-five them", locale: en, context: unseated)
                == .record(points: 25, team: .team2))
    }

    @Test func theOwnerOnTeamTwoMakesUsTeamTwo() {
        let context = ScoreContext(team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"], owner: "Rafa")
        #expect(context.ownTeam == .team2)
        #expect(ScoreCommand.parse("fifteen us", locale: en, context: context)
                == .record(points: 15, team: .team2))
        #expect(ScoreCommand.parse("fifteen them", locale: en, context: context)
                == .record(points: 15, team: .team1))
    }

    // MARK: - Never guessing (Review Focus 1)

    @Test func aBareNumberAsksWhichTeam() {
        #expect(ScoreCommand.parse("twenty-five", locale: en, context: seated) == .askTeam(points: 25))
        #expect(ScoreCommand.parse("veinticinco", locale: es, context: seated) == .askTeam(points: 25))
    }

    @Test func tableTalkWithNoNumberAndNoCommandIsNotACommand() {
        #expect(ScoreCommand.parse("your turn, pass me the water", locale: en, context: seated) == nil)
        #expect(ScoreCommand.parse("", locale: en, context: seated) == nil)
        #expect(ScoreCommand.parse("   ", locale: en, context: seated) == nil)
    }

    /// A number inside a team reference is not the round's points.
    @Test func teamWordsAreNotCountedAsPoints() {
        #expect(ScoreCommand.parse("one team two", locale: en, context: seated)
                == .record(points: 1, team: .team2))
        #expect(ScoreCommand.parse("dos equipo uno", locale: es, context: seated)
                == .record(points: 2, team: .team1))
    }

    /// With nothing but a team reference there is no round to record.
    @Test func aTeamReferenceAloneIsNotARecord() {
        #expect(ScoreCommand.parse("team two", locale: en, context: seated) == nil)
        #expect(ScoreCommand.parse("equipo dos", locale: es, context: seated) == nil)
    }

    /// A number a round cannot be is not a round. The keypad caps at 3 digits too.
    @Test func implausibleValuesAreNotPoints() {
        #expect(ScoreCommand.points(in: "zero us", locale: en) == nil)
        #expect(ScoreCommand.points(in: "1000 us", locale: en) == nil)
        #expect(ScoreCommand.points(in: "999 us", locale: en) == 999)
    }

    // MARK: - Undo

    @Test func undoInBothLanguages() {
        #expect(ScoreCommand.parse("undo", locale: en, context: seated) == .undo)
        #expect(ScoreCommand.parse("take that back", locale: en, context: seated) == .undo)
        #expect(ScoreCommand.parse("quita eso", locale: es, context: seated) == .undo)
    }

    /// Undo outranks a number, so "undo the twenty-five" is not a new round.
    @Test func undoOutranksARecord() {
        #expect(ScoreCommand.parse("undo the twenty-five", locale: en, context: seated) == .undo)
    }

    // MARK: - Questions

    @Test func whoIsWinningInBothLanguages() {
        #expect(ScoreCommand.parse("who's winning?", locale: en, context: seated) == .whoIsWinning)
        #expect(ScoreCommand.parse("what's the score", locale: en, context: seated) == .whoIsWinning)
        #expect(ScoreCommand.parse("¿quién va ganando?", locale: es, context: seated) == .whoIsWinning)
    }

    @Test func pointsToGoInBothLanguages() {
        #expect(ScoreCommand.parse("how many to go?", locale: en, context: seated) == .pointsToGo)
        #expect(ScoreCommand.parse("how much to win", locale: en, context: seated) == .pointsToGo)
        #expect(ScoreCommand.parse("¿cuánto falta?", locale: es, context: seated) == .pointsToGo)
    }

    /// A question that happens to name a team is still a question.
    @Test func aQuestionOutranksARecord() {
        #expect(ScoreCommand.parse("how many to go for Rafa", locale: en, context: seated) == .pointsToGo)
    }

    // MARK: - Ending

    @Test func endAndCancelAreDistinct() {
        #expect(ScoreCommand.parse("end the game", locale: en, context: seated) == .endGame)
        #expect(ScoreCommand.parse("game over", locale: en, context: seated) == .endGame)
        #expect(ScoreCommand.parse("cancel the game", locale: en, context: seated) == .cancelGame)
        #expect(ScoreCommand.parse("termina el juego", locale: es, context: seated) == .endGame)
        #expect(ScoreCommand.parse("cancela el juego", locale: es, context: seated) == .cancelGame)
    }

    /// "cancel the game" contains "game": cancel must be checked first.
    @Test func cancelIsNotHeardAsEnd() {
        #expect(ScoreCommand.parse("cancel this game", locale: en, context: seated) == .cancelGame)
    }

    /// A player called "Blue" or "Uno" must not be shadowed by the team-name words.
    @Test func aPlayerNamedAfterATeamWordStillResolvesToTheirOwnTeam() {
        let context = ScoreContext(team1: ["Ana", "Luis"], team2: ["Blue", "Mia"], owner: "Ana")
        #expect(ScoreCommand.team(in: "thirty blue", locale: en, context: context) == .team2)
    }
}
