//
//  GameSetup.swift
//  iScore
//
//  Rules for setting up a game: target score per game type, the four seats
//  on New Game, and player-name cleanup for the player picker.
//

import Foundation
import SwiftData

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

/// New Game's starting game type and target, saved by Settings.
enum GameDefaults {

    static let typeKey = "defaultGameType"
    static let targetKey = "defaultMaxScore"

    static func load(from defaults: UserDefaults = .standard) -> (type: GameType, target: Int) {
        let type = defaults.string(forKey: typeKey).flatMap(GameType.init(rawValue:)) ?? .nine
        let stored = defaults.object(forKey: targetKey) as? Double
        return (type, type.clampedTarget(stored ?? Double(type.defaultTarget)))
    }
}

/// Which saved player owns this phone, so a spoken "me" has someone to mean.
enum OwnerIdentity {

    static let nameKey = "ownerPlayerName"

    /// The stored name; nil when unset or "Nobody" (stored as an empty string).
    static func load(from defaults: UserDefaults = .standard) -> String? {
        guard let name = defaults.string(forKey: nameKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    /// The saved player's own spelling of `stored`, or nil when that player no
    /// longer exists, so a deleted player cannot haunt "me".
    static func resolve(_ stored: String?, known: [String]) -> String? {
        guard let stored else { return nil }
        return known.first { PlayerName.isSame($0, stored) }
    }
}

/// One seat on New Game (team 1 or 2, first or second player).
struct PlayerSeat: Identifiable {

    let team: Team
    let position: Int

    var id: Int { PlayerLineup.seat(team: team, position: position) }

    /// "Team 2 · Player 2"
    var title: String {
        "\(team.description) · Player \(position + 1)"
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

/// Turns a confirmed setup into a stored game. New Game and the voice sheet
/// both start games through here.
enum GameFactory {

    /// Inserts a game for `resolved`, reusing `existing` players by name and
    /// creating the rest. Expects a complete lineup.
    @discardableResult
    static func make(_ resolved: ResolvedGame, existing: [Player], in context: ModelContext) -> Game {
        let game = Game(gameType: resolved.gameType, maxScore: Double(resolved.target))
        context.insert(game)

        let team1 = resolved.lineup.names(for: .team1)
        let team2 = resolved.lineup.names(for: .team2)
        for name in team1 + team2 {
            let player = existing.first { PlayerName.isSame($0.name, name) } ?? Player(name: name)
            game.players?.append(player)
        }
        game.team1 = team1
        game.team2 = team2
        return game
    }
}

/// The decisions behind the "say the game" sheet, kept out of the view.
enum VoiceSetup {

    enum Opening: Equatable {
        /// Start listening straight away.
        case listen
        /// Ask for microphone and speech access first, then listen.
        case askPermission
        /// Speech cannot work here: go to typing.
        case typeInstead
    }

    static func opening(for availability: SpeechAvailability) -> Opening {
        switch availability {
        case .ready: .listen
        case .needsPermission: .askPermission
        case .denied, .unsupported: .typeInstead
        }
    }

    /// One line saying why the user is typing instead of talking; nil when
    /// nothing went wrong. A thrown unavailability names its own reason.
    static func explanation(availability: SpeechAvailability, error: Error?) -> String? {
        var reason = availability
        if let error {
            guard let failure = error as? SpeechCaptureError else {
                var detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                while detail.hasSuffix(".") { detail.removeLast() }
                return String(localized: "Listening stopped: \(detail). Type the game instead.")
            }
            if case .unavailable(let why) = failure { reason = why }
        }
        switch reason {
        case .ready:
            return nil
        case .needsPermission:
            return String(localized: "Allow the microphone and speech recognition to talk, or type the game instead.")
        case .denied:
            return String(localized: "Microphone or speech access is off. Turn it on in Settings, or type the game instead.")
        case .unsupported:
            return String(localized: "Speech recognition isn't available on this device. Type the game instead.")
        }
    }

    static var heardNothing: String {
        String(localized: "Didn't catch anything. Type the game instead.")
    }

    static var couldntStart: String {
        String(localized: "Couldn't start listening. Type the game instead.")
    }

    /// What to tell the user once a listening session is over, whoever ended it.
    /// `lastError` must be read before anything can restart the recognizer.
    /// Heard words with no error need no notice; an error always gets one.
    static func notice(heard: String, availability: SpeechAvailability, lastError: Error?) -> String? {
        let hasWords = !heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard let lastError else { return hasWords ? nil : heardNothing }
        return explanation(availability: availability, error: lastError) ?? couldntStart
    }

    /// Seated names that match no saved player (and are not the owner), in seat order.
    static func newNames(in lineup: PlayerLineup, known: [String], owner: String?) -> [String] {
        let saved = known + (owner.map { [$0] } ?? [])
        return lineup.names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { name in !name.isEmpty && !saved.contains { PlayerName.isSame($0, name) } }
    }

    /// The pipeline behind both the mic and the typed sentence.
    static func resolve(
        _ sentence: String,
        locale: Locale,
        defaults: (type: GameType, target: Int),
        known: [String],
        owner: String?
    ) async -> ResolvedGame {
        let parsed = GameCommand.parse(sentence, locale: locale)
        let command = await GameCommandModel.enhance(parsed, transcript: sentence, locale: locale, timeout: .seconds(3))
        return command.resolved(defaults: defaults, known: known, owner: owner)
    }
}
