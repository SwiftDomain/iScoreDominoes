//
//  LanguageRelaunch.swift
//  iScore
//
//  Applying the app language. `AppleLanguages` is read when the bundle loads,
//  so a change only takes effect on the next launch — the picker says so and
//  offers to relaunch rather than pretending the switch was live.
//
//  This governs the app process only. The Lock Screen widget runs in its own
//  process with its own bundle and does not inherit this override; it reads
//  `LanguageSettings.appKey` and resolves against an explicit locale instead.
//

import Foundation

enum LanguageRelaunch {

    /// Foundation's own key for the per-app language override.
    static let overrideKey = "AppleLanguages"

    static func needsRelaunch(changing from: AppLanguage, to new: AppLanguage) -> Bool {
        from != new
    }

    /// Writes both the override the bundle reads at launch and the plain value
    /// the pickers read now, so the two cannot drift apart.
    static func apply(_ language: AppLanguage, to defaults: UserDefaults = .standard) {
        defaults.set([language.rawValue], forKey: overrideKey)
        defaults.set(language.rawValue, forKey: LanguageSettings.appKey)
    }
}
