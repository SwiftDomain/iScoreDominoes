import Foundation
import Testing
@testable import iScore

struct SpokenReplyVoiceAvailabilityTests {

    /// Review Focus 4 — a voice language with no installed voice must not
    /// break recognition or scoring; it only means the app does not speak
    /// back, and Settings can say so rather than failing silently mid-game.
    @Test func reportsWhenItCannotSpeakALanguage() {
        #expect(SpokenReply.canSpeak(Locale(identifier: "en_US")))
        #expect(!SpokenReply.canSpeak(Locale(identifier: "zz_ZZ")))
        #expect(SpokenReply.voice(for: Locale(identifier: "zz_ZZ")) == nil)
    }

    @Test func bothShippedLanguagesHaveAVoice() {
        #expect(SpokenReply.canSpeak(Locale(identifier: "en")))
        #expect(SpokenReply.canSpeak(Locale(identifier: "es")))
    }

    /// The voice locale the rest of the app uses comes from the setting, not
    /// from the device — that is the whole point of a separate voice language.
    @Test func theVoiceLocaleFollowsTheSetting() {
        let defaults = UserDefaults(suiteName: "SpokenReplyVoiceTests")!
        defaults.removePersistentDomain(forName: "SpokenReplyVoiceTests")
        defer { defaults.removePersistentDomain(forName: "SpokenReplyVoiceTests") }
        defaults.set("en", forKey: LanguageSettings.appKey)
        defaults.set("es", forKey: LanguageSettings.voiceKey)
        #expect(LanguageSettings.voiceLocale(from: defaults).identifier == "es")
        #expect(SpokenReply.canSpeak(LanguageSettings.voiceLocale(from: defaults)))
    }
}
