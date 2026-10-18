import Foundation

/// Who is seated where, so "us" and "them" can mean a team. Pure data.
struct ScoreContext: Equatable {
    let team1: [String]
    let team2: [String]
    /// The device owner's player name, or nil when they are not seated.
    let owner: String?

    init(team1: [String], team2: [String], owner: String?) {
        self.team1 = team1
        self.team2 = team2
        self.owner = owner
    }

    /// The team the owner sits on, or `.none` when unseated.
    var ownTeam: Team {
        guard let owner else { return .none }
        if team1.contains(where: { PlayerName.isSame($0, owner) }) { return .team1 }
        if team2.contains(where: { PlayerName.isSame($0, owner) }) { return .team2 }
        return .none
    }
}

/// What a spoken sentence asked the scoreboard to do. The only place that reads words.
enum ScoreCommand: Equatable {
    case record(points: Int, team: Team)
    /// A number with no team reference. Never guessed.
    case askTeam(points: Int)
    case undo
    case whoIsWinning
    case pointsToGo
    case endGame
    case cancelGame
}

extension ScoreCommand {

    /// The most a round can be; matches the keypad's three digits.
    static let maxPoints = 999

    /// nil when nothing in `transcript` is a command.
    static func parse(_ transcript: String, locale: Locale, context: ScoreContext) -> ScoreCommand? {
        let words = tokenize(transcript)
        // Order matters: "cancel the game" must not read as "end game", and a question or
        // an undo must never be read as a new round.
        for (command, phrases) in keywords where phrases.contains(where: { contains(words, $0) }) {
            return command
        }
        guard let points = points(in: transcript, locale: locale) else { return nil }
        let team = team(in: transcript, locale: locale, context: context)
        return team == .none ? .askTeam(points: points) : .record(points: points, team: team)
    }

    /// Which team `transcript` refers to, by the spec's precedence. `.none` when nothing names a team.
    static func team(in transcript: String, locale: Locale, context: ScoreContext) -> Team {
        let words = tokenize(transcript)

        // 1. A player's name, first in the transcript wins.
        for start in words.indices {
            for (team, names) in [(Team.team1, context.team1), (Team.team2, context.team2)] {
                for name in names {
                    let parts = tokenize(name).filter { $0 != breakToken }
                    guard !parts.isEmpty, start + parts.count <= words.count else { continue }
                    if PlayerName.isSame(words[start..<start + parts.count].joined(separator: " "),
                                         parts.joined(separator: " ")) {
                        return team
                    }
                }
            }
        }

        // 2. A team name or color.
        for (team, phrases) in teamWords {
            if phrases.contains(where: { contains(words, $0) }) { return team }
        }

        // 3 and 4. Us and them, relative to the owner, seat order when unseated.
        let own = context.ownTeam == .none ? Team.team1 : context.ownTeam
        let other = own == .team1 ? Team.team2 : Team.team1
        if words.contains(where: { us.contains($0) }) { return own }
        if words.contains(where: { them.contains($0) }) { return other }
        return .none
    }

    /// Largest positive number in `transcript` that a round can be, or nil. Capped at `maxPoints`.
    static func points(in transcript: String, locale: Locale) -> Int? {
        SpokenNumber.scan(tokenize(transcript), locale: locale)
            .map(\.value)
            .filter { (1...maxPoints).contains($0) }
            .max()
    }

    // MARK: - Words

    private static let breakToken = ","

    /// Folded (case and accents) words split on whitespace. Hyphens and apostrophes stay
    /// inside a word ("twenty-five", "who's"); curly apostrophes are straightened; any other
    /// punctuation becomes a break token so a phrase cannot span a pause.
    private static func tokenize(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { words.append(current) }
            current = ""
        }
        let straight = text.replacingOccurrences(of: "\u{2019}", with: "'")
        for character in straight {
            if character.isLetter || character.isNumber || character == "-" || character == "'" {
                current.append(character)
            } else {
                flush()
                if !character.isWhitespace { words.append(breakToken) }
            }
        }
        flush()
        return words.map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) }
    }

    /// True when `phrase` (space-separated, already folded) appears as a run of whole words.
    private static func contains(_ words: [String], _ phrase: String) -> Bool {
        let parts = phrase.split(separator: " ").map(String.init)
        guard !parts.isEmpty, words.count >= parts.count else { return false }
        return (0...words.count - parts.count).contains { Array(words[$0..<$0 + parts.count]) == parts }
    }

    /// Checked in this order.
    private static let keywords: [(ScoreCommand, [String])] = [
        (.cancelGame, ["cancel the game", "cancel this game", "cancel game", "throw it out",
                       "cancela el juego", "cancelar juego", "anula el juego"]),
        (.endGame, ["end the game", "end game", "game over", "we're done",
                    "termina el juego", "terminar juego", "se acabo"]),
        (.undo, ["undo", "take that back", "scratch that",
                 "quita eso", "quitalo", "borra eso", "deshacer"]),
        (.pointsToGo, ["how many to go", "how many left", "how much to win",
                       "cuanto falta", "cuanto queda"]),
        (.whoIsWinning, ["who's winning", "who is winning", "what's the score", "the score",
                         "quien va ganando", "quien gana", "como vamos"]),
    ]

    private static let teamWords: [(Team, [String])] = [
        (.team1, ["team one", "team 1", "equipo uno", "equipo 1", "green", "verde"]),
        (.team2, ["team two", "team 2", "equipo dos", "equipo 2", "blue", "azul"]),
    ]

    private static let us: Set<String> = ["us", "we", "nosotros", "nosotras"]
    private static let them: Set<String> = ["them", "they", "ellos", "ellas"]
}
