//
//  GameSetup.swift
//  iScore
//
//  Rules for setting up a game: target score per game type, the four seats
//  on New Game, and player-name cleanup for the player picker.
//

import Foundation

extension GameType {

    /// "Double 6" / "Double 9"
    var title: String {
        "Double \(pips)"
    }

    /// The target moves in steps of 10.
    static let targetStep = 10

    /// A target of 0 would end the game on the first score.
    var targetRange: ClosedRange<Int> {
        switch self {
        case .six: 10...100
        case .nine: 10...200
        }
    }

    /// Target picked when switching to this game type.
    var defaultTarget: Int {
        switch self {
        case .six: 20
        case .nine: 100
        }
    }

    /// Rounds to the nearest step and keeps it in `targetRange`.
    func clampedTarget(_ value: Double) -> Int {
        let step = Double(Self.targetStep)
        let rounded = Int((value / step).rounded() * step)
        return min(max(rounded, targetRange.lowerBound), targetRange.upperBound)
    }

    /// One − / + tap on the target stepper (`direction` is -1 or 1).
    func steppedTarget(_ current: Int, by direction: Int) -> Int {
        clampedTarget(Double(current + direction * Self.targetStep))
    }
}

/// The four seats on New Game: team 1 is seats 0–1, team 2 is seats 2–3.
struct PlayerLineup: Equatable {

    var names = ["", "", "", ""]

    static func seat(team: Team, position: Int) -> Int {
        (team == .team2 ? 2 : 0) + position
    }

    private var trimmed: [String] {
        names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private var filled: [String] {
        trimmed.filter { !$0.isEmpty }
    }

    private var hasDuplicates: Bool {
        Set(filled.map { $0.lowercased() }).count < filled.count
    }

    /// Four names, no two the same (ignoring case).
    var isComplete: Bool {
        filled.count == names.count && !hasDuplicates
    }

    /// Why Start is disabled; nil when the lineup is complete.
    var hint: String? {
        let missing = names.count - filled.count
        if missing == 1 { return "Add 1 more player to start" }
        if missing > 1 { return "Add \(missing) more players to start" }
        if hasDuplicates { return "Pick 4 different players" }
        return nil
    }

    func names(for team: Team) -> [String] {
        switch team {
        case .team1: Array(trimmed[0...1])
        case .team2: Array(trimmed[2...3])
        case .none: []
        }
    }

    /// Names in the other seats, so the picker can gray them out.
    func pickedNames(excludingSeat seat: Int) -> [String] {
        trimmed.enumerated()
            .filter { $0.offset != seat && !$0.element.isEmpty }
            .map(\.element)
    }
}

enum PlayerName {

    static let maxLength = 15

    /// Applied while typing.
    static func limited(_ text: String) -> String {
        String(text.prefix(maxLength))
    }

    /// Trims the typed name and reuses an existing player's spelling when
    /// it only differs by case, so "ana" doesn't create a second "Ana".
    static func resolve(_ typed: String, existing: [String]) -> String {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return existing.first { isSame($0, name) } ?? name
    }

    static func isSame(_ lhs: String, _ rhs: String) -> Bool {
        let clean = { (name: String) in name.trimmingCharacters(in: .whitespacesAndNewlines) }
        return clean(lhs).caseInsensitiveCompare(clean(rhs)) == .orderedSame
    }

    /// Picker search; an empty query matches everyone.
    static func matches(_ name: String, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || name.localizedStandardContains(query)
    }
}
