import Foundation
import Testing
@testable import iScore

/// The voice choice is tested against a stand-in inventory, never the
/// simulator's: asking the system for its voices can block on a fresh CI
/// simulator, and which voices a machine has installed is not this code's
/// behavior. Whether a real phone has Spanish is on the device checklist.
struct SpokenReplyVoiceAvailabilityTests {

    private let installed: Set<String> = ["en-US", "es-MX", "es"]
    private var isInstalled: (String) -> Bool { { installed.contains($0) } }

    @Test func aFullIdentifierIsPreferred() {
        #expect(SpokenReply.voiceLanguage(for: Locale(identifier: "en_US"), isInstalled: isInstalled) == "en-US")
        #expect(SpokenReply.voiceLanguage(for: Locale(identifier: "es_MX"), isInstalled: isInstalled) == "es-MX")
    }

    /// The setting stores a bare language ("es"), so the code alone must find a voice.
    @Test func aBareLanguageFallsBackToItsCode() {
        #expect(SpokenReply.voiceLanguage(for: Locale(identifier: "es_ES"), isInstalled: isInstalled) == "es")
    }

    /// Review Focus 4: a language with no installed voice is reported, so the
    /// app can stay quiet and say why rather than fail mid-game.
    @Test func reportsWhenItCannotSpeakALanguage() {
        #expect(SpokenReply.voiceLanguage(for: Locale(identifier: "zz_ZZ"), isInstalled: isInstalled) == nil)
        #expect(!SpokenReply.canSpeak(Locale(identifier: "zz_ZZ"), isInstalled: isInstalled))
        #expect(SpokenReply.canSpeak(Locale(identifier: "es"), isInstalled: isInstalled))
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
    }
}
