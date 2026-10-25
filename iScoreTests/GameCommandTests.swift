import Foundation
import Testing
@testable import iScore

struct GameCommandParseTests {

    private let en = Locale(identifier: "en_US")
    private let es = Locale(identifier: "es_DO")

    private func parse(_ text: String, _ locale: Locale? = nil) -> GameCommand {
        GameCommand.parse(text, locale: locale ?? en)
    }

    @Test func parsesTheCanonicalSentence() {
        let command = parse("nine, two hundred, me and Carlos against Luis and Papo")
        #expect(command.gameType == .nine)
        #expect(command.target == 200)
        #expect(command.team1 == ["me", "Carlos"])
        #expect(command.team2 == ["Luis", "Papo"])
    }

    @Test func wordOrderDoesNotMatter() {
        let a = parse("me and Carlos against Luis and Papo, two hundred, nine")
        let b = parse("two hundred nine me and Carlos vs Luis and Papo")
        #expect(a.gameType == .nine)
        #expect(a.target == 200)
        #expect(a.team1 == ["me", "Carlos"])
        #expect(a == b)
    }

    @Test func recognizesSeparators() {
        #expect(parse("Ana and Luis vs Papo and Tito").team2 == ["Papo", "Tito"])
        #expect(parse("Ana and Luis versus Papo and Tito").team2 == ["Papo", "Tito"])
        #expect(parse("Ana y Luis contra Papo y Tito", es).team2 == ["Papo", "Tito"])
    }

    @Test func numbersOutsideAnyTargetRangeAreDropped() {
        let command = parse("nine, five thousand, Ana and Luis vs Papo and Tito")
        #expect(command.gameType == .nine)
        #expect(command.target == nil)
        #expect(command.team1 == ["Ana", "Luis"])
    }

    @Test func sixAndNineAreGameTypesNotTargets() {
        #expect(parse("six, Ana and Luis vs Papo and Tito").gameType == .six)
        #expect(parse("six, Ana and Luis vs Papo and Tito").target == nil)
        #expect(parse("double six to one hundred").gameType == .six)
        #expect(parse("double six to one hundred").target == 100)
    }

    @Test func namesSurviveWithoutAGameTypeOrTarget() {
        let command = parse("Ana and Luis vs Papo and Tito")
        #expect(command.gameType == nil)
        #expect(command.target == nil)
        #expect(command.team1 == ["Ana", "Luis"])
    }

    @Test func noSeparatorPutsFirstTwoNamesOnTeamOne() {
        let command = parse("Ana, Luis, Papo, Tito")
        #expect(command.team1 == ["Ana", "Luis"])
        #expect(command.team2 == ["Papo", "Tito"])
    }

    @Test func emptyTranscriptIsEmpty() {
        #expect(parse("").isEmpty)
        #expect(parse("uh, hmm, okay so").isEmpty)
    }

    // MARK: - Branches the sentence tests do not reach

    /// With no game type spoken, the widest range (Double 9's) decides what counts as a target.
    @Test func targetWithoutATypeUsesTheWidestRange() {
        #expect(parse("one hundred fifty, Ana and Luis vs Papo and Tito").target == 150)
        #expect(parse("two hundred and fifty").target == nil)
    }

    /// Once a type is spoken, its own range applies: 150 is out of range for Double 6.
    @Test func targetOutsideTheSpokenTypesRangeIsDropped() {
        #expect(parse("six, one hundred fifty").target == nil)
        #expect(parse("nine, one hundred fifty").target == 150)
    }

    @Test func firstTypeAndFirstInRangeTargetWin() {
        let command = parse("nine six, fifty, one hundred")
        #expect(command.gameType == .nine)
        #expect(command.target == 50)
    }

    @Test func spanishNumbersAndAccents() {
        let command = parse("nueve, doscientos, yo y Carlos contra Luis y Papo", es)
        #expect(command.gameType == .nine)
        #expect(command.target == 200)
        #expect(command.team1 == ["yo", "Carlos"])
        #expect(command.team2 == ["Luis", "Papo"])
        #expect(parse("doble seis, dieciséis", es).gameType == .six)
        #expect(parse("doble seis, dieciséis", es).target == 16)
    }

