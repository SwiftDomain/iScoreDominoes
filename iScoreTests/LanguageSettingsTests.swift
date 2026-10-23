import Foundation
import Testing
@testable import iScore

struct AppLanguageTests {

    @Test func matchesSupportedLanguages() {
        #expect(AppLanguage.matching(Locale(identifier: "en_US")) == .english)
        #expect(AppLanguage.matching(Locale(identifier: "es_DO")) == .spanish)
        #expect(AppLanguage.matching(Locale(identifier: "es")) == .spanish)
    }

    /// Review Focus 1 — a language we do not ship falls back to English.
    @Test func fallsBackToEnglish() {
        #expect(AppLanguage.matching(Locale(identifier: "fr_FR")) == .english)
        #expect(AppLanguage.matching(Locale(identifier: "pt_BR")) == .english)
        #expect(AppLanguage.matching(Locale(identifier: "")) == .english)
    }

    @Test func namesItselfInItsOwnLanguage() {
        #expect(AppLanguage.english.endonym == "English")
        #expect(AppLanguage.spanish.endonym == "Español")
    }
}

struct LanguageSettingsTests {

    private func emptyDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func voiceFollowsAppWhenUnset() {
        let defaults = emptyDefaults("LanguageSettingsTests.unset")
        defer { defaults.removePersistentDomain(forName: "LanguageSettingsTests.unset") }
        defaults.set("es", forKey: LanguageSettings.appKey)
        #expect(LanguageSettings.voice(from: defaults) == .spanish)
        #expect(LanguageSettings.voiceLocale(from: defaults).identifier.hasPrefix("es"))
    }

    @Test func voiceIsIndependentOnceSet() {
        let defaults = emptyDefaults("LanguageSettingsTests.split")
        defer { defaults.removePersistentDomain(forName: "LanguageSettingsTests.split") }
        defaults.set("en", forKey: LanguageSettings.appKey)
        defaults.set("es", forKey: LanguageSettings.voiceKey)
        #expect(LanguageSettings.app(from: defaults) == .english)
        #expect(LanguageSettings.voice(from: defaults) == .spanish)
    }

    @Test func anUnknownStoredValueFallsBackRatherThanCrashing() {
        let defaults = emptyDefaults("LanguageSettingsTests.junk")
        defer { defaults.removePersistentDomain(forName: "LanguageSettingsTests.junk") }
        defaults.set("klingon", forKey: LanguageSettings.appKey)
        #expect(LanguageSettings.app(from: defaults) == .english)
    }
}
