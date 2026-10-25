//
//  GamePreset.swift
//  iScore
//
//  A saved game setup — "Friday night" = Double 9, 200, the usual four —
//  started with one tap from Home or by saying its name. The model only
//  stores; every decision runs on `PresetSetup`, a plain value, so it is
//  tested without a store.
//
//  CloudKit: every property has a default and there are no relationships.
//  Players are kept as names and matched to saved players when started.
//

import Foundation
import SwiftData

@Model
final class GamePreset {

    var name: String = ""
    var gameType: GameType = GameType.nine
    var target: Int = 200
    var playerNames: [String] = ["", "", "", ""]
    var created: Date = Date()
    /// Orders the Home row; nil until the preset is first started.
    var lastUsed: Date?

    init(_ setup: PresetSetup) {
        name = setup.name
        gameType = setup.gameType
        target = setup.target
        playerNames = setup.playerNames
    }

    var setup: PresetSetup {
        PresetSetup(name: name, gameType: gameType, target: target, playerNames: playerNames)
    }
}

/// A preset as a value: what it would start.
struct PresetSetup: Equatable, Sendable {

    var name: String
    var gameType: GameType
    var target: Int
    /// Seats 0–1 are team 1, seats 2–3 team 2, as on New Game.
    var playerNames: [String]

    init(name: String, gameType: GameType, target: Int, playerNames: [String]) {
        self.name = name
        self.gameType = gameType
        self.target = target
        self.playerNames = playerNames
    }

    /// "Save this setup" from a game.
    init(game: Game, name: String) {
        self.init(name: name, gameType: game.gameType, target: Int(game.maxScore),
                  playerNames: Array((game.team1 + ["", ""]).prefix(2)) + Array((game.team2 + ["", ""]).prefix(2)))
    }

    /// Four names, none blank, no player twice.
    var isComplete: Bool {
        let names = playerNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard names.count == 4, !names.contains(where: \.isEmpty) else { return false }
        return names.indices.allSatisfy { index in
            !names[..<index].contains { PlayerName.isSame($0, names[index]) }
        }
    }

    /// The game this preset starts: names take the saved players' spelling,
    /// and a target stored outside today's range is clamped.
    func resolved(known: [String]) -> ResolvedGame {
        var lineup = PlayerLineup()
        var newNames: [String] = []
        for (seat, stored) in playerNames.prefix(4).enumerated() {
            let name = PlayerName.limited(PlayerName.resolve(stored, existing: known))
            lineup.names[seat] = name
            if !known.contains(where: { PlayerName.isSame($0, name) }) { newNames.append(name) }
        }
        return ResolvedGame(gameType: gameType,
                            target: gameType.clampedTarget(Double(target)),
                            lineup: lineup,
                            newNames: newNames)
    }

    /// Seat names that match no saved player, in seat order.
    func missingPlayers(known: [String]) -> [String] {
        playerNames.filter { name in !known.contains { PlayerName.isSame($0, name) } }
    }

    /// "Friday night, Double 9 to 200, Ana, Luis, Rafa, Mia"
    var accessibilityLabel: LocalizedStringResource {
        let names = (playerNames + ["", "", "", ""]).prefix(4)
        return "\(name), \(gameType.title) to \(target), \(names[0]), \(names[1]), \(names[2]), \(names[3])"
    }
}

enum PresetName {

    static let maxLength = 24

    static func cleaned(_ typed: String) -> String {
        String(typed.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
    }

    static func isTaken(_ name: String, among existing: [String]) -> Bool {
        existing.contains { PlayerName.isSame($0, name) }
    }
}

enum PresetList {

    /// One card per name — two devices can save the same name before they
    /// sync, and the oldest copy wins — then the three most recently used.
    static func homeRow(_ presets: [GamePreset]) -> [GamePreset] {
        let duplicates = Set(duplicates(in: presets).map(ObjectIdentifier.init))
        return presets
            .filter { !duplicates.contains(ObjectIdentifier($0)) }
            .sorted { ($0.lastUsed ?? $0.created) > ($1.lastUsed ?? $1.created) }
            .prefix(3)
            .map { $0 }
    }

    /// Every preset that is not the oldest one with its name.
    static func duplicates(in presets: [GamePreset]) -> [GamePreset] {
        var kept: [GamePreset] = []
        var extras: [GamePreset] = []
        for preset in presets.sorted(by: { $0.created < $1.created }) {
            if kept.contains(where: { PlayerName.isSame($0.name, preset.name) }) {
                extras.append(preset)
            } else {
                kept.append(preset)
            }
        }
        return extras
    }
}
