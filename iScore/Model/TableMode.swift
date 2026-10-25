//
//  TableMode.swift
//  iScore
//
//  Table mode: the phone lies face-up in the middle of the table. These are
//  the decisions it makes — when the halves sit side by side, whether a game
//  opens in it, and what each half says to VoiceOver — kept out of the view.
//

import CoreGraphics
import Foundation
import Observation

enum TableLayout {

    /// A phone lying flat keeps whatever orientation it last had; in
    /// landscape the halves sit side by side instead of stacked.
    static func isSideBySide(_ size: CGSize) -> Bool {
        size.width > size.height
    }
}

enum TableModeSettings {
    static let defaultKey = "tableModeByDefault"
}

/// Whether games open in table mode tonight. Seeded from the Settings default
/// and kept for the session, so the next game of the night opens the same way.
@Observable
final class TableModeSession {

    var isOn: Bool

    init(defaults: UserDefaults = .standard) {
        isOn = defaults.bool(forKey: TableModeSettings.defaultKey)
    }
}

extension Game {

    /// One half of the table, read aloud: "Ana & Luis, 105, 95 to win".
    func tableCardLabel(for team: Team) -> LocalizedStringResource {
        let name = displayName(for: team)
        let total = total(for: team)
        let needed = pointsToWin(for: team)
        if needed == 0 { return "\(name), \(total), won" }
        return "\(name), \(total), \(needed) to win"
    }
}
