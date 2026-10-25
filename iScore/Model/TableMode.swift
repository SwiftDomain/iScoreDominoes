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

    /// The Settings default changed: tonight follows it straight away.
    func followDefault(_ on: Bool) {
        isOn = on
    }
}

enum TableModeRules {

    /// Only a game being played is shown on the table. A finished or
    /// cancelled game falls back to the normal screen, so no half can add a
    /// round to a settled game; the next game still opens in table mode.
    static func isShown(sessionOn: Bool, state: GameState) -> Bool {
        sessionOn && state == .playing
    }

    /// The center strip's line, by the bottom bar's own rule: a spoken answer
    /// outranks the mic's line. Nil means show the round line.
    static func stripLine(answer: String?, mic: String?) -> String? {
        answer ?? mic
    }

    enum Tap: Equatable {
        case record(points: Int, team: Team)
        case openKeypad(Team)
    }

    /// A number heard with no team is finished by tapping a half; otherwise a
    /// tap opens that team's keypad.
    static func tap(_ team: Team, pending: Int?) -> Tap {
        if let pending { return .record(points: pending, team: team) }
        return .openKeypad(team)
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