    @Test func connectorInsideANumberIsNotAName() {
        let command = parse("fifty and five, Ana and Luis vs Papo and Tito")
        #expect(command.target == 55)
        #expect(command.team1 == ["Ana", "Luis"])
    }

    @Test func separatorWithOneSidedNames() {
        let leading = parse("vs Papo and Tito")
        #expect(leading.team1.isEmpty)
        #expect(leading.team2 == ["Papo", "Tito"])
        let trailing = parse("Ana and Luis vs")
        #expect(trailing.team1 == ["Ana", "Luis"])
        #expect(trailing.team2.isEmpty)
    }

    @Test func onlyTheFirstSeparatorSplits() {
        let command = parse("Ana vs Luis vs Papo")
        #expect(command.team1 == ["Ana"])
        #expect(command.team2 == ["Luis", "Papo"])
    }

    @Test func extraNamesWithoutASeparatorGoToTeamTwo() {
        let command = parse("Ana Luis Papo")
        #expect(command.team1 == ["Ana", "Luis"])
        #expect(command.team2 == ["Papo"])
    }

    @Test func casingAndPunctuationAreHandled() {
        let command = parse("  NINE!! Two-Hundred... Me & Carlos VS. Luis ")
        #expect(command.gameType == .nine)
        #expect(command.target == 200)
        #expect(command.team1 == ["Me", "Carlos"])
        #expect(command.team2 == ["Luis"])
    }

    @Test func numberOnlyTranscriptIsNotEmpty() {
        #expect(!parse("nine").isEmpty)
        #expect(parse("five thousand").isEmpty)
    }
}

struct GameCommandResolveTests {

    private let defaults = (type: GameType.nine, target: 100)
    private let known = ["Ana", "Carlos", "Luis", "Papo"]

    private func resolve(_ text: String, owner: String? = "Ana", known: [String]? = nil) -> ResolvedGame {
        GameCommand.parse(text, locale: Locale(identifier: "en_US"))
            .resolved(defaults: defaults, known: known ?? self.known, owner: owner)
    }

    @Test func fillsTheCanonicalSentence() {
        let game = resolve("nine, two hundred, me and Carlos against Luis and Papo")
        #expect(game.gameType == .nine)
        #expect(game.target == 200)
        #expect(game.lineup.names == ["Ana", "Carlos", "Luis", "Papo"])
        #expect(game.lineup.isComplete)
        #expect(game.newNames.isEmpty)
    }

    @Test func missingFieldsComeFromDefaults() {
        let game = resolve("Ana and Luis vs Papo and Carlos")
        #expect(game.gameType == .nine)
        #expect(game.target == 100)
    }

    @Test func targetIsClampedToTheResolvedType() {
        #expect(resolve("six, one hundred fifty, Ana and Luis vs Papo and Carlos").target == 100)
        #expect(resolve("nine, one hundred four, Ana and Luis vs Papo and Carlos").target == 100)
    }

    @Test func existingSpellingWins() {
        let game = resolve("nine, ana and carlos vs luis and papo")
        #expect(game.lineup.names == ["Ana", "Carlos", "Luis", "Papo"])
        #expect(game.newNames.isEmpty)
    }

    @Test func unknownNamesAreMarkedNew() {
        let game = resolve("Ana and Carlos vs Tito and Papo")
        #expect(game.newNames == ["Tito"])
        #expect(game.lineup.isComplete)
    }

    /// Review Focus 1 — the mic heard nothing usable.
    @Test func emptyTranscriptGivesDefaultsAndEmptySeats() {
        let game = resolve("uh, hmm")
        #expect(game.gameType == .nine)
        #expect(game.target == 100)
        #expect(game.lineup.names == ["", "", "", ""])
        #expect(!game.lineup.isComplete)
        #expect(String(localized: game.lineup.hint!) == "Add 4 more players to start")
    }

