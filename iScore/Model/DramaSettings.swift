//
//  DramaSettings.swift
//  iScore
//
//  "Call out big moments": on unless the user turns it off. Off means no
//  highlight anywhere — banner, summary or spoken line.
//

import Foundation

enum DramaSettings {

    static let enabledKey = "roundDramaEnabled"

    /// `bool(forKey:)` reads a missing key as false, so presence is checked first.
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: enabledKey) != nil else { return true }
        return defaults.bool(forKey: enabledKey)
    }
}
