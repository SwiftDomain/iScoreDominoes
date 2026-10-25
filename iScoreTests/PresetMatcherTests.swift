import Foundation
import Testing
@testable import iScore

struct PresetMatcherTests {

    private func setup(_ name: String, target: Int = 200) -> PresetSetup {
        PresetSetup(name: name, gameType: .nine, target: target, playerNames: ["Ana", "Luis", "Rafa", "Mia"])
    }

    private var friday: PresetSetup { setup("Friday night") }

    @Test func theNameWithACommandMatches() {
        #expect(PresetMatcher.match("start Friday night", presets: [friday]) == friday)
        #expect(PresetMatcher.match("Friday night", presets: [friday]) == friday)
        #expect(PresetMatcher.match("let's play friday night please", presets: [friday]) == friday)
    }

    /// Review Focus 3: one name a prefix of another — the whole phrase decides.
    @Test func theLongerNameWinsWhenBothFit() {
        let short = setup("Friday", target: 100)
        #expect(PresetMatcher.match("start Friday night", presets: [short, friday]) == friday)
        #expect(PresetMatcher.match("start Friday", presets: [short, friday]) == short)
    }

    /// Review Focus 2: a free-form description that happens to contain a
    /// preset's name is still a free-form description.
    @Test func aDescriptionIsNotTakenForAPreset() {
        let ana = setup("Ana")
        #expect(PresetMatcher.match("nine two hundred Ana Luis versus Rafa Mia", presets: [ana]) == nil)
    }

    /// Review Focus 5: Spanish, any case, any accenting.
    @Test func spanishAndAccentsMatch() {
        for name in ["Viernes", "VIERNES", "viérnes"] {
            let viernes = setup(name)
            #expect(PresetMatcher.match("empieza el viernes", presets: [viernes]) == viernes)
        }
    }

    @Test func noPresetsNoMatch() {
        #expect(PresetMatcher.match("start Friday night", presets: []) == nil)
    }

    @Test func aMatchedPresetIsWhatTheSheetStarts() async {
        let resolved = await VoiceSetup.resolve(
            "start Friday night",
            locale: Locale(identifier: "en"),
            defaults: (.six, 100),
            known: ["Ana", "Luis", "Rafa", "Mia"],
            owner: nil,
            presets: [friday]
        )
        #expect(resolved.gameType == .nine)
        #expect(resolved.target == 200)
        #expect(resolved.lineup.names == ["Ana", "Luis", "Rafa", "Mia"])
    }

    /// Final review #1: a name may itself contain words that are filler
    /// elsewhere — most Spanish names do.
    @Test func aNameWithArticlesOrFillerWordsMatches() {
        let viernes = setup("Viernes por la noche")
        #expect(PresetMatcher.match("juguemos el viernes por la noche", presets: [viernes]) == viernes)
        let revancha = setup("La revancha")
        #expect(PresetMatcher.match("empieza la revancha", presets: [revancha]) == revancha)
        let usual = setup("The usual")
        #expect(PresetMatcher.match("start the usual", presets: [usual]) == usual)
        #expect(PresetMatcher.match("let's play the usual please", presets: [usual]) == usual)
    }

    /// Speech and the keyboard's smart punctuation both write "Let’s".
    @Test func aCurlyApostropheIsTheSameWord() {
        #expect(PresetMatcher.match("Let’s play Friday night", presets: [friday]) == friday)
    }

    /// The looser rule still never takes a description for a preset.
    @Test func extraWordsStillMeanNoMatch() {
        let usual = setup("The usual")
        #expect(PresetMatcher.match("the usual but to three hundred", presets: [usual]) == nil)
        let ana = setup("Ana")
        #expect(PresetMatcher.match("the Ana and Luis game", presets: [ana]) == nil)
    }
}
