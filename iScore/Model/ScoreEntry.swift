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

    var buttonTitle: String {
        title("Add")
    }

    /// "Save 35 points" / "Save 1 point" / "Save points"
    func title(_ verb: String) -> String {
        switch value {
        case nil: "\(verb) points"
        case 1: "\(verb) 1 point"
        case let points?: "\(verb) \(points) points"
        }
    }
}
