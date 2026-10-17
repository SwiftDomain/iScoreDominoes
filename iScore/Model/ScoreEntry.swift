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

    var buttonTitle: String {
        switch value {
        case nil: "Add points"
        case 1: "Add 1 point"
        case let points?: "Add \(points) points"
        }
    }
}
