//
//  LanguageSettings.swift
//  iScore
//
//  The two language settings the app keeps: the one it shows and the one it
//  listens and speaks in. They are independent — a Spanish-speaking table with
//  an English interface is a supported combination, and so is the reverse.
//

import Foundation

/// A language the app ships. English and Spanish are the two.
enum AppLanguage: String, CaseIterable, Identifiable {

    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    /// The language's own name, in that language, so each row in the picker
    /// reads naturally to whoever speaks it.
    var endonym: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        }
    }

    /// The shipped language closest to a device locale. Anything we do not
    /// ship falls back to English rather than leaving the interface empty.
    static func matching(_ locale: Locale) -> AppLanguage {
        guard let code = locale.language.languageCode?.identifier,
              let language = AppLanguage(rawValue: code) else { return .english }
        return language
    }

    /// The language the bundle actually chose, from
    /// `Bundle.main.preferredLocalizations`. This is the truth about what is on
    /// screen: iOS Settings can change it without the in-app picker knowing.
    static func shown(preferredLocalizations: [String]) -> AppLanguage {
        guard let first = preferredLocalizations.first else { return .english }
        return matching(Locale(identifier: first))
    }
}

extension LocalizedStringResource {

    /// This copy in a given language, whatever language the process runs in.
    /// The voice and the Lock Screen both need text in a language they choose.
    func resolved(in locale: Locale) -> String {
        var resource = self
        resource.locale = locale
        return String(localized: resource)
    }
}

/// Reads the stored languages. Settings owns the writes, through `@AppStorage`
/// and `LanguageRelaunch`; the one exception is `adopt`, at launch.
enum LanguageSettings {

    static let appKey = "appLanguage"
    static let voiceKey = "voiceLanguage"

    /// Falls back to the device's language on first run, so a Spanish phone
    /// opens in Spanish without anyone visiting Settings.
    static func app(from defaults: UserDefaults = .standard) -> AppLanguage {
        stored(defaults.string(forKey: appKey)) ?? .matching(.current)
    }

    /// Defaults to the app language until the user sets it apart.
    static func voice(from defaults: UserDefaults = .standard) -> AppLanguage {
        stored(defaults.string(forKey: voiceKey)) ?? app(from: defaults)
    }

    /// What `SFSpeechRecognizer` and `AVSpeechSynthesisVoice` are built from.
    static func voiceLocale(from defaults: UserDefaults = .standard) -> Locale {
        Locale(identifier: voice(from: defaults).rawValue)
    }

    /// Records the language actually shown, in the app's store and in the
    /// widget's, so the picker and the Lock Screen agree with the screen even
    /// after the language was changed in iOS Settings. Called at launch.
    static func adopt(_ shown: AppLanguage, app: UserDefaults = .standard, group: UserDefaults) {
        app.set(shown.rawValue, forKey: appKey)
        group.set(shown.rawValue, forKey: appKey)
    }

    /// A stored value we no longer ship, or never did, is treated as unset.
    private static func stored(_ raw: String?) -> AppLanguage? {
        raw.flatMap(AppLanguage.init(rawValue:))
    }
}