    /// Review Focus 3 — the same name heard twice.
    @Test func aRepeatedNameIsSeatedOnce() {
        let game = resolve("me and Carlos vs Carlos and Papo")
        #expect(game.lineup.names == ["Ana", "Carlos", "Papo", ""])
        #expect(!game.lineup.isComplete)
        #expect(String(localized: game.lineup.hint!) == "Add 1 more player to start")
    }

    /// Review Focus 4 — recognizer output with punctuation and over-long names.
    @Test func namesAreTrimmedAndTruncated() {
        let game = resolve("Ana and Bartholomewlongname vs Luis and Papo",
                           known: ["Ana", "Luis", "Papo"])
        #expect(game.lineup.names[1] == "Bartholomewlong")
        #expect(game.lineup.names[1].count == PlayerName.maxLength)
        #expect(game.lineup.isComplete)
    }

    @Test func meIsDroppedWhenTheOwnerIsNotPlaying() {
        let game = resolve("me and Carlos vs Luis and Papo", owner: nil)
        #expect(game.lineup.names == ["Carlos", "", "Luis", "Papo"])
        #expect(!game.lineup.isComplete)
    }

    @Test func spanishMeResolvesToTheOwner() {
        let command = GameCommand.parse("yo y Carlos contra Luis y Papo", locale: Locale(identifier: "es_DO"))
        let game = command.resolved(defaults: defaults, known: known, owner: "Ana")
        #expect(game.lineup.names == ["Ana", "Carlos", "Luis", "Papo"])
    }

    // MARK: - Branches the brief's tests do not reach

    /// A name never crosses sides: the short side keeps its empty seat.
    @Test func aShortSideKeepsItsEmptySeat() {
        let game = resolve("Ana vs Luis and Papo")
        #expect(game.lineup.names == ["Ana", "", "Luis", "Papo"])
        #expect(game.lineup.names(for: .team1) == ["Ana", ""])
        #expect(game.lineup.names(for: .team2) == ["Luis", "Papo"])
        #expect(!game.lineup.isComplete)
    }

    /// A third name on one side is ignored; it does not spill onto the other team.
    @Test func aThirdNameOnOneSideIsIgnored() {
        let game = resolve("Ana, Carlos and Tito vs Papo")
        #expect(game.lineup.names == ["Ana", "Carlos", "Papo", ""])
        #expect(game.newNames.isEmpty)
    }

    @Test func namesBeyondTheFourthSeatAreIgnored() {
        let game = resolve("Ana and Carlos vs Luis, Papo and Tito")
        #expect(game.lineup.names == ["Ana", "Carlos", "Luis", "Papo"])
        #expect(game.newNames.isEmpty)
    }

    @Test func aRepeatedNameDifferingByCaseIsSeatedOnce() {
        let game = resolve("Ana and Tito vs tito and Luis")
        #expect(game.lineup.names == ["Ana", "Tito", "Luis", ""])
        #expect(game.newNames == ["Tito"])
    }

    @Test func meAndTheOwnersNameSeatTheOwnerOnce() {
        let game = resolve("me and Ana vs Luis and Papo")
        #expect(game.lineup.names == ["Ana", "", "Luis", "Papo"])
    }

    @Test func theOwnerIsNeverMarkedNew() {
        let game = resolve("me and Carlos vs Luis and Papo", owner: "Zed", known: ["Carlos", "Luis", "Papo"])
        #expect(game.lineup.names == ["Zed", "Carlos", "Luis", "Papo"])
        #expect(game.newNames.isEmpty)
    }

    @Test func newNamesKeepTheOrderHeard() {
        let game = resolve("Tito and Ana vs Rafa and Luis")
        #expect(game.newNames == ["Tito", "Rafa"])
    }

    @Test func aSpokenTypeWithoutATargetUsesTheDefaultClampedToThatType() {
        let game = resolve("six, Ana and Luis vs Papo and Carlos")
        #expect(game.gameType == .six)
        #expect(game.target == 100)
    }
}
