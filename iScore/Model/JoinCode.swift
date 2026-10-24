//
//  JoinCode.swift
//  iScore
//
//  The short code a scorekeeper reads to the table so the others can watch.
//  Four characters from an alphabet with no lookalikes — no 0/O, no 1/I — so
//  a code said out loud is typed right the first time.
//

import Foundation

struct JoinCode: Equatable, Hashable, CustomStringConvertible {

    static let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    static let length = 4

    let value: String

    var description: String { value }

    private init(value: String) {
        self.value = value
    }

    static func random<G: RandomNumberGenerator>(using generator: inout G) -> JoinCode {
        let characters = Array(alphabet)
        let picked = (0..<length).map { _ in characters.randomElement(using: &generator)! }
        return JoinCode(value: String(picked))
    }

    static func random() -> JoinCode {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    /// What someone typed, forgiving case, spaces and hyphens. Nil when it
    /// cannot be a code, so the Join button stays off rather than searching
    /// for a game that does not exist.
    init?(typed: String) {
        let cleaned = typed.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard cleaned.count == Self.length, cleaned.allSatisfy(Self.alphabet.contains) else { return nil }
        self.value = cleaned
    }
}
