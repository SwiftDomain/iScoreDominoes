//
//  PointGrid.swift
//  iScore
//
//  The point values the Lock Screen offers per team. A round outside the
//  grid opens the app; everything else is one tap with the phone locked.
//
//  Values are *chosen* by how often the user actually scores them and
//  *shown* in ascending order, so a button keeps its place between rounds.
//

import Foundation

enum PointGrid {

    /// Buttons per team. Six fits one row at Lock Screen width.
    static let size = 6

    /// How many history sightings a default is worth. A value the user has
    /// scored more often than this takes a default's slot; a one-off does not.
    static let defaultWeight = 2

    static func defaults(for type: GameType) -> [Int] {
        switch type {
        case .six: [5, 10, 15, 20, 25, 30]
        case .nine: [10, 20, 25, 30, 40, 50]
        }
    }

    /// `history` is every round value recorded for this game type, in the
    /// order they were scored.
    static func values(for type: GameType, history: [Int], limit: Int = size) -> [Int] {
        let fallback = defaults(for: type)
        guard limit > 0 else { return [] }

        var weight: [Int: Int] = [:]
        for (index, value) in fallback.enumerated() {
            // Earlier defaults win ties, hence the small index penalty.
            weight[value] = defaultWeight * fallback.count - index
        }
        for value in history where value > 0 {
            weight[value, default: 0] += fallback.count
        }

        let ranked = weight.sorted { left, right in
            left.value == right.value ? left.key < right.key : left.value > right.value
        }
        return ranked.prefix(limit).map(\.key).sorted()
    }
}
