//
//  WidgetLanguage.swift
//  iScore
//
//  The widget runs in its own process with its own bundle, so it does not
//  inherit the app's `AppleLanguages` override — setting that override only
//  changes the app. The widget therefore reads the chosen language out of the
//  shared App Group and resolves each string against an explicit locale.
//
//  Keep this file free of anything the widget cannot link.
//

import Foundation

enum WidgetLanguage {

    /// The app language, as the app last wrote it to the shared container.
    /// Falls back to the device's language, then to English.
    static var locale: Locale {
        let raw = AppGroup.defaults.string(forKey: LanguageSettings.appKey)
        let language = raw.flatMap(AppLanguage.init(rawValue:)) ?? .matching(.current)
        return Locale(identifier: language.rawValue)
    }

    /// Resolves a resource in the app's chosen language rather than the
    /// widget process's own.
    static func text(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }
}
