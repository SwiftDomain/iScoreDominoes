import Foundation
import FoundationModels

/// The optional second layer behind `GameCommand.parse`. The deterministic parser is primary and
/// works on every device; this layer only runs when it came back short *and* the on-device model
/// is available. Every failure (no model, unsupported language, throw, timeout, guardrail
/// refusal, nonsense) collapses to "return the deterministic command unchanged".
///
/// What it exists to catch: a two-word name ("Juan Carlos") arrives from the parser as two
/// names, and unusual phrasing or unfamiliar spellings can leave names missing.
///
/// The decisions (`needsModel`, `merged`, `command(from:)`) are pure and tested; `enhance` is the
/// only code that touches `FoundationModels`.
enum GameCommandModel {

    /// True unless both teams already have exactly two names. A missing game type or target is
    /// not a reason: those fall back to the user's defaults, and the model cannot know them.
    /// A 3-and-1 split also counts, since that is what a two-word name looks like.
    static func needsModel(_ command: GameCommand) -> Bool {
        command.team1.count != 2 || command.team2.count != 2
    }

    /// Deterministic fields win; the model only fills what is still nil or empty. One exception
    /// for teams: a team that is not exactly two names is replaced by the model's two-name
    /// team, but only if that team accounts for every word the parser heard ("Juan", "Carlos"
    /// becomes "Juan Carlos"; ["Ana"] becomes ["Ana", "Carlos"]). A model team that contradicts
    /// what was heard is ignored.
    static func merged(deterministic: GameCommand, model: GameCommand) -> GameCommand {
        var result = deterministic
        if result.gameType == nil { result.gameType = model.gameType }
        if result.target == nil { result.target = model.target }
        result.team1 = team(deterministic.team1, completedBy: model.team1)
        result.team2 = team(deterministic.team2, completedBy: model.team2)
        return result
    }

    private static func team(_ heard: [String], completedBy suggested: [String]) -> [String] {
        guard heard.count != 2, suggested.count == 2 else { return heard }
        if heard.isEmpty { return suggested }
        let suggestedWords = Set(suggested.flatMap(words))
        return heard.flatMap(words).allSatisfy(suggestedWords.contains) ? suggested : heard
    }

    private static func words(_ name: String) -> [String] {
        name.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Turns the model's raw fields into a command, dropping anything unusable: an unknown game
    /// type, a target outside the widest target range, blank or repeated names.
    static func command(gameType: String?, target: Int?, team1: [String], team2: [String]) -> GameCommand {
        var command = GameCommand()
        switch gameType?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "six", "6": command.gameType = .six
        case "nine", "9": command.gameType = .nine
        default: break
        }
        if let target, (10...200).contains(target) { command.target = target }
        var seen = Set<String>()
        func clean(_ names: [String]) -> [String] {
            names.compactMap { raw in
                let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return !name.isEmpty && seen.insert(name.lowercased()).inserted ? name : nil
            }
        }
        command.team1 = clean(team1)
        command.team2 = clean(team2)
        return command
    }

    /// Runs the model when it is available, else returns `deterministic` unchanged. Never throws
    /// and never exceeds `timeout`: the model call races a timer, and whichever finishes first
    /// decides, so a call that ignores cancellation cannot hold the caller up.
    static func enhance(_ deterministic: GameCommand,
                        transcript: String,
                        locale: Locale,
                        timeout: Duration) async -> GameCommand {
        guard needsModel(deterministic),
              !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              SystemLanguageModel.default.availability == .available,
              SystemLanguageModel.default.supportsLocale(locale) else { return deterministic }

        let answer = await withCheckedContinuation { (continuation: CheckedContinuation<GameCommand?, Never>) in
            let gate = OneShot(continuation)
            let work = Task { gate.finish(await ask(transcript: transcript, locale: locale)) }
            let timer = Task {
                try? await Task.sleep(for: timeout)
                gate.finish(nil)
                work.cancel()
            }
            Task { _ = await work.value; timer.cancel() }
        }
        guard let answer else { return deterministic }
        return merged(deterministic: deterministic, model: answer)
    }

    // MARK: - Model call

    @Generable
    struct Heard {
        @Guide(description: "Which domino set: six for double-six, nine for double-nine, unknown if not said.",
               .anyOf(["six", "nine", "unknown"]))
        var gameType: String
        @Guide(description: "The score needed to win, if said.")
        var target: Int?
        @Guide(description: "The first team's players. A full name such as Juan Carlos is ONE player. The speaker may call themselves me or yo; keep that word as is.")
        var team1: [String]
        @Guide(description: "The second team's players, after the word against or versus.")
        var team2: [String]
    }

    /// Nil on any failure or refusal.
    private static func ask(transcript: String, locale: Locale) async -> GameCommand? {
        let session = LanguageModelSession(instructions: """
            You read one spoken sentence that sets up a 2 versus 2 domino game and report what it \
            said. Do not invent anything that was not said. Names are people; a two-word name like \
            Juan Carlos is one person. Each team has two players. The sentence may be in English or \
            Spanish.
            """)
        guard let heard = try? await session.respond(to: transcript, generating: Heard.self).content else { return nil }
        let command = command(gameType: heard.gameType, target: heard.target, team1: heard.team1, team2: heard.team2)
        return command.isEmpty ? nil : command
    }

    /// Resumes a continuation exactly once, from whichever of two tasks gets there first.
    private final class OneShot: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<GameCommand?, Never>?

        init(_ continuation: CheckedContinuation<GameCommand?, Never>) { self.continuation = continuation }

        func finish(_ value: GameCommand?) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(returning: value)
        }
    }
}
