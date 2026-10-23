# Voice and Keypad as Equal Doors — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything the keypad can do can be said, and everything that can be said has a visible touch equivalent: a push-to-talk mic button on `GameView` and in the Add Score sheet records a round for either team, undoes the last one, answers "who's winning?" and "how many to go?" out loud, and ends or cancels the game behind a confirmation tap — in English or Spanish, confirmed through the same `RoundFeedbackBanner` the touch path already uses.

**Architecture:** Three pure layers and one thin view. `ScoreCommand.parse` turns a transcript plus a `ScoreContext` (the two teams' names and the device owner) into an action — it is the only place that reads words. `VoiceScoring.outcome` turns that action plus what the game currently allows into one of seven outcomes, and is the only place that decides what happens; it never touches a `Game`. `Game+Voice` supplies the two spoken answers as copy. `VoiceScoreBar` is a single reusable view that owns the mic button, the listening state and the live transcript, and hands its host an `Outcome` to apply — so `GameView` and `AddGameScoreView` share one mic and one state machine. Feature 1's `SpeechCapture` is reused unchanged; nothing in this feature is always-listening and nothing blocks on speech.

**Tech Stack:** SwiftUI, SwiftData, Speech (`SFSpeechRecognizer`, via Feature 1's `SpeechCapture`), AVFoundation (`AVSpeechSynthesizer`), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md` (Feature 3; the Intent, Goals, Anti-goals and Constraints sections apply in full)

**Branch:** `voice-and-keypad`, off `worktree-say-the-game` with `origin/main` merged in — both confirmed with the owner on 2026-10-18. Feature 3 reuses Feature 1's `SpeechCapture`, `SpokenNumber`, `VoiceSetup` and `OwnerIdentity`, which exist only on Feature 1's branch, so **this PR stacks on PR #4 and can only merge after it.** Feature 2 landed on `main` as PR #5 while this plan was being written; the merge commit `c6bfc81` brought it in and resolved its three conflicts, so this branch already carries the `iScoreWidgets` target, `iScore/Shared/`, and `GameView`'s Live Activity wiring. Work happens in the worktree at `.claude/worktrees/voice-doors`.

**Baseline at plan time:** 236 tests in 32 suites pass on this branch (Feature 1's suites on top of main's 145). Any task that reports fewer has lost something.

**Git hygiene:** **never `git add -A`**, and note that a bare `git commit` commits the whole index, not the paths named alongside it — stage explicitly and check `git status` before every commit. (That is how an unrelated app-icon change ended up in Feature 2's history.)

**Voice language:** Feature 4 (two language settings) is not built, so every recognizer and every synthesizer in this feature takes `Locale.current`, exactly as `VoiceGameSheet` already does. Each call site passes a `locale` parameter rather than reading `.current` inside, so Feature 4 changes one line per site and nothing in the pure layer.

## Global Constraints

- iOS 26 deployment target, Swift 5 language mode, SwiftUI + SwiftData.
- SwiftData syncs via CloudKit (`cloudKitDatabase: .automatic`): **every new persisted property needs a default value and every new relationship must be optional.** This plan adds **no** `@Model` types and **no** new properties to `Game` or `Player`. The two new settings are `@AppStorage`, not model state.
- `Game.scoreTeam` is `[[Int]]` with a seed `[0, 0]` row; every real round is one-sided. Do not change this shape. Rounds are appended and undone **only** through the existing `Game.addRound(_:for:)` and `Game.undoLastRound()`.
- No `Color` literals in views. Semantic colors come from `Theme` only. Any new colorset goes in `Assets.xcassets` **and** `Theme.colorAssetNames`, or `ThemeTests` fails. **This plan adds no new colorsets** — the mic button uses `Theme.palette(for:)` and `Theme.learn`/`Theme.learnShadow`, all of which exist.
- Type is `DuoFont` (`.score`, `.title`, `.body`, `.label`). Cards: radius 16, 2pt border, 4pt bottom edge. Buttons: radius 14, 4pt darker bottom edge. No gradients, shadows, blur or glass.
- Logic lives in pure types in `iScore/Model/` with Swift Testing coverage in `iScoreTests`. Views stay thin.
- Every new Swift file is registered: `ruby scripts/xcodeproj.rb add iScore <path>` for app files, `add iScoreTests <path>` for test files. Run it in the same step the file is created, before the build. **`project.pbxproj` is never hand-edited** — the script gained `set <target> KEY=value` in the merge commit for build settings, so extend the script if it cannot express something.
- **Nothing in this feature belongs in `iScore/Shared/`.** That directory is the app↔widget boundary from Feature 2, and a file there must be registered against each of `iScore`, `iScoreWidgets` and `iScoreTests` separately. Voice is app-only: the widget process must never link `Speech` or `AVSpeechSynthesizer`. Every new file in this plan goes in `iScore/Model/` or `iScore/Views/`.
- `GameView` now carries Feature 2's Live Activity wiring (`.task`, two `.onChange`, `drainLockScreenRounds()`, `roundHistory`). Task 6 adds to that view; it must not remove any of it. The existing `.onChange(of: game.scoreTeam)` means a voice-recorded round reaches the Lock Screen activity for free — do not add a second refresh call.
- User-facing strings go through `String(localized:)` as Feature 1's do, so Feature 4's extraction pass finds them.
- Player names cap at 15 characters and compare case-insensitively (`PlayerName.isSame`). Spoken names resolve through the existing helpers; voice never creates a player.
- **Push-to-talk only.** No wake phrase, no continuous recognition, no recognizer started by anything other than a tap. A listening session always ends by itself, by a second tap, or on `onDisappear`.
- Test command used throughout:
  `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:<suite-path>`
  **The OS must be pinned.** This machine has an iPhone 17 Pro on both 26.4 and 26.5, and the bare name makes `xcodebuild` fall through to a macOS destination and error out. Heavy CloudKit error logging in simulator output is known noise (no iCloud account in the simulator).

## Review Focus

Input classes the spec implies that no task's happy-path tests would otherwise exercise. Each has its test pinned to the task that owns the code.

1. **Table conversation heard as a score.** A bare number with no team reference ("twenty-five", mid-sentence). Expected: never recorded against a guessed team — it becomes `.askTeam(points:)` and the user taps which team, with the points already filled in. A sentence with neither a number nor a command word is refused, not acted on. → Task 1 and Task 3.
2. **A spoken round that wins the game.** Expected: the voice path finishes the game and opens the summary exactly as the touch path does — the win is not left on screen as a banner with the game still playing. → Task 6.
3. **Speaking into an Add Score keypad that already holds digits.** Expected: the spoken value replaces the typed digits rather than concatenating with them ("3" typed + "twenty-five" spoken must never become 325). → Task 7.
4. **"Undo" with nothing to undo, or any command on a finished or cancelled game.** Expected: a refusal line shown and spoken, no crash, no phantom or negative round, and `scoreTeam` unchanged. → Task 3.
5. **Speech denied, restricted or unsupported.** Expected: the mic button is never a dead end — it explains itself in one line and the keypad remains fully usable. The button does not vanish (a missing control cannot be discovered) and tapping it does not silently do nothing. → Task 5.
6. **Answers suppressed on silent, or with speech turned off in Settings.** Expected: a suppressed answer still appears on screen. Suppression silences the voice, never the answer. → Task 4 and Task 6.

---

### Task 1: `ScoreCommand` — the transcript parser

The only place in the feature that reads words. Pure, no `Game`, no speech, no views.

**Files:**
- Create: `iScore/Model/ScoreCommand.swift`
- Create: `iScoreTests/ScoreCommandTests.swift`

**Interfaces:**
- Consumes: `SpokenNumber.scan(_:locale:)` and `SpokenNumber.parse(_:locale:)` (Feature 1, `iScore/Model/SpokenNumber.swift`); `PlayerName.isSame(_:_:)` (`iScore/Model/GameSetup.swift`); `Team`.
- Produces:
  ```swift
  struct ScoreContext: Equatable {
      let team1: [String]
      let team2: [String]
      /// The device owner's player name, or nil when they are not seated.
      let owner: String?
      init(team1: [String], team2: [String], owner: String?)
      /// The team the owner sits on, or `.none` when unseated.
      var ownTeam: Team { get }
  }

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
      /// nil when nothing in `transcript` is a command.
      static func parse(_ transcript: String, locale: Locale, context: ScoreContext) -> ScoreCommand?
      /// Which team `transcript` refers to, by the spec's precedence. `.none` when nothing names a team.
      static func team(in transcript: String, locale: Locale, context: ScoreContext) -> Team
      /// Largest positive number in `transcript` that a round can be, or nil. Capped at `maxPoints`.
      static func points(in transcript: String, locale: Locale) -> Int?
      static let maxPoints = 999
  }
  ```

**Resolution rules, from the spec, in this precedence:**

1. **Explicit player name** — any word matching a name in `context.team1` or `context.team2` via `PlayerName.isSame`, accent- and case-folded the way `GameCommand` folds names. First match in the transcript wins.
2. **Team name** — `team one`/`team two`, `equipo uno`/`equipo dos`, and the Duo team colors `green`/`blue`, `verde`/`azul` (team 1 is green, team 2 is blue; this is what people at the table actually say about the two cards on screen).
3. **`us` / `we` / `nosotros`** — `context.ownTeam`, falling back to `.team1` when the owner is unseated (the spec's Feature 1 resolution rules pin this fallback).
4. **`them` / `they` / `ellos` / `ellas`** — the other team from `context.ownTeam`, falling back to `.team2` when the owner is unseated.

**Command keyword sets** (all matched on the folded, tokenized transcript; each entry matches as a word sequence, not a substring, so "and" inside a name cannot trigger one):

| Command | English | Spanish |
|---|---|---|
| `cancelGame` | `cancel the game`, `cancel game`, `throw it out` | `cancela el juego`, `cancelar juego`, `anula el juego` |
| `endGame` | `end the game`, `end game`, `game over`, `we're done` | `termina el juego`, `terminar juego`, `se acabo` |
| `undo` | `undo`, `take that back`, `scratch that` | `quita eso`, `quitalo`, `borra eso`, `deshacer` |
| `pointsToGo` | `how many to go`, `how many left`, `how much to win` | `cuanto falta`, `cuanto queda` |
| `whoIsWinning` | `who's winning`, `who is winning`, `what's the score`, `the score` | `quien va ganando`, `quien gana`, `como vamos` |

Checked in exactly that order, so a question is never read as a record and `cancel the game` is never read as `end game`. If none matches, a number makes `.record` (with a team) or `.askTeam` (without one); no number makes `nil`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct ScoreCommandTests {

    private let en = Locale(identifier: "en_US")
    private let es = Locale(identifier: "es_US")

    /// Ana & Luis are team 1, Rafa & Mia are team 2, and Ana owns the phone.
    private let seated = ScoreContext(team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"], owner: "Ana")
    private let unseated = ScoreContext(team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"], owner: nil)

    // MARK: - Recording

    @Test func recordsPointsForTheOwnersTeam() {
        #expect(ScoreCommand.parse("twenty-five us", locale: en, context: seated)
                == .record(points: 25, team: .team1))
        #expect(ScoreCommand.parse("thirty them", locale: en, context: seated)
                == .record(points: 30, team: .team2))
    }

    @Test func recordsSpanishPointsForTheOwnersTeam() {
        #expect(ScoreCommand.parse("veinticinco nosotros", locale: es, context: seated)
                == .record(points: 25, team: .team1))
        #expect(ScoreCommand.parse("treinta ellos", locale: es, context: seated)
                == .record(points: 30, team: .team2))
    }

    @Test func digitsWorkAsWellAsWords() {
        #expect(ScoreCommand.parse("25 us", locale: en, context: seated)
                == .record(points: 25, team: .team1))
    }

    /// Word order is the speaker's, not ours.
    @Test func teamMayComeFirst() {
        #expect(ScoreCommand.parse("give Rafa fifteen", locale: en, context: seated)
                == .record(points: 15, team: .team2))
    }

    // MARK: - Team precedence

    @Test func aNamedPlayerOutranksUsAndThem() {
        // "us" would mean team 1; Rafa is named, so team 2 wins.
        #expect(ScoreCommand.parse("twenty for Rafa, not us", locale: en, context: seated)
                == .record(points: 20, team: .team2))
    }

    @Test func aTeamNameOutranksUsAndThem() {
        #expect(ScoreCommand.parse("twenty team two, not us", locale: en, context: seated)
                == .record(points: 20, team: .team2))
        #expect(ScoreCommand.parse("veinte equipo dos", locale: es, context: seated)
                == .record(points: 20, team: .team2))
    }

    @Test func teamColorsNameTheTeams() {
        #expect(ScoreCommand.team(in: "forty on green", locale: en, context: seated) == .team1)
        #expect(ScoreCommand.team(in: "forty on blue", locale: en, context: seated) == .team2)
        #expect(ScoreCommand.team(in: "cuarenta al azul", locale: es, context: seated) == .team2)
    }

    @Test func namesMatchCaseAndAccentInsensitively() {
        let context = ScoreContext(team1: ["José", "Luis"], team2: ["Rafa", "Mia"], owner: nil)
        #expect(ScoreCommand.team(in: "thirty jose", locale: en, context: context) == .team1)
    }

    /// The scorekeeper is often not one of the four players.
    @Test func withNoOwnerUsAndThemFallBackToSeatOrder() {
        #expect(ScoreCommand.parse("twenty-five us", locale: en, context: unseated)
                == .record(points: 25, team: .team1))
        #expect(ScoreCommand.parse("twenty-five them", locale: en, context: unseated)
                == .record(points: 25, team: .team2))
    }

    @Test func theOwnerOnTeamTwoMakesUsTeamTwo() {
        let context = ScoreContext(team1: ["Ana", "Luis"], team2: ["Rafa", "Mia"], owner: "Rafa")
        #expect(context.ownTeam == .team2)
        #expect(ScoreCommand.parse("fifteen us", locale: en, context: context)
                == .record(points: 15, team: .team2))
        #expect(ScoreCommand.parse("fifteen them", locale: en, context: context)
                == .record(points: 15, team: .team1))
    }

    // MARK: - Never guessing (Review Focus 1)

    @Test func aBareNumberAsksWhichTeam() {
        #expect(ScoreCommand.parse("twenty-five", locale: en, context: seated) == .askTeam(points: 25))
        #expect(ScoreCommand.parse("veinticinco", locale: es, context: seated) == .askTeam(points: 25))
    }

    @Test func tableTalkWithNoNumberAndNoCommandIsNotACommand() {
        #expect(ScoreCommand.parse("your turn, pass me the water", locale: en, context: seated) == nil)
        #expect(ScoreCommand.parse("", locale: en, context: seated) == nil)
        #expect(ScoreCommand.parse("   ", locale: en, context: seated) == nil)
    }

    /// A number a round cannot be is not a round. The keypad caps at 3 digits too.
    @Test func implausibleValuesAreNotPoints() {
        #expect(ScoreCommand.points(in: "zero us", locale: en) == nil)
        #expect(ScoreCommand.points(in: "1000 us", locale: en) == nil)
        #expect(ScoreCommand.points(in: "999 us", locale: en) == 999)
    }

    // MARK: - Undo

    @Test func undoInBothLanguages() {
        #expect(ScoreCommand.parse("undo", locale: en, context: seated) == .undo)
        #expect(ScoreCommand.parse("take that back", locale: en, context: seated) == .undo)
        #expect(ScoreCommand.parse("quita eso", locale: es, context: seated) == .undo)
    }

    /// Undo outranks a number, so "undo the twenty-five" is not a new round.
    @Test func undoOutranksARecord() {
        #expect(ScoreCommand.parse("undo the twenty-five", locale: en, context: seated) == .undo)
    }

    // MARK: - Questions

    @Test func whoIsWinningInBothLanguages() {
        #expect(ScoreCommand.parse("who's winning?", locale: en, context: seated) == .whoIsWinning)
        #expect(ScoreCommand.parse("what's the score", locale: en, context: seated) == .whoIsWinning)
        #expect(ScoreCommand.parse("¿quién va ganando?", locale: es, context: seated) == .whoIsWinning)
    }

    @Test func pointsToGoInBothLanguages() {
        #expect(ScoreCommand.parse("how many to go?", locale: en, context: seated) == .pointsToGo)
        #expect(ScoreCommand.parse("how much to win", locale: en, context: seated) == .pointsToGo)
        #expect(ScoreCommand.parse("¿cuánto falta?", locale: es, context: seated) == .pointsToGo)
    }

    /// A question that happens to name a team is still a question.
    @Test func aQuestionOutranksARecord() {
        #expect(ScoreCommand.parse("how many to go for Rafa", locale: en, context: seated) == .pointsToGo)
    }

    // MARK: - Ending

    @Test func endAndCancelAreDistinct() {
        #expect(ScoreCommand.parse("end the game", locale: en, context: seated) == .endGame)
        #expect(ScoreCommand.parse("game over", locale: en, context: seated) == .endGame)
        #expect(ScoreCommand.parse("cancel the game", locale: en, context: seated) == .cancelGame)
        #expect(ScoreCommand.parse("termina el juego", locale: es, context: seated) == .endGame)
        #expect(ScoreCommand.parse("cancela el juego", locale: es, context: seated) == .cancelGame)
    }

    /// "cancel the game" contains "game": cancel must be checked first.
    @Test func cancelIsNotHeardAsEnd() {
        #expect(ScoreCommand.parse("cancel this game", locale: en, context: seated) == .cancelGame)
    }

    /// A player called "Blue" or "Uno" must not be shadowed by the team-name words.
    @Test func aPlayerNamedAfterATeamWordStillResolvesToTheirOwnTeam() {
        let context = ScoreContext(team1: ["Ana", "Luis"], team2: ["Blue", "Mia"], owner: "Ana")
        #expect(ScoreCommand.team(in: "thirty blue", locale: en, context: context) == .team2)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:iScoreTests/ScoreCommandTests`
Expected: FAIL — `cannot find 'ScoreContext' in scope`.

- [ ] **Step 3: Implement `ScoreContext` and `ScoreCommand` in `iScore/Model/ScoreCommand.swift`**

Tokenize and fold the same way `GameCommand` does: split on whitespace keeping hyphens and apostrophes inside words, fold `[.diacriticInsensitive, .caseInsensitive]`, and turn other punctuation into a break token so `"veinticinco, nosotros"` still reads as two tokens. Keep that tokenizer private to this file rather than exposing `GameCommand`'s — the two parsers want different stop words and should not drift into one shared blob.

`points(in:)` takes `SpokenNumber.scan`'s hits, drops anything outside `1...maxPoints`, and returns the **largest** remaining value (a transcript like "thirty them, round nine" should score 30, not 9).

`team(in:)` walks the precedence list above and returns on the first hit. Player names are checked before the team-name words so a player actually called "Blue" wins, which is what the last test pins.

Register the file: `ruby scripts/xcodeproj.rb add iScore iScore/Model/ScoreCommand.swift` and `ruby scripts/xcodeproj.rb add iScoreTests iScoreTests/ScoreCommandTests.swift`.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command.
Expected: PASS, all of `ScoreCommandTests`.

- [ ] **Step 5: Commit**

```bash
git add iScore/Model/ScoreCommand.swift iScoreTests/ScoreCommandTests.swift iScore.xcodeproj/project.pbxproj
git commit -m "feat: parse spoken in-game score commands in English and Spanish"
```

---

### Task 2: The spoken answers, as copy on `Game`

"Who's winning?" and "how many to go?" are answered from the game. The copy lives beside the rest of the scoreboard copy, in the file that already owns `headline` and `statusLabel`.

**Files:**
- Create: `iScore/Model/Game+Voice.swift`
- Create: `iScoreTests/GameVoiceTests.swift`

**Interfaces:**
- Consumes: `Game.displayName(for:)`, `Game.leader`, `Game.lead`, `Game.pointsToWin(for:)`, `Game.total(for:)` (`iScore/Model/Game+Scoreboard.swift`); `OwnerIdentity.resolve(_:known:)` (`iScore/Model/GameSetup.swift`).
- Produces:
  ```swift
  extension Game {
      /// "Ana & Luis lead by 30, 105 to 75" / "All tied up at 60" / "Nobody has scored yet"
      var winningAnswer: String { get }
      /// "Ana & Luis need 95, Rafa & Mia need 155"
      var pointsToGoAnswer: String { get }
      /// The two answers together, for `VoiceScoring.outcome`.
      var voiceAnswers: VoiceScoring.Answers { get }
      /// The teams and the owner, for `ScoreCommand.parse`.
      func scoreContext(owner storedOwnerName: String?) -> ScoreContext
  }
  ```
  `VoiceScoring.Answers` is defined in Task 3; implement this task's `voiceAnswers` after it, or define the two-field struct here and let Task 3 consume it — either order compiles, so **define `Answers` in Task 3's file** and have this task's `voiceAnswers` be the last thing written in Task 3's Step 3. Everything else in this task stands alone.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct GameVoiceTests {

    @Test func winningAnswerNamesTheLeaderAndTheLead() {
        let game = makeTestGame(rows: demoGameRows)   // Ana & Luis 105, Rafa & Mia 45
        #expect(game.winningAnswer == "Ana & Luis lead by 60, 105 to 45")
    }

    @Test func aTieSaysSoWithTheScore() {
        let game = makeTestGame(rows: [[0, 0], [30, 0], [0, 30]])
        #expect(game.winningAnswer == "All tied up at 30")
    }

    @Test func anEmptyGameSaysNobodyHasScored() {
        let game = makeTestGame()
        #expect(game.winningAnswer == "Nobody has scored yet")
    }

    @Test func pointsToGoCoversBothTeams() {
        let game = makeTestGame(rows: demoGameRows)   // target 200
        #expect(game.pointsToGoAnswer == "Ana & Luis need 95, Rafa & Mia need 155")
    }

    /// Past the target, a team needs nothing — the answer must not say "need 0".
    @Test func aTeamAtTheTargetHasWon() {
        let game = makeTestGame(maxScore: 100, rows: [[0, 0], [100, 0]])
        #expect(game.pointsToGoAnswer == "Ana & Luis have won, Rafa & Mia need 100")
    }

    /// Unnamed teams fall back to the same labels the screen shows.
    @Test func answersUseTheScreensTeamNames() {
        let game = makeTestGame(rows: [[0, 0], [20, 0]], team1: [], team2: [])
        #expect(game.winningAnswer == "Team 1 lead by 20, 20 to 0")
    }

    @Test func contextCarriesBothTeamsAndTheOwner() {
        let game = makeTestGame()
        let context = game.scoreContext(owner: "ana")
        #expect(context.team1 == ["Ana", "Luis"])
        #expect(context.team2 == ["Rafa", "Mia"])
        // The saved player's own spelling, not what was stored.
        #expect(context.owner == "Ana")
        #expect(context.ownTeam == .team1)
    }

    /// A stored owner who is not at this table is not in this game.
    @Test func anOwnerWhoIsNotPlayingIsDropped() {
        let game = makeTestGame()
        let context = game.scoreContext(owner: "Carlos")
        #expect(context.owner == nil)
        #expect(context.ownTeam == .none)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/GameVoiceTests`
Expected: FAIL — `value of type 'Game' has no member 'winningAnswer'`.

- [ ] **Step 3: Implement the extension in `iScore/Model/Game+Voice.swift`**

Every string through `String(localized:)`. `scoreContext(owner:)` resolves the stored name against `team1 + team2` with `OwnerIdentity.resolve`, so an owner who is not seated at this table comes back `nil` — which is exactly the unseated case Task 1's fallbacks handle.

Register: `ruby scripts/xcodeproj.rb add iScore iScore/Model/Game+Voice.swift` and `add iScoreTests iScoreTests/GameVoiceTests.swift`.

- [ ] **Step 4: Run to verify they pass**

Expected: PASS, all of `GameVoiceTests`.

- [ ] **Step 5: Commit**

```bash
git add iScore/Model/Game+Voice.swift iScoreTests/GameVoiceTests.swift iScore.xcodeproj/project.pbxproj
git commit -m "feat: spoken answers for who's winning and how many to go"
```

---

### Task 3: `VoiceScoring` — what a command does

The only place that decides. It never sees a `Game`: the caller passes what the game currently allows, so every branch is a one-line test.

**Files:**
- Create: `iScore/Model/VoiceScoring.swift`
- Create: `iScoreTests/VoiceScoringTests.swift`
- Modify: `iScore/Model/Game+Voice.swift` (add `voiceAnswers`)

**Interfaces:**
- Consumes: `ScoreCommand` (Task 1); `Game.winningAnswer`, `Game.pointsToGoAnswer` (Task 2).
- Produces:
  ```swift
  enum VoiceScoring {

      struct Answers: Equatable {
          let winning: String
          let pointsToGo: String
      }

      /// What the game allows right now.
      struct Permissions: Equatable {
          /// `game.state == .playing`
          let canScore: Bool
          /// `game.canUndo`
          let canUndo: Bool
      }

      enum Outcome: Equatable {
          case recorded(points: Int, team: Team)
          case undone
          /// A number with no team: the host shows both team buttons, points filled in.
          case askTeam(points: Int)
          case confirmEnd
          case confirmCancel
          /// An answer to show and speak. Nothing changes.
          case said(String)
          /// Nothing happened, and this line says why. Shown and spoken.
          case refused(String)
      }

      /// `assumedTeam` is the team the host already knows (the Add Score sheet's team);
      /// nil on `GameView`, where no team is implied.
      static func outcome(for command: ScoreCommand?,
                          permissions: Permissions,
                          answers: Answers,
                          assumedTeam: Team?) -> Outcome

      static var notUnderstood: String { get }
      static var nothingToUndo: String { get }
      static var gameIsOver: String { get }
  }
  ```

**Mapping:**

| command | `canScore == false` | otherwise |
|---|---|---|
| `nil` | `.refused(notUnderstood)` | `.refused(notUnderstood)` |
| `.record` | `.refused(gameIsOver)` | `.recorded` |
| `.askTeam` | `.refused(gameIsOver)` | `.recorded` with `assumedTeam` when there is one, else `.askTeam` |
| `.undo` | `.refused(gameIsOver)` | `.undone` when `canUndo`, else `.refused(nothingToUndo)` |
| `.whoIsWinning` | `.said(answers.winning)` | `.said(answers.winning)` |
| `.pointsToGo` | `.said(answers.pointsToGo)` | `.said(answers.pointsToGo)` |
| `.endGame` | `.refused(gameIsOver)` | `.confirmEnd` |
| `.cancelGame` | `.refused(gameIsOver)` | `.confirmCancel` |

Questions are answerable on a finished game — looking back at a score is not scoring.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct VoiceScoringTests {

    private let playing = VoiceScoring.Permissions(canScore: true, canUndo: true)
    private let fresh = VoiceScoring.Permissions(canScore: true, canUndo: false)
    private let over = VoiceScoring.Permissions(canScore: false, canUndo: false)
    private let answers = VoiceScoring.Answers(winning: "Ana & Luis lead by 60, 105 to 45",
                                               pointsToGo: "Ana & Luis need 95, Rafa & Mia need 155")

    private func outcome(_ command: ScoreCommand?,
                         _ permissions: VoiceScoring.Permissions,
                         assumedTeam: Team? = nil) -> VoiceScoring.Outcome {
        VoiceScoring.outcome(for: command, permissions: permissions, answers: answers, assumedTeam: assumedTeam)
    }

    @Test func aRecordIsRecorded() {
        #expect(outcome(.record(points: 25, team: .team1), playing) == .recorded(points: 25, team: .team1))
    }

    @Test func undoNeedsARoundToTakeBack() {
        #expect(outcome(.undo, playing) == .undone)
        #expect(outcome(.undo, fresh) == .refused(VoiceScoring.nothingToUndo))
    }

    /// Review Focus 4: an extra undo is a refusal, never a phantom round.
    @Test func undoOnAFinishedGameIsRefused() {
        #expect(outcome(.undo, over) == .refused(VoiceScoring.gameIsOver))
    }

    @Test func nothingIsScoredOnAGameThatIsOver() {
        #expect(outcome(.record(points: 25, team: .team1), over) == .refused(VoiceScoring.gameIsOver))
        #expect(outcome(.askTeam(points: 25), over) == .refused(VoiceScoring.gameIsOver))
        #expect(outcome(.endGame, over) == .refused(VoiceScoring.gameIsOver))
        #expect(outcome(.cancelGame, over) == .refused(VoiceScoring.gameIsOver))
    }

    /// Looking at the score is not scoring.
    @Test func questionsAreAnsweredEvenAfterTheGame() {
        #expect(outcome(.whoIsWinning, over) == .said(answers.winning))
        #expect(outcome(.pointsToGo, over) == .said(answers.pointsToGo))
    }

    /// Review Focus 1: no team, no guess.
    @Test func aBareNumberAsksWhichTeamWhenNoneIsImplied() {
        #expect(outcome(.askTeam(points: 25), playing) == .askTeam(points: 25))
    }

    /// In the Add Score sheet the team is already known, so the number is enough.
    @Test func anAssumedTeamAnswersTheQuestionItself() {
        #expect(outcome(.askTeam(points: 25), playing, assumedTeam: .team2)
                == .recorded(points: 25, team: .team2))
    }

    /// An explicit team in the sentence still wins over the sheet's own team.
    @Test func anExplicitTeamOutranksTheAssumedOne() {
        #expect(outcome(.record(points: 25, team: .team1), playing, assumedTeam: .team2)
                == .recorded(points: 25, team: .team1))
    }

    @Test func endingAndCancellingBothWaitForAConfirmation() {
        #expect(outcome(.endGame, playing) == .confirmEnd)
        #expect(outcome(.cancelGame, playing) == .confirmCancel)
    }

    /// Review Focus 1: an unparsed transcript is refused with a line, not swallowed.
    @Test func nothingUnderstoodIsRefusedWithAReason() {
        #expect(outcome(nil, playing) == .refused(VoiceScoring.notUnderstood))
        #expect(VoiceScoring.notUnderstood.isEmpty == false)
        #expect(VoiceScoring.notUnderstood != VoiceScoring.nothingToUndo)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/VoiceScoringTests`
Expected: FAIL — `cannot find 'VoiceScoring' in scope`.

- [ ] **Step 3: Implement `VoiceScoring` in `iScore/Model/VoiceScoring.swift`, then `Game.voiceAnswers`**

A single `switch` over the mapping table. The three strings go through `String(localized:)`; `notUnderstood` must name the way out ("Didn't catch that. Say a number and a team, or use the keypad.") because it is the line a user sees when the mic misheard them.

Then add to `iScore/Model/Game+Voice.swift`:
```swift
var voiceAnswers: VoiceScoring.Answers {
    VoiceScoring.Answers(winning: winningAnswer, pointsToGo: pointsToGoAnswer)
}
```

Register: `ruby scripts/xcodeproj.rb add iScore iScore/Model/VoiceScoring.swift` and `add iScoreTests iScoreTests/VoiceScoringTests.swift`.

- [ ] **Step 4: Run to verify they pass**

Run the Step 2 command, then `-only-testing:iScoreTests/GameVoiceTests` to confirm Task 2 still passes.
Expected: PASS, both suites.

- [ ] **Step 5: Commit**

```bash
git add iScore/Model/VoiceScoring.swift iScore/Model/Game+Voice.swift iScoreTests/VoiceScoringTests.swift iScore.xcodeproj/project.pbxproj
git commit -m "feat: decide what a spoken score command does"
```

---

### Task 4: Spoken replies, and the Settings toggle that silences them

**Files:**
- Create: `iScore/Model/SpokenReply.swift`
- Create: `iScoreTests/SpokenReplyTests.swift`
- Modify: `iScore/Views/SettingsView.swift`

**Interfaces:**
- Produces:
  ```swift
  /// Whether a spoken answer may be spoken. Pure.
  enum VoiceOutput {
      static let speechKey = "voiceSpeechEnabled"
      /// Defaults to true: a feature whose point is talking starts out talking.
      static func load(from defaults: UserDefaults = .standard) -> Bool
      static func shouldSpeak(isEnabled: Bool) -> Bool
  }

  @MainActor final class SpokenReply {
      init(locale: Locale)
      /// Speaks `text` when `isEnabled`; silently does nothing otherwise.
      func say(_ text: String, isEnabled: Bool)
      func stop()
  }
  ```

**The silent switch.** iOS exposes no API for the Ring/Silent switch, and the usual workarounds (timing a silent clip) are fragile. The supported way to honor it is the audio session category: `AVAudioSession` category **`.ambient`** is silenced by the hardware switch by the system, which is precisely the spec's requirement. `SpokenReply.say` therefore sets `.ambient` with `.mixWithOthers` before speaking, and `AVSpeechSynthesizer.usesApplicationAudioSession` stays at its default `true` so the synthesizer uses that session. No silent-switch detection code exists or should be written.

**Sequencing with the mic.** `SpeechCapture` holds the session at `.record` with `.duckOthers` and deactivates it on teardown. A reply must therefore be spoken **after** `capture.stop()`, never during a session — Task 5's state machine enforces the order, and this task's comment says why.

- [ ] **Step 1: Write the failing tests**

```swift
import AVFoundation
import Foundation
import Testing
@testable import iScore

struct SpokenReplyTests {

    @Test func speechIsOnUntilItIsTurnedOff() {
        let defaults = UserDefaults(suiteName: "SpokenReplyTests.\(UUID().uuidString)")!
        #expect(VoiceOutput.load(from: defaults) == true)
        defaults.set(false, forKey: VoiceOutput.speechKey)
        #expect(VoiceOutput.load(from: defaults) == false)
        defaults.set(true, forKey: VoiceOutput.speechKey)
        #expect(VoiceOutput.load(from: defaults) == true)
    }

    @Test func theSettingDecidesWhetherToSpeak() {
        #expect(VoiceOutput.shouldSpeak(isEnabled: true) == true)
        #expect(VoiceOutput.shouldSpeak(isEnabled: false) == false)
    }

    /// Review Focus 6: a reply with speech off must not throw, hang, or crash —
    /// the answer still reaches the screen through the caller.
    @Test @MainActor func sayingSomethingWithSpeechOffIsHarmless() {
        let reply = SpokenReply(locale: Locale(identifier: "en_US"))
        reply.say("Ana & Luis lead by 60", isEnabled: false)
        reply.stop()
    }

    /// The voice language is a parameter, so Feature 4 changes call sites, not this class.
    @Test @MainActor func aVoiceIsChosenForTheLocale() {
        #expect(SpokenReply.voice(for: Locale(identifier: "es_US"))?.language.hasPrefix("es") == true)
        #expect(SpokenReply.voice(for: Locale(identifier: "en_US"))?.language.hasPrefix("en") == true)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/SpokenReplyTests`
Expected: FAIL — `cannot find 'VoiceOutput' in scope`.

- [ ] **Step 3: Implement `VoiceOutput` and `SpokenReply` in `iScore/Model/SpokenReply.swift`**

`SpokenReply` holds one `AVSpeechSynthesizer`, built lazily. `say` returns immediately when `!VoiceOutput.shouldSpeak(isEnabled:)`, otherwise stops anything in flight (so two quick answers do not queue up behind each other at a table), sets the `.ambient` session, and speaks an `AVSpeechUtterance` with `voice(for:)`.

Add `static func voice(for locale: Locale) -> AVSpeechSynthesisVoice?` — `AVSpeechSynthesisVoice(language:)` on the locale's BCP-47 identifier, falling back to the bare language code. It is `static` and pure enough to assert on, which is what the last test does.

Register: `ruby scripts/xcodeproj.rb add iScore iScore/Model/SpokenReply.swift` and `add iScoreTests iScoreTests/SpokenReplyTests.swift`.

- [ ] **Step 4: Add the Settings toggle**

In `iScore/Views/SettingsView.swift`, add a **Voice** section between "New game defaults" and "Players", in the existing card idiom (`Text("Voice").duoLabel()` then a `.duoCard()` holding one row):

```swift
@AppStorage(VoiceOutput.speechKey) private var speaksAnswers = true
```

One row: `Image(systemName: "speaker.wave.2.fill")` tinted `Theme.learn`, title `"Speak answers"`, a `Toggle` bound to `speaksAnswers` with `.labelsHidden()` and `.tint(Theme.teamA)`, and beneath it one `Theme.textSecondary` line in `DuoFont.body`: *"Answers are always shown on screen. Silent mode also silences them."* That line is the feature's honesty about Review Focus 6 and about the `.ambient` behavior, and it belongs on screen rather than only in this plan.

- [ ] **Step 5: Run to verify they pass**

Run the Step 2 command and `-only-testing:iScoreTests/ThemeTests` (the Settings edit must not introduce a color literal).
Expected: PASS, both.

- [ ] **Step 6: Commit**

```bash
git add iScore/Model/SpokenReply.swift iScoreTests/SpokenReplyTests.swift iScore/Views/SettingsView.swift iScore.xcodeproj/project.pbxproj
git commit -m "feat: speak answers in the voice language, with a Settings toggle"
```

---

### Task 5: `VoiceScoreBar` — the one mic button both screens use

A single view owning the mic, the listening state and the live transcript. Its host passes the game's context and receives an `Outcome`. This is the only new view in the feature.

**Files:**
- Create: `iScore/Views/VoiceScoreBar.swift`
- Create: `iScoreTests/VoiceScoreBarTests.swift`

**Interfaces:**
- Consumes: `SpeechCapture`, `SpeechAvailability`, `VoiceSetup.opening(for:)`, `VoiceSetup.explanation(availability:error:)`, `VoiceSetup.notice(heard:availability:lastError:)` (Feature 1); `ScoreCommand.parse`, `ScoreContext` (Task 1); `VoiceScoring` (Task 3); `SpokenReply`, `VoiceOutput` (Task 4).
- Produces:
  ```swift
  struct VoiceScoreBar: View {
      init(context: ScoreContext,
           permissions: VoiceScoring.Permissions,
           answers: VoiceScoring.Answers,
           assumedTeam: Team? = nil,
           locale: Locale = .current,
           onOutcome: @escaping (VoiceScoring.Outcome) -> Void)
  }

  /// The bar's own decisions, kept out of the view.
  enum VoiceBarState {
      enum Prompt: Equatable { case tapToTalk, listening, thinking, blocked(String) }
      static func prompt(isListening: Bool, isThinking: Bool, availability: SpeechAvailability, notice: String?) -> Prompt
      /// Whether the mic can be tapped at all.
      static func isMicEnabled(availability: SpeechAvailability, isThinking: Bool) -> Bool
  }
  ```

**Behavior.** One tap starts `SpeechCapture`; the button becomes a stop button and the live transcript shows beneath it. A second tap, or the recognizer ending by itself, moves to `.thinking`, waits 400ms for the recognizer's last word (the same wait `VoiceGameSheet.finishListening` uses and for the same reason), stops the capture, then parses and calls `onOutcome`. The reply is spoken only after `capture.stop()` has returned, per Task 4.

**Review Focus 5 — never a dead end.** When `availability` is `.denied` or `.unsupported` the mic button stays visible and disabled, and the bar shows `VoiceSetup.explanation(...)` in one line. The host's keypad buttons are untouched, so the touch door is always open. On `.needsPermission` the first tap asks for access and then listens, exactly as `VoiceGameSheet.open()` does.

**Duo styling.** The mic is a circular `DuoCardStyle(edge: 6, radius: 32, border: palette.edge, fill: palette.fill)` button, 64×64, `Image(systemName:)` at `.system(size: 26, weight: .heavy)` in `Theme.surface` — the same vocabulary as `VoiceGameSheet`'s 128pt mic, scaled for a bottom bar. Idle uses `Theme.palette(for: .team1)`; listening uses `learn`/`learnShadow` (via `.duo(fill: Theme.learn, edge: Theme.learnShadow, foreground: Theme.surface)`'s palette form) so "the mic is live" is a distinct color from either team and cannot be mistaken for a team button. `.sensoryFeedback(.impact, trigger: capture.isListening)`. Accessibility label switches between "Start listening" and "Stop listening", with the hint "Say a score, undo, or ask who's winning".

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct VoiceScoreBarTests {

    @Test func thePromptFollowsTheState() {
        #expect(VoiceBarState.prompt(isListening: false, isThinking: false, availability: .ready, notice: nil) == .tapToTalk)
        #expect(VoiceBarState.prompt(isListening: true, isThinking: false, availability: .ready, notice: nil) == .listening)
        #expect(VoiceBarState.prompt(isListening: false, isThinking: true, availability: .ready, notice: nil) == .thinking)
    }

    /// Review Focus 5: a blocked mic says why, and says it in the prompt, not nowhere.
    @Test func aBlockedMicExplainsItself() {
        let denied = VoiceBarState.prompt(isListening: false, isThinking: false, availability: .denied, notice: nil)
        #expect(denied == .blocked(VoiceSetup.explanation(availability: .denied, error: nil)!))
        let unsupported = VoiceBarState.prompt(isListening: false, isThinking: false, availability: .unsupported, notice: nil)
        #expect(unsupported != denied)
    }

    /// A notice from the last session (nothing heard, recognizer died) outranks "Tap to talk".
    @Test func aNoticeIsShownOverTheIdlePrompt() {
        #expect(VoiceBarState.prompt(isListening: false, isThinking: false, availability: .ready, notice: "Didn't catch that.")
                == .blocked("Didn't catch that."))
    }

    /// Listening wins over a stale notice, so the bar never nags mid-session.
    @Test func listeningClearsTheNotice() {
        #expect(VoiceBarState.prompt(isListening: true, isThinking: false, availability: .ready, notice: "Didn't catch that.")
                == .listening)
    }

    @Test func theMicIsTappableUnlessItCannotWork() {
        #expect(VoiceBarState.isMicEnabled(availability: .ready, isThinking: false) == true)
        #expect(VoiceBarState.isMicEnabled(availability: .needsPermission, isThinking: false) == true)
        #expect(VoiceBarState.isMicEnabled(availability: .denied, isThinking: false) == false)
        #expect(VoiceBarState.isMicEnabled(availability: .unsupported, isThinking: false) == false)
        // Mid-parse, a second tap would race the first.
        #expect(VoiceBarState.isMicEnabled(availability: .ready, isThinking: true) == false)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/VoiceScoreBarTests`
Expected: FAIL — `cannot find 'VoiceBarState' in scope`.

- [ ] **Step 3: Implement `VoiceBarState` and `VoiceScoreBar` in `iScore/Views/VoiceScoreBar.swift`**

`VoiceBarState` is a small pure enum + two static functions, in the same file as the view it serves (it is the view's own state machine and has no other client).

The view mirrors `VoiceGameSheet`'s lifecycle: a private `CaptureHolder` final class with `lazy var capture = SpeechCapture(locale:)` so the recognizer and audio engine are built once rather than on every parent body pass, `.onChange(of: capture.isListening)` to catch a session the recognizer ended itself, and `.onDisappear { capture.stop() }` so the mic can never outlive the screen.

Add a `#Preview` showing all four prompt states, as the other Duo components do.

Register: `ruby scripts/xcodeproj.rb add iScore iScore/Views/VoiceScoreBar.swift` and `add iScoreTests iScoreTests/VoiceScoreBarTests.swift`.

- [ ] **Step 4: Run to verify they pass**

Run the Step 2 command plus `-only-testing:iScoreTests/ThemeTests` and `-only-testing:iScoreTests/DuoViewTests`.
Expected: PASS, all three.

- [ ] **Step 5: Commit**

```bash
git add iScore/Views/VoiceScoreBar.swift iScoreTests/VoiceScoreBarTests.swift iScore.xcodeproj/project.pbxproj
git commit -m "feat: push-to-talk mic bar for in-game scoring"
```

---

### Task 6: `GameView` — the mic beside the two team buttons, and End/Cancel

Wires the bar into the Game screen and adds the touch door for ending and cancelling, which the app does not have today. Confirmed with the owner on 2026-10-18: both commands get a visible control, and the voice path raises the same alert a touch user sees.

**Files:**
- Modify: `iScore/Views/GameView.swift` (adds to Feature 2's Live Activity wiring; removes none of it)
- Modify: `iScore/Views/RoundFeedbackBanner.swift` (an Undo button)
- Create: `iScoreTests/GameEndingTests.swift`
- Modify: `iScore/Model/Game+Voice.swift` (add `endByUser()` / `cancelByUser()`)

**Interfaces:**
- Consumes: `VoiceScoreBar` (Task 5); `Game.scoreContext(owner:)`, `Game.voiceAnswers` (Tasks 2–3); `RoundFeedbackBanner`; `Game.addRound(_:for:)`, `Game.undoLastRound()`.
- Produces:
  ```swift
  extension Game {
      /// Ends a playing game as finished. No-op otherwise.
      func endByUser()
      /// Cancels a playing game. No-op otherwise.
      func cancelByUser()
  }
  ```

**Layout.** The bottom bar's `HStack` becomes mic + two team buttons: `VoiceScoreBar` at its natural 64pt width, then the existing two `addButton(for:)`s. The team buttons keep their `.duo` style and full behavior — the keypad does not shrink to make room for voice (spec anti-goal: "a second-class keypad"), it only loses horizontal room, which the existing `Label` already handles by truncating the team name. When the banner is showing, the whole row is replaced by the banner as it is today, and the mic comes back with it.

**The banner is the undo affordance.** The spec says so explicitly, and today it is not — `RoundFeedbackBanner` is purely informational and undo lives only in the toolbar. Add an optional trailing `Button("Undo", systemImage: "arrow.uturn.backward")` to `RoundFeedbackBanner`, taking `onUndo: (() -> Void)?` defaulting to `nil` so the preview and any other caller are unaffected: `.duoLabel(palette.edge)` on a `Theme.surface` capsule, 44pt minimum height, accessibility label "Undo this round". `GameView` passes `{ game.undoLastRound() }` and clears the banner. This gives the just-scored round — spoken or typed — a one-tap take-back where the user is already looking, which is the whole point of the line in the spec.

**Toolbar.** A third toolbar button after Undo and Info: `Menu` with `Image(systemName: "ellipsis.circle")`, holding `Button("End game", systemImage: "flag.checkered")` and `Button("Cancel game", systemImage: "xmark.circle", role: .destructive)`, disabled when `!isPlaying`. Each sets a `@State` flag that raises an `.alert` in the same idiom as the existing "Undo Last Score" alert: End → "End this game? The score stands as it is." → confirm runs `endByUser()` and opens the summary; Cancel → "Cancel this game? It won't count." → confirm runs `cancelByUser()` and pops the path.

**Outcome handling** (`onOutcome:`), each case:
- `.recorded(points, team)` — `game.addRound(points, for: team)`, then the **same** post-round path the sheet uses: `finishIfWon()` first, and only if it returns false show `RoundFeedbackBanner` and post the `AccessibilityNotification.Announcement`. That is Review Focus 2, and it is why the existing `addScoreDismissed()` body is extracted into `applyNewRound()` and called from both places rather than duplicated.
- `.undone` — `game.undoLastRound()`; clear any banner.
- `.askTeam(points)` — set `@State private var pendingPoints: Int?` and show a one-line row above the bar: "25 — which team?" with the two team buttons; tapping one records it through `applyNewRound()`. Visible touch door for an ambiguous sentence.
- `.confirmEnd` / `.confirmCancel` — raise the same alert the toolbar menu raises. The confirmation is a tap, as the spec requires.
- `.said(text)` / `.refused(text)` — show `text` in the bar's notice line and speak it through `SpokenReply`. **Both** paths show it on screen, which is Review Focus 6.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct GameEndingTests {

    @Test func endingAPlayingGameFinishesIt() {
        let game = makeTestGame(rows: demoGameRows)
        game.endByUser()
        #expect(game.state == .finished)
        #expect(game.inProcess == false)
        // The score stands exactly as it was.
        #expect(game.scoreTeam == demoGameRows)
    }

    @Test func cancellingAPlayingGameCancelsIt() {
        let game = makeTestGame(rows: demoGameRows)
        game.cancelByUser()
        #expect(game.state == .cancelled)
        #expect(game.inProcess == false)
        #expect(game.scoreTeam == demoGameRows)
    }

    /// A second "end the game" must not reopen or re-decide a settled game.
    @Test func endingAndCancellingAreNoOpsOnASettledGame() {
        let finished = makeTestGame(rows: demoGameRows, state: .finished)
        finished.cancelByUser()
        #expect(finished.state == .finished)

        let cancelled = makeTestGame(rows: demoGameRows, state: .cancelled)
        cancelled.endByUser()
        #expect(cancelled.state == .cancelled)
    }

    /// Review Focus 2: a spoken round that reaches the target is a win, not a banner.
    /// `GameView` reads `winningTeam`; this pins the value the voice path relies on.
    @Test func aSpokenRoundThatReachesTheTargetWinsTheGame() {
        let game = makeTestGame(maxScore: 100, rows: [[0, 0], [75, 0]])
        #expect(game.winningTeam == .none)
        game.addRound(25, for: .team1)
        #expect(game.winningTeam == .team1)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/GameEndingTests`
Expected: FAIL — `value of type 'Game' has no member 'endByUser'`.

- [ ] **Step 3: Implement `endByUser()` / `cancelByUser()` in `iScore/Model/Game+Voice.swift`**

Each guards `state == .playing`, sets `state` and `inProcess = false`.

Register the test file: `ruby scripts/xcodeproj.rb add iScoreTests iScoreTests/GameEndingTests.swift`.

- [ ] **Step 4: Run to verify they pass**

Run the Step 2 command.
Expected: PASS, all of `GameEndingTests`.

- [ ] **Step 5: Wire `GameView`**

Make the edits described under **Layout**, **Toolbar** and **Outcome handling** above. Extract the existing `addScoreDismissed()` body into `applyNewRound()` and call it from the sheet's `onDismiss` and from `.recorded` and `.askTeam`, so the voice path and the touch path cannot drift. `SpokenReply` is held in a `@State` holder alongside the bar's, built once with `Locale.current`.

- [ ] **Step 6: Build, then run the whole suite**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: PASS, every suite including `ThemeTests` and `SmokeTests`.

- [ ] **Step 7: Commit**

```bash
git add iScore/Views/GameView.swift iScore/Views/RoundFeedbackBanner.swift iScore/Model/Game+Voice.swift iScoreTests/GameEndingTests.swift iScore.xcodeproj/project.pbxproj
git commit -m "feat: mic, End game and Cancel game on the Game screen"
```

---

### Task 7: `AddGameScoreView` — the mic inside the keypad sheet

In the sheet the team is already known, so `assumedTeam` is set and a bare number is enough.

**Files:**
- Modify: `iScore/Views/AddGameScoreView.swift`
- Modify: `iScoreTests/ScoreEntryTests.swift`
- Modify: `iScore/Model/ScoreEntry.swift`

**Interfaces:**
- Consumes: `VoiceScoreBar` (Task 5) with `assumedTeam: team`; `ScoreEntry`.
- Produces: `mutating func set(_ points: Int)` on `ScoreEntry` — replaces the digits outright, ignoring anything non-positive or past `maxDigits`.

**Review Focus 3.** A spoken value must **replace** what is typed, never append to it. `ScoreEntry.append` is digit-at-a-time by design, so a spoken 25 going through `append` twice on top of a typed "3" would make 325. Hence the new `set`.

**Behavior.** The bar sits between the score well and the keypad, at the same 64pt size. `onOutcome:`
- `.recorded(points, team)` — `entry.set(points)`, then add and dismiss exactly as the Add button does (`addScore()` is reused verbatim, so the projection, the round and the dismissal are identical to a tap).
- `.undone` — the round being entered does not exist yet, so undo is meaningless here. Show the notice "Close this first, then undo the last round" and change nothing. The special case stays in the sheet rather than in `VoiceScoring`, because the sheet is the only context where undo has no meaning.
- `.askTeam` — cannot occur here (`assumedTeam` is always set), so it falls through the same way as `.refused`.
- `.said` / `.refused` — notice line plus `SpokenReply`.
- `.confirmEnd` / `.confirmCancel` — dismiss the sheet and show the notice "Close this first, then end the game." Ending a game from inside a score-entry sheet is two decisions in one tap and is not worth it.

- [ ] **Step 1: Write the failing tests**

Append to `iScoreTests/ScoreEntryTests.swift`:

```swift
    /// Review Focus 3: a spoken value replaces what was typed. 3 + "twenty-five" is 25, never 325.
    @Test func settingAValueReplacesTheTypedDigits() {
        var entry = ScoreEntry()
        entry.append(3)
        entry.set(25)
        #expect(entry.digits == "25")
        #expect(entry.value == 25)
    }

    @Test func settingIgnoresValuesTheKeypadCouldNotHold() {
        var entry = ScoreEntry()
        entry.append(3)
        entry.set(0)
        #expect(entry.digits == "3")
        entry.set(-5)
        #expect(entry.digits == "3")
        entry.set(1000)
        #expect(entry.digits == "3")
        entry.set(999)
        #expect(entry.digits == "999")
    }
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/ScoreEntryTests`
Expected: FAIL — `value of type 'ScoreEntry' has no member 'set'`.

- [ ] **Step 3: Implement `ScoreEntry.set(_:)`**

Guard `points > 0` and `String(points).count <= Self.maxDigits`, then assign `digits`.

- [ ] **Step 4: Run to verify they pass**

Expected: PASS, all of `ScoreEntryTests`.

- [ ] **Step 5: Wire `AddGameScoreView`**

Add the bar and the `onOutcome` mapping above. The sheet's own `@State private var notice: String?` renders in the same `Theme.textSecondary` `DuoFont.body` line the projection summary uses, directly under the bar.

- [ ] **Step 6: Run the whole suite**

Run: the full `xcodebuild test` command with no `-only-testing`.
Expected: PASS, every suite.

- [ ] **Step 7: Commit**

```bash
git add iScore/Views/AddGameScoreView.swift iScore/Model/ScoreEntry.swift iScoreTests/ScoreEntryTests.swift
git commit -m "feat: speak a score into the Add Score keypad"
```

---

### Task 8: Verify on the simulator, then open the PR

The spec's "done looks like" is a scorekeeper playing a full game with one mic tap per round. The simulator's speech recognizer frequently refuses to start (no microphone), which is exactly the `.unsupported` / error path Review Focus 5 covers — so verification is in two halves and the second half needs the owner's device.

**Files:**
- Modify: `CLAUDE.md` (a "Voice scoring" section, in the idiom of the existing "Lock Screen scoreboard" one)

- [ ] **Step 1: Run the full suite one more time**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: PASS. Record the new test count in the PR body.

- [ ] **Step 2: Verify the blocked-mic path on the simulator**

Launch the app with `-demoData`, open the in-progress game, and confirm by screenshot:
- the mic sits beside the two team buttons and the team buttons still work end to end (keypad → round → banner);
- tapping the mic either listens or shows a one-line explanation, and the screen is never stuck in `.thinking`;
- the banner that follows a typed round carries a working Undo;
- the Lock Screen activity still starts, still scores, and its totals still match in-app after a round added through the mic path's `applyNewRound()` — Feature 2 is in this branch and must not have regressed;
- the ⋯ menu's End game and Cancel game each raise their alert, and confirming each lands the right `state`;
- Settings shows the Voice section and its toggle.

- [ ] **Step 3: Write the `CLAUDE.md` section**

A "Voice scoring" section covering: push-to-talk only and why (no always-listening, no wake phrase); the three pure layers and which file each lives in; the team-reference precedence; that `.ambient` is how silent mode is honored and that no silent-switch detection exists; and that `VoiceScoreBar` is the single mic — a third screen that wants voice embeds it rather than growing its own.

- [ ] **Step 4: Commit and push**

```bash
git add CLAUDE.md
git commit -m "docs: record how voice scoring is put together"
git push -u origin voice-and-keypad
```

- [ ] **Step 5: Open the PR**

`gh pr create --base worktree-say-the-game`, titled "Voice and keypad as equal doors (Feature 3)". The body states: the branch stacks on PR #4 and must merge after it; PR #5 is not included and `GameView.swift` plus `project.pbxproj` will conflict with whichever of #4/#5 lands second; and that **on-device verification of real recognition and real spoken answers is the owner's, because the simulator has no microphone** — naming the two things only a device can show: that a spoken round lands in under a beat, and that an answer is audible with the ringer on and silent with the switch flipped.

- [ ] **Step 6: Hand back**

Report the PR link, the test count, and the two device checks left to the owner.

---

## Notes for the executor

- `GameCommand` (Feature 1) and `ScoreCommand` (this feature) are deliberately separate parsers with separate stop-word sets. Do not merge them — a sentence that sets up a game and a sentence that scores a round want different things from the same words ("nine" is a game type in one and a round value in the other).
- `VoiceScoring` must never import SwiftData or take a `Game`. If a decision needs something from the game, add a field to `Permissions` or `Answers` rather than passing the model in.
- Every string the user can see or hear goes through `String(localized:)`. Feature 4 extracts them; a bare literal here becomes its bug.
