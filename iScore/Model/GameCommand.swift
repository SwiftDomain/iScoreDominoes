import Foundation

/// What a spoken game description said, before defaults, clamping or saved players are applied.
/// Every field is optional or empty because players can say the pieces in any order, or leave
/// some out. Pure logic: it knows nothing about the player list.
struct GameCommand: Equatable {
    var gameType: GameType?
    var target: Int?
    var team1: [String] = []
    var team2: [String] = []
    /// True when the sentence carried nothing usable, so Task 6 knows to try the model.
    var isEmpty: Bool { gameType == nil && target == nil && team1.isEmpty && team2.isEmpty }

    /// Reads `transcript` in any word order. The first spoken 6 or 9 picks the game type; the
    /// first other number inside that type's target range (the widest range if no type was
    /// said) is the target; what is left after dropping filler is names, split into teams at
    /// the separator word, or 2 and 2 if there was none.
    static func parse(_ transcript: String, locale: Locale) -> GameCommand {
        let original = tokenize(transcript)
        let lowered = original.map { $0.lowercased() }
        var command = GameCommand()

        var consumed = Set<Int>()
        var candidates: [Int] = []
        for hit in numbers(in: lowered, locale: locale) {
            consumed.formUnion(hit.range)
            if command.gameType == nil, hit.value == 6 || hit.value == 9 {
                command.gameType = hit.value == 6 ? .six : .nine
            } else {
                candidates.append(hit.value)
            }
        }
        let range = command.gameType?.targetRange ?? 10...200
        command.target = candidates.first(where: range.contains)

        var names: [String] = []
        var splitIndex: Int?
        for (index, word) in lowered.enumerated() where !consumed.contains(index) {
            if separators.contains(word) {
                if splitIndex == nil { splitIndex = names.count }
            } else if !stopWords.contains(word) {
                names.append(original[index])
            }
        }
        let split = splitIndex ?? min(2, names.count)
        command.team1 = Array(names[..<split])
        command.team2 = Array(names[split...])
        return command
    }

    // MARK: - Words

    /// Words split on whitespace. Hyphens and apostrophes stay inside a word ("twenty-five",
    /// "D'Angelo"); "&" reads as "and"; any other punctuation becomes a "," break token, so a
    /// pause ("two hundred, nine") keeps neighbouring numbers apart.
    private static func tokenize(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { words.append(current) }
            current = ""
        }
        for character in text.replacingOccurrences(of: "&", with: " and ") {
            if character.isLetter || character.isNumber || character == "-" || character == "'" {
                current.append(character)
            } else {
                flush()
                if !character.isWhitespace { words.append(breakToken) }
            }
        }
        flush()
        return words
    }

    private static let breakToken = ","

    /// `SpokenNumber.scan`, except that a lone 6 or 9 right after a whole-hundreds number is its
    /// own hit. Said without a pause, "two hundred nine" is a target and a game type, not 209.
    private static func numbers(in words: [String], locale: Locale) -> [(value: Int, range: Range<Int>)] {
        SpokenNumber.scan(words, locale: locale).flatMap { hit -> [(value: Int, range: Range<Int>)] in
            guard hit.value >= 100, hit.value % 100 == 6 || hit.value % 100 == 9,
                  hit.range.count > 1 else { return [hit] }
            let last = hit.range.upperBound - 1
            let head = SpokenNumber.scan(Array(words[hit.range.lowerBound..<last]), locale: locale)
                .map { (value: $0.value, range: ($0.range.lowerBound + hit.range.lowerBound)..<($0.range.upperBound + hit.range.lowerBound)) }
            return head + [(hit.value % 100, last..<hit.range.upperBound)]
        }
    }

    private static let separators: Set<String> = ["against", "versus", "vs", "contra"]

    /// Words that are never part of a name: articles, connectors, "double", number words the
    /// scanner does not cover ("thousand"), and spoken filler.
    private static let stopWords: Set<String> = [
        breakToken, "the", "a", "an", "to", "and", "y", "double", "doble", "thousand", "mil",
        "uh", "um", "hmm", "okay", "ok", "so", "eh", "pues", "bueno",
    ]
}

/// A spoken command with defaults filled in and names matched to saved players, ready for the
/// confirmation card to show and start.
struct ResolvedGame: Equatable {
    let gameType: GameType
    let target: Int
    let lineup: PlayerLineup
    /// Heard names that match no existing player — shown as new on the card.
    let newNames: [String]
}

extension GameCommand {

    /// `known` is every saved player's name; `owner` is the device owner's player name, or nil
    /// when they are not a player. "me" / "yo" becomes `owner`, or is dropped without one.
    /// Names are matched to `known` (existing spelling wins), truncated, and seated once each
    /// (first mention wins, across both teams). The speaker named the sides, so team 1's names
    /// go to seats 0–1 and team 2's to seats 2–3, in heard order; a dropped or repeated name
    /// leaves its seat empty and a third name on one side is ignored.
    func resolved(defaults: (type: GameType, target: Int),
                  known: [String],
                  owner: String?) -> ResolvedGame {
        let type = gameType ?? defaults.type
        let target = type.clampedTarget(Double(self.target ?? defaults.target))
        let saved = known + (owner.map { [$0] } ?? [])

        var lineup = PlayerLineup()
        var newNames: [String] = []
        for (heardNames, firstSeat) in [(team1, 0), (team2, 2)] {
            var taken = 0
            for heard in heardNames where taken < 2 {
                let name: String
                if Self.selfWords.contains(heard.lowercased()) {
                    guard let owner else { continue }
                    name = owner
                } else {
                    name = PlayerName.resolve(heard, existing: saved)
                }
                let limited = PlayerName.limited(name)
                guard !limited.isEmpty,
                      !lineup.names.contains(where: { PlayerName.isSame($0, limited) }) else { continue }
                lineup.names[firstSeat + taken] = limited
                taken += 1
                if !saved.contains(where: { PlayerName.isSame($0, name) }) { newNames.append(limited) }
            }
        }
        return ResolvedGame(gameType: type, target: target, lineup: lineup, newNames: newNames)
    }

    /// How a speaker refers to themselves, in English and Spanish.
    private static let selfWords: Set<String> = ["me", "yo"]
}
