//
//  ScoreEntry.swift
//  iScore
//
//  Digits typed on the Add Score keypad. Never produces a 0-point round:
//  a leading 0 is ignored, so `value` is either nil or positive.
//

import Foundation

struct ScoreEntry: Equatable {

    static let maxDigits = 3

    private(set) var digits = ""

    /// Adds a digit 0…9. Ignores a leading 0 and anything past `maxDigits`.
    mutating func append(_ digit: Int) {
        guard (0...9).contains(digit),
              digits.count < Self.maxDigits,
              !(digits.isEmpty && digit == 0) else { return }
        digits.append(String(digit))
    }

    /// Replaces whatever is typed with `points`, for a value that arrives whole (spoken).
    /// `append` is digit-at-a-time, so a spoken 25 over a typed 3 would be 325; this is 25.
    /// Ignores anything non-positive or wider than `maxDigits`, leaving the entry as it was.
    mutating func set(_ points: Int) {
        guard points > 0, String(points).count <= Self.maxDigits else { return }
        digits = String(points)
    }

    mutating func deleteLast() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }

    mutating func clear() {
        digits = ""
    }

    var value: Int? {
        Int(digits)
    }

    /// Returns the value and clears the entry, so a second tap gets nil
    /// (the Add button stays live while the sheet animates away).
    mutating func take() -> Int? {
        defer { clear() }
        return value
    }

    /// What the confirm button does. Whole phrases rather than a verb glued
    /// onto a noun, so each language can order and inflect them its own way.
    enum Verb {
        case add, save
    }

    var buttonTitle: LocalizedStringResource {
        title(.add)
    }

    /// "Save 35 points" / "Save points"
    func title(_ verb: Verb) -> LocalizedStringResource {
        guard let points = value else {
            switch verb {
            case .add: return "Add points"
            case .save: return "Save points"
            }
        }
        switch verb {
        case .add: return "Add \(points) points"
        case .save: return "Save \(points) points"
        }
    }
}
