# Round-level Drama Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app calls out what players would call out themselves — capicúa, a big round, a comeback, a shutout (zapato), a last-round win, a win streak — with the existing round banner, a trophy burst and, when voice answers are on, a spoken line.

**Architecture:** A pure `GameDrama` (`iScore/Model/GameDrama.swift`) returns zero or one `Highlight` for a new round, and zero or one for a finished game, ranked and never repeating within a game. Copy lives in `Game+Drama.swift` as `LocalizedStringResource`. Views only pass data in and show what comes out: `RoundFeedbackBanner` shows a round highlight, `GameSummaryView` shows the game's, and `VoiceScoreBar` — the only synthesizer — speaks either.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, String Catalog.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md` §9 "Round-level drama".

## Global Constraints

- iOS 26, Swift 5 language mode, SwiftUI + SwiftData with CloudKit. **No new persisted property** — capicúa is a flag on the round being entered, not stored.
- Duo theme is law: colors from `Theme` only, `DuoFont`, no gradients/shadows/blur/glass. Reuse `RoundFeedbackBanner` and `TrophyBurst`; **no new visual language**.
- Anti-goal: **highlights never block score entry.** The banner keeps its 2-second life and its Undo; nothing modal, nothing waits.
- Every user-visible or spoken line is a `LocalizedStringResource` / `String(localized:)` with Spanish in `iScore/Localizable.xcstrings`; `ruby scripts/lint-strings.rb` must pass. Spanish uses the real terms: *capicúa*, *zapato*, *remontada*.
- `VoiceScoreBar` is the only synthesizer (CLAUDE.md, Voice scoring); a host never adds a second one.
- New Swift files are registered with `ruby scripts/xcodeproj.rb add iScore <path>` (tests: `add iScoreTests <path>`).
- Tests: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`.

## Decisions the spec left open (my calls)

- **Comeback**: a team that trailed by at least `GameDrama.comebackDeficit(target:)` = 25% of the target, rounded up to a multiple of 5 (Double-6 at 100 → 25; Double-9 at 200 → 50), and now leads (mid-game) or has won (finished game).
- **Biggest round of the night**: strictly more points than every earlier round on the same calendar day across all games (this one included), and only once at least 5 earlier rounds were played that day — so round one is never "the biggest".
- **Decided by one round** = "last-round win": the winner trailed before the final round.
- **Win streak**: a player on the winning team whose finished games, newest first, are all wins for 3 or more in a row (this game included). Ties of streak length go to the longer streak, then seat order.
- **Ranking**: round — capicúa > comeback > biggest round. Finished game — shutout > comeback win > last-round win > streak.
- **The winning round** shows no round banner (the summary opens), so a capicúa or big winning round is folded into the summary only if no finale highlight beats it: summary uses `finale ?? roundHighlight`.
- **Capicúa by voice with no team on the Game screen** (`askTeam`) is dropped — the team buttons record a plain round. Accepted cost: the user says it again or uses the sheet's toggle.
- **Settings**: "Call out big moments" toggle, default on, key `roundDramaEnabled`. Off means no highlight anywhere, including the summary line.

## Review Focus

1. Undo right after a highlighted round, then the same kind again — it must not repeat within the game (the shown set is not reset by undo).
2. Edited or deleted rounds (Edit Score) never produce a highlight — only `applyNewRound` asks.
3. A game in another language: the spoken line must be in the **voice** language, the banner in the app language.
4. Demo data / iCloud games from earlier days must not count toward "biggest round tonight".
5. A shutout where the loser scored and then had it undone — totals decide, not history.

Each has a test in the owning task (marked RF1–RF5).

---

### Task 1: `GameDrama` round highlights

**Files:**
- Create: `iScore/Model/GameDrama.swift`
- Test: `iScoreTests/GameDramaTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum GameDrama {
      enum Highlight: Equatable {
          case capicua(Team)
          case biggestRound(Team, points: Int)
          case comeback(Team, deficit: Int)
          case shutout(winner: Team)
          case comebackWin(Team, deficit: Int)
          case lastRoundWin(Team)
          case streak(name: String, wins: Int)
          var kind: Kind { get }
      }
      enum Kind: Hashable { case capicua, biggestRound, comeback, shutout, comebackWin, lastRoundWin, streak }
      static func comebackDeficit(target: Int) -> Int
      /// The largest lead `team`'s opponents held at any point, from the round totals.
      static func largestDeficit(of team: Team, in game: Game) -> Int
      static func roundHighlight(after round: Round, in game: Game, capicua: Bool,
                                 earlierRoundsTonight: [Int], alreadyShown: Set<Kind>) -> Highlight?
      static func roundsTonight(in games: [Game], before round: Round, of game: Game, now: Date, calendar: Calendar) -> [Int]
  }
  ```
  `earlierRoundsTonight` is the points of every round played today before `round` (other games' rounds plus this game's earlier ones).

- [ ] **Step 1: Write the failing tests** (`struct GameDramaTests`), building games with `Game(gameType:maxScore:)` and `addRound`:
  - `nothingHappenedIsNothing`: 25 then 30 on a 200 game, no capicúa, `earlierRoundsTonight: [10, 20, 25, 30, 35]` → `nil`.
  - `capicuaOutranksEverything`: capicúa on a round that is also a comeback and the night's biggest → `.capicua(team)`.
  - `comebackWhenATeamTrailingByAQuarterTakesTheLead`: 200 game, team2 +60, team1 +70 → `.comeback(.team1, deficit: 60)`; with team2 +45 first (below 50) → `nil`.
  - `comebackDeficitIsAQuarterRoundedToFive`: `comebackDeficit(target: 100) == 25`, `(200) == 50`, `(150) == 40`, `(10) == 5`.
  - `biggestRoundNeedsFiveEarlierRoundsAndMustBeatThemAll`: 4 earlier `[10,20,30,40]` + round 90 → `nil`; 5 earlier `[10,20,30,40,50]` + 90 → `.biggestRound(team, points: 90)`; 5 earlier with a 90 + round 90 → `nil` (ties are not records).
  - `aKindShownOnceIsNotShownAgain` (RF1): comeback with `alreadyShown: [.comeback]` → `nil`.
  - `onlyTodaysRoundsCount` (RF4): `roundsTonight` over a game timestamped yesterday and one today returns only today's points, and only this game's rounds before `round`.
- [ ] **Step 2: Run** `xcodebuild test … -only-testing:iScoreTests/GameDramaTests` — Expected: build fails, `GameDrama` undefined.
- [ ] **Step 3: Implement** in `GameDrama.swift`. `largestDeficit` walks `game.rounds` accumulating totals. Finale cases exist in the enum but are produced by Task 2.
- [ ] **Step 4: Run** the same command — Expected: all `GameDramaTests` pass.
- [ ] **Step 5: Commit** `feat: GameDrama finds the moment in a new round`.

### Task 2: `GameDrama` finished-game highlights

**Files:**
- Modify: `iScore/Model/GameDrama.swift`
- Test: `iScoreTests/GameDramaTests.swift`

**Interfaces:**
- Consumes: Task 1's `Highlight`, `comebackDeficit`, `largestDeficit`.
- Produces: `static func finale(of game: Game, history: [Game]) -> Highlight?` — `nil` unless `game.state == .finished` and `game.winningTeam != .none`. `history` is every game (any order); streaks are read from finished games sorted by `timestamp`.

- [ ] **Step 1: Write the failing tests:**
  - `aShutoutIsAZapato`: team1 reaches 100 with team2 at 0 → `.shutout(winner: .team1)`.
  - `totalsDecideTheShutoutNotHistory` (RF5): team2 +10, undo, team1 to 100 → `.shutout(winner: .team1)`.
  - `comebackWinOutranksALastRoundWin`: Double-9 at 150 (deficit 40): team2 +60, team1 +70, team2 +20, team1 +80 → `.comebackWin(.team1, deficit: 60)` (team1 also trailed before the last round).
  - `lastRoundWin`: Double-6 at 100: team1 +40, team2 +30, team2 +75 → `.lastRoundWin(.team2)` (deficit 10 is below 25).
  - `threeWinsInARowIsAStreak`: three finished games where "Ana" (any case, `PlayerName.isSame`) is on the winning team, plus a plain win now → `.streak(name: "Ana", wins: 4)` when nothing outranks it; a loss in between resets to the wins since.
  - `noFinaleWhilePlaying`: a game still playing → `nil`.
- [ ] **Step 2: Run** — Expected: fails, `finale` undefined.
- [ ] **Step 3: Implement** `finale(of:history:)` with the ranking from Decisions.
- [ ] **Step 4: Run** — Expected: pass.
- [ ] **Step 5: Commit** `feat: GameDrama names how a game was won`.

### Task 3: Copy, spoken line and the Settings switch

**Files:**
- Create: `iScore/Model/Game+Drama.swift`, `iScore/Model/DramaSettings.swift`
- Modify: `iScore/Views/SettingsView.swift`, `iScore/Localizable.xcstrings`
- Test: `iScoreTests/GameDramaTests.swift`

**Interfaces:**
- Consumes: `GameDrama.Highlight`.
- Produces:
  ```swift
  extension Game {
      func dramaTitle(_ h: GameDrama.Highlight) -> LocalizedStringResource
      func dramaDetail(_ h: GameDrama.Highlight) -> LocalizedStringResource
      /// "Title. Detail" resolved in `locale` — the voice language.
      func dramaLine(_ h: GameDrama.Highlight, in locale: Locale) -> String
  }
  enum DramaSettings { static let enabledKey = "roundDramaEnabled"; static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool }
  ```
- Copy (English → Spanish), names via `displayName(for:)`:

  | Highlight | Title | Detail |
  |---|---|---|
  | capicua | Capicúa! → ¡Capicúa! | %@ closed it at both ends → %@ cerró por las dos puntas |
  | biggestRound | Biggest round tonight! → ¡La ronda más grande de la noche! | %@ +%lld → %@ +%lld |
  | comeback | Comeback! → ¡Remontada! | %@: down %lld, now in front → %@: iban %lld abajo, ahora ganan |
  | shutout | Zapato! → ¡Zapato! | %@ didn't score → %@ no anotó |
  | comebackWin | Comeback win! → ¡Ganaron remontando! | Won from %lld down → Ganaron desde %lld abajo |
  | lastRoundWin | Won it in the last round! → ¡La ganaron en la última ronda! | %@ were behind until the end → %@ iban perdiendo hasta el final |
  | streak | On a streak! → ¡En racha! | %@: %lld wins in a row → %@: %lld victorias seguidas |

  Settings row in the Voice card's neighbor position (its own card, label "Big moments"): toggle "Call out big moments" → "Anunciar las grandes jugadas", footnote "Capicúa, zapato, comebacks and streaks get a banner and, with spoken answers on, a line." → "Capicúa, zapato, remontadas y rachas reciben un aviso y, con las respuestas habladas, una frase."

- [ ] **Step 1: Write the failing tests:** `dramaIsOnByDefault` (fresh suite → `true`; set `false` → `false`); `theShutoutDetailNamesTheLoser` (`String(localized: game.dramaDetail(.shutout(winner: .team1)))` contains team2's display name); `theSpokenLineIsInTheVoiceLanguage` (RF3: `dramaLine(.capicua(.team1), in: Locale(identifier: "es"))` starts with "¡Capicúa!").
- [ ] **Step 2: Run** — Expected: fails to build.
- [ ] **Step 3: Implement** both files, the Settings card, and the catalog entries (scratchpad `cat_add.py`).
- [ ] **Step 4: Run** tests and `ruby scripts/lint-strings.rb` — Expected: pass, lint exit 0.
- [ ] **Step 5: Commit** `feat: big-moment copy in English and Spanish, and a switch to turn it off`.

### Task 4: Capicúa as input — the sheet toggle and the spoken word

**Files:**
- Modify: `iScore/Model/ScoreCommand.swift`, `iScore/Model/VoiceScoring.swift`, `iScore/Views/AddGameScoreView.swift`, `iScore/Views/GameView.swift` (pattern matches only), `iScore/Localizable.xcstrings`
- Test: `iScoreTests/ScoreCommandTests.swift`, `iScoreTests/VoiceScoringTests.swift`

**Interfaces:**
- Produces: `ScoreCommand.record(points:team:capicua: Bool = false)`, `ScoreCommand.askTeam(points:capicua: Bool = false)`, `VoiceScoring.Outcome.recorded(points:team:capicua: Bool = false)`. Defaults keep every existing constructor compiling; only `case let` matches change.
- `AddGameScoreView(game:team:capicua: Binding<Bool>)`.

- [ ] **Step 1: Write the failing tests:**
  - `capicuaIsHeardInBothLanguages`: `parse("capicúa thirty for us", en…)` == `.record(points: 30, team: own, capicua: true)`; Spanish `"capicúa treinta para nosotros"` the same; `"capicua"` without accent too (folding).
  - `capicuaAloneIsNotACommand`: `parse("capicúa", …) == nil`.
  - `aPlainRoundIsNotACapicua`: `parse("thirty for us")` has `capicua == false`.
  - `theFlagSurvivesToTheOutcome`: `VoiceScoring.outcome(for: .record(points: 30, team: .team1, capicua: true), …) == .recorded(points: 30, team: .team1, capicua: true)`, and through `askTeam` with an `assumedTeam`.
- [ ] **Step 2: Run** — Expected: build fails (no `capicua` label).
- [ ] **Step 3: Implement.** The word list is `["capicua", "capicu"]` (folded). In `AddGameScoreView`, a Duo-styled `Toggle("Capicúa", isOn: $capicua)` (es "Capicúa") sits under the projection line; a spoken capicúa sets it before `addScore()`. `GameView` owns `@State private var nextRoundCapicua = false`, passes the binding, and `record(_:for:capicua:)` sets it for voice rounds.
- [ ] **Step 4: Run** the full suite — Expected: all pass (existing `.record(points:team:)` tests unchanged).
- [ ] **Step 5: Commit** `feat: capicúa can be marked on the keypad or said aloud`.

### Task 5: Show it, speak it

**Files:**
- Modify: `iScore/Views/GameView.swift`, `iScore/Views/RoundFeedbackBanner.swift`, `iScore/Views/GameSummaryView.swift`, `iScore/Views/VoiceScoreBar.swift`, `CLAUDE.md`
- Test: `iScoreTests/VoiceScoreBarTests.swift`

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: `RoundFeedbackBanner(round:game:highlight: GameDrama.Highlight? = nil, onUndo:)`; `GameSummaryView(game:highlight: GameDrama.Highlight? = nil, onNext:)`; `VoiceScoreBar(…, announcement: Binding<String?> = .constant(nil), …)` with pure `VoiceBarState.speaksAnnouncement(_ line: String?, isListening: Bool, isThinking: Bool, speaksAnswers: Bool) -> Bool`.

- [ ] **Step 1: Write the failing test** `anAnnouncementWaitsForTheMicAndHonorsTheSwitch`: `speaksAnnouncement("¡Zapato!", isListening: false, isThinking: false, speaksAnswers: true) == true`; `false` when listening, thinking, speech off, or `nil`.
- [ ] **Step 2: Run** — Expected: fails.
- [ ] **Step 3: Implement.**
  - `GameView`: `@Query(sort: \Game.timestamp) var allGames`, `@State shownDrama: Set<GameDrama.Kind>`, `@State roundHighlight: GameDrama.Highlight?`, `@State summaryHighlight`, `@State announcement: String?`. In `applyNewRound`, before `finishIfWon`, when `DramaSettings.isEnabled()` and a round was added: compute `roundHighlight(…)` with `nextRoundCapicua`, insert its kind into `shownDrama`, reset `nextRoundCapicua`. If the game finished, `summaryHighlight = finale(of:history:) ?? roundHighlight`; else pass it to the banner. Either way set `announcement = game.dramaLine(h, in: LanguageSettings.voiceLocale())`. Edit Score never calls this path (RF2).
  - `RoundFeedbackBanner`: with a highlight, the title is `dramaTitle`, the detail `dramaDetail`, the icon `sparkles`, and a `TrophyBurst` behind the icon. VoiceOver announcement uses the same two lines.
  - `GameSummaryView`: one `Text(game.dramaTitle(h))` + detail under the trophy, `duoLabel`-styled detail.
  - `VoiceScoreBar`: `.onChange(of: announcement)` and after `conclude` — if `speaksAnnouncement`, speak through its own `SpokenReply`, then set the binding to `nil`.
  - `CLAUDE.md`: a short "Round drama" section (pure `GameDrama`, ranking, never blocks entry, spoken through the bar).
- [ ] **Step 4: Run** the full suite; build and install on the simulator with `-demoData`, add a round that triggers a comeback and finish a game with a shutout; screenshot the banner and the summary — Expected: suite green; both highlights visible; entry buttons return after 2 s.
- [ ] **Step 5: Commit** `feat: big moments get a banner, a trophy burst and a spoken line`.
