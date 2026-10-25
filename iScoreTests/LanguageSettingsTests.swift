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

    /// Review Focus 5: the Lock Screen's leader line comes from the widget
    /// target, whose literals must reach the catalog like the app's do.
    @Test func theLockScreenLeaderLineIsTranslated() {
        #expect(localized("Round \(4) · \(80) to win", in: "es") == "Ronda 4 · 80 para ganar")
        #expect(localized("Round \(4)", in: "es") == "Ronda 4")
    }

    /// Shipping two localizations gives the app a Language row in iOS
    /// Settings, which changes what is shown without telling the picker.
    @Test func theShownLanguageComesFromTheBundlesChoice() {
        #expect(AppLanguage.shown(preferredLocalizations: ["es"]) == .spanish)
        #expect(AppLanguage.shown(preferredLocalizations: ["en"]) == .english)
        #expect(AppLanguage.shown(preferredLocalizations: ["Base"]) == .english)
        #expect(AppLanguage.shown(preferredLocalizations: []) == .english)
    }

    /// At launch the language on screen wins, in the app's store and in the
    /// widget's, so the picker and the Lock Screen agree with what is shown.
    @Test func launchAdoptsTheLanguageActuallyShown() {
        let app = emptyDefaults("LanguageSettingsTests.adoptApp")
        let group = emptyDefaults("LanguageSettingsTests.adoptGroup")
        defer {
            app.removePersistentDomain(forName: "LanguageSettingsTests.adoptApp")
            group.removePersistentDomain(forName: "LanguageSettingsTests.adoptGroup")
        }
        app.set("es", forKey: LanguageSettings.appKey)
        group.set("es", forKey: LanguageSettings.appKey)
        LanguageSettings.adopt(.english, app: app, group: group)
        #expect(LanguageSettings.app(from: app) == .english)
        #expect(group.string(forKey: LanguageSettings.appKey) == "en")
    }
}
