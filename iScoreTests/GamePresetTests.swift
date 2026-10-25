import Foundation
import Testing
@testable import iScore

struct GamePresetTests {

    private let friday = PresetSetup(name: "Friday night", gameType: .nine, target: 200,
                                     playerNames: ["Ana", "Luis", "Rafa", "Mia"])

    private func preset(_ name: String, created: TimeInterval, used: TimeInterval? = nil) -> GamePreset {
        var setup = friday
        setup.name = name
        let preset = GamePreset(setup)
        preset.created = Date(timeIntervalSince1970: created)
        preset.lastUsed = used.map(Date.init(timeIntervalSince1970:))
        return preset
    }

    // MARK: - Resolving

    @Test func resolvingReusesTheSavedSpelling() {
        var setup = friday
        setup.playerNames = ["ana", "Luis", "Rafa", "Mia"]
        let resolved = setup.resolved(known: ["Ana", "Luis", "Rafa", "Mia"])
        #expect(resolved.lineup.names == ["Ana", "Luis", "Rafa", "Mia"])
        #expect(resolved.newNames.isEmpty)
        #expect(resolved.gameType == .nine)
        #expect(resolved.target == 200)
    }

    /// Review Focus 1: a player deleted since the preset was saved is created
    /// again by name; the lineup is still complete.
    @Test func aDeletedPlayerComesBackAsNew() {
        let resolved = friday.resolved(known: ["Ana", "Rafa", "Mia"])
        #expect(resolved.lineup.isComplete)
        #expect(resolved.newNames == ["Luis"])
    }

    /// Review Focus 4: a stored target outside today's range is clamped.
    @Test func anOutOfRangeTargetIsClamped() {
        var setup = friday
        setup.target = 990
        #expect(setup.resolved(known: []).target == 200)
        setup.target = 5
        #expect(setup.resolved(known: []).target == 10)
    }

    @Test func aFinishedGameBecomesASetupInSeatOrder() {
        let game = makeTestGame(.six, maxScore: 100, team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"])
        let setup = PresetSetup(game: game, name: "Sunday")
        #expect(setup == PresetSetup(name: "Sunday", gameType: .six, target: 100,
                                     playerNames: ["Ana", "Luis", "Rafa", "Mia"]))
    }

    @Test func aSetupNeedsFourDifferentPlayers() {
        #expect(friday.isComplete)
        var blank = friday
        blank.playerNames[3] = " "
        #expect(!blank.isComplete)
        var twice = friday
        twice.playerNames[1] = "ana"
        #expect(!twice.isComplete)
    }

    @Test func theModelRoundTripsItsSetup() {
        #expect(GamePreset(friday).setup == friday)
    }

    // MARK: - Names

    @Test func namesAreTrimmedAndCut() {
        #expect(PresetName.cleaned("  Friday night  ") == "Friday night")
        #expect(PresetName.cleaned(String(repeating: "x", count: 40)).count == PresetName.maxLength)
    }

    @Test func aNameIsTakenWhateverItsCaseOrAccents() {
        #expect(PresetName.isTaken("friday NIGHT", among: ["Friday night"]))
        #expect(PresetName.isTaken("Sábado", among: ["sabado"]))
        #expect(!PresetName.isTaken("Saturday", among: ["Friday night"]))
    }

    // MARK: - Lists

    @Test func homeShowsThreeRecentlyUsedFirst() {
        let presets = [
            preset("A", created: 1), preset("B", created: 2), preset("C", created: 3),
            preset("D", created: 4), preset("E", created: 0, used: 10),
        ]
        #expect(PresetList.homeRow(presets).map(\.name) == ["E", "D", "C"])
    }

    /// Two devices saving one name before they sync: one card, the oldest.
    @Test func aSyncedDuplicateNameShowsOnce() {
        let older = preset("Friday night", created: 1)
        let newer = preset("friday night", created: 2)
        let row = PresetList.homeRow([newer, older])
        #expect(row.count == 1)
        #expect(row.first === older)
        let duplicates = PresetList.duplicates(in: [newer, older])
        #expect(duplicates.count == 1)
        #expect(duplicates.first === newer)
    }

    @Test func missingPlayersAreListedInSeatOrder() {
        #expect(friday.missingPlayers(known: ["Ana", "Rafa"]) == ["Luis", "Mia"])
        #expect(friday.missingPlayers(known: ["Ána", "Luis", "Rafa", "Mia"]).isEmpty)
    }

    @Test func theVoiceOverLabelReadsTheWholeSetup() {
        #expect(String(localized: friday.accessibilityLabel) == "Friday night, Double 9 to 200, Ana, Luis, Rafa, Mia")
        #expect(localized(friday.accessibilityLabel, in: "es") == "Friday night, Doble 9 a 200, Ana, Luis, Rafa, Mia")
    }

    // MARK: - Settings row notes

    private func text(_ notes: [LocalizedStringResource], in language: String = "en") -> [String] {
        notes.map { localized($0, in: language) }
    }

    @Test func aHealthyPresetHasNoNotes() {
        #expect(PresetRowNotes.notes(for: friday, isDuplicate: false, known: friday.playerNames).isEmpty)
    }

    @Test func notesSayWhatIsWrong() {
        #expect(text(PresetRowNotes.notes(for: friday, isDuplicate: true, known: friday.playerNames)) == ["Duplicate name"])
        #expect(text(PresetRowNotes.notes(for: friday, isDuplicate: false, known: ["Ana", "Rafa", "Mia"])) == ["Luis is no longer saved"])
        #expect(text(PresetRowNotes.notes(for: friday, isDuplicate: false, known: ["Ana", "Rafa"])) == ["2 players are no longer saved"])
        #expect(text(PresetRowNotes.notes(for: friday, isDuplicate: true, known: ["Ana", "Rafa"]), in: "es")
                == ["Nombre repetido", "2 jugadores ya no están guardados"])
        #expect(text(PresetRowNotes.notes(for: friday, isDuplicate: false, known: ["Ana", "Rafa", "Mia"]), in: "es")
                == ["Luis ya no está guardado"])
    }

    // MARK: - Editor

    @Test func aValidPresetHasNothingBlockingSave() {
        #expect(PresetEditorRules.blocker(name: "Friday night", setup: friday, existing: [], editing: nil) == nil)
    }

    @Test func saveIsBlockedForOneReasonAtATime() {
        var blank = friday
        blank.playerNames[0] = ""
        let cases: [(String, PresetSetup, [String], String, String)] = [
            ("  ", blank, ["Friday night"], "Give it a name", "Ponle un nombre"),
            ("friday NIGHT", blank, ["Friday night"], "You already have a preset called friday NIGHT",
             "Ya tienes una partida guardada llamada friday NIGHT"),
            ("Saturday", blank, ["Friday night"], "Pick all four players", "Elige a los cuatro jugadores"),
        ]
        for (name, setup, existing, english, spanish) in cases {
            let blocker = PresetEditorRules.blocker(name: name, setup: setup, existing: existing, editing: nil)
            #expect(blocker.map { localized($0, in: "en") } == english)
            #expect(blocker.map { localized($0, in: "es") } == spanish)
        }
    }

    /// Editing a preset keeps its own name without calling it taken.
    @Test func aPresetMayKeepItsOwnName() {
        #expect(PresetEditorRules.blocker(name: "Friday night", setup: friday,
                                          existing: ["Friday night", "Sunday"], editing: "Friday night") == nil)
    }
}
