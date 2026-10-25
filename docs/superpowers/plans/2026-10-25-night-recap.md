# Night Recap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a few games with the same group, the Game Summary offers one shareable card for the night: standings, each pair's record, the biggest round and the longest streak. One tap shares it to Messages or the group chat.

**Architecture:** A pure `NightRecap` (`iScore/Model/NightRecap.swift`) works out which games make up the night and every number on the card. No new storage: a "night" is inferred from finished games. A `NightRecapCard` view, built from Duo parts, is rendered with `ImageRenderer` at 2x and shared with `ShareLink` from a small `NightRecapView` sheet that the summary opens.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, String Catalog.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md` §10 "Night recap worth sending". Feature 8 (rivalries) is dropped, so the card carries no rivalry totals.

## Global Constraints

- iOS 26, Swift 5 mode, SwiftUI + SwiftData with CloudKit. **No new persisted property.**
- The Duo theme is law: colors from `Theme` only, `DuoFont`, `.duoCard`, and no gradients, shadows, blur or glass. The card must look like the app.
- The card must be **legible as a small image in a chat thread**: large numerals, few words, high contrast.
- Every visible string is localized, with Spanish in `iScore/Localizable.xcstrings`, and `ruby scripts/lint-strings.rb` passes.
- Register new files with `ruby scripts/xcodeproj.rb add iScore|iScoreTests <path>`.
- Tests: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`.

## Decisions the spec left open (my calls)

- **Which games make a night:** finished games on the same calendar day as this game (by `timestamp`) that share at least 3 of its 4 players, compared with `PlayerName.isSame`. Cancelled and in-progress games don't count. These are the spec's own words.
- **When it offers itself:** once the night has **2 or more** games. One game already has its own share card. The spec's "after three games" is the check that it works, not the threshold.
- **Standings:** each player's wins and games played tonight, ranked with the existing `Leaderboard.standings` (`PlayerRecord`), so ties rank the same as in the Hall of Fame.
- **Pairs:** a pair is the two names on a team, in any order and any case. Each pair's record is wins and losses tonight, sorted by wins and then by the fewest losses.
- **Biggest round:** the single largest round of the night, with the pair that scored it.
- **Longest streak:** the longest run of consecutive wins by one player within the night, in game order. It is shown only if it is 2 or more.
- **App Store link:** the spec asks for one, but the app has no App Store id yet. `NightRecap.appStoreURL` is `nil` for now, and the share text includes the link only when it's set, so it's a one-line change after release.
- **Entry point:** only the Game Summary has the button. Home stays as it is.

## Review Focus

1. **Name drift:** the same person typed "ana" in one game and "Ana" in another must be one player and one pair (RF1).
2. **A fifth player** who swaps in for one game: that game still counts, because it shares 3 players, and the new player appears in the standings with 1 game (RF2).
3. **Last night's games and cancelled games** never count (RF3).
4. **Long names** of 15 characters must not break the card's layout at the rendered size. Check this in the simulator.
5. **The summary of the night's first game** offers no recap (RF4).

---

### Task 1: Which games make the night

**Files:**
- Create: `iScore/Model/NightRecap.swift`
- Test: `iScoreTests/NightRecapTests.swift`

**Interfaces:**
- Produces: `enum NightRecap { static let minimumGames = 2; static let sharedPlayers = 3; static let appStoreURL: URL? = nil; static func games(tonightWith game: Game, in games: [Game], calendar: Calendar = .current) -> [Game] }`. It returns the night's finished games oldest first, with `game` included when it's finished.

- [ ] **Step 1: Write the failing tests.** Build finished games with `Game(gameType:maxScore:)`, then set `team1`, `team2`, `timestamp` and `state`.
  - `sameDaySameGroupIsTheNight`: 3 games today with Ana, Luis, Rafa and Mia → all 3, oldest first.
  - `threeSharedPlayersIsEnough` (RF2): a game with Ana, Luis, Rafa and Carlos counts.
  - `twoSharedPlayersIsAnotherTable`: Ana, Luis, Pedro and Carlos → excluded.
  - `namesMatchWhateverTheCase` (RF1): "ana", "LUIS", "Rafa", "mia" counts.
  - `yesterdayAndCancelledDoNotCount` (RF3): a game from yesterday and a game cancelled today → excluded. A game still in progress → excluded.
- [ ] **Step 2: Run** `-only-testing:iScoreTests/NightRecapTests`. Expected: the build fails because `NightRecap` is undefined.
- [ ] **Step 3: Implement** `games(tonightWith:in:calendar:)`.
- [ ] **Step 4: Run.** Expected: the tests pass.
- [ ] **Step 5: Commit** `feat: NightRecap finds the night's games`.

### Task 2: The night's numbers

**Files:**
- Modify: `iScore/Model/NightRecap.swift`
- Test: `iScoreTests/NightRecapTests.swift`

**Interfaces:**
- Consumes: `games(tonightWith:in:calendar:)`, `PlayerRecord`, `Leaderboard.standings`, `PlayerName.isSame`.
- Produces:
  ```swift
  struct NightRecap {
      struct Pair: Equatable { let names: [String]; let won: Int; let lost: Int }   // names in first-seen spelling and seat order
      struct BigRound: Equatable { let points: Int; let names: [String] }
      struct Streak: Equatable { let name: String; let wins: Int }
      let date: Date
      let gamesPlayed: Int
      let standings: [Standing]
      let pairs: [Pair]
      let biggestRound: BigRound?
      let longestStreak: Streak?          // nil below 2
      /// nil when the night has fewer than `minimumGames` games.
      init?(tonightWith game: Game, in games: [Game], calendar: Calendar = .current)
  }
  ```
  Move the Task 1 statics onto this struct. The enum becomes this struct.

- [ ] **Step 1: Write the failing tests.** Use a night of 3 games: Ana & Luis beat Rafa & Mia, Rafa & Mia beat Ana & Luis, then Ana & Rafa beat Luis & Mia. Rounds include one 85.
  - `oneGameIsNotANight` (RF4): the first game alone → `nil`.
  - `standingsCountTonightOnly`: Ana and Rafa have 2 wins each and Luis and Mia have 1; everyone played 3 games, and ranks match `Leaderboard.standings`.
  - `pairsKeepTheirRecordInAnyOrder`: "Luis & Ana" in a later game is the same pair as "Ana & Luis". Ana & Luis are 1–1, Rafa & Mia are 1–1, Ana & Rafa are 1–0, Luis & Mia are 0–1. The order is by wins, then the fewest losses.
  - `theBiggestRoundAndWhoScoredIt`: `BigRound(points: 85, names: […])`.
  - `aStreakNeedsTwoInARow`: in the 3-game night, Rafa wins games 2 and 3 → `Streak(name: "Rafa", wins: 2)`. In a night where nobody wins twice in a row → `nil`.
- [ ] **Step 2: Run.** Expected: it fails.
- [ ] **Step 3: Implement** the struct.
- [ ] **Step 4: Run** the full suite. Expected: everything passes.
- [ ] **Step 5: Commit** `feat: NightRecap counts the night's standings, pairs, big round and streak`.

### Task 3: The card, the sheet and the share

**Files:**
- Create: `iScore/Views/NightRecapCard.swift` (the card and the sheet)
- Modify: `iScore/Views/GameSummaryView.swift`, `iScore/Localizable.xcstrings`, `CLAUDE.md`
- Test: `iScoreTests/NightRecapTests.swift`

**Interfaces:**
- Consumes: `NightRecap`.
- Produces: `NightRecapCard(recap: NightRecap)`, a fixed width of 360pt rendered at 2x. `NightRecapView(recap: NightRecap)` is a sheet with the card preview, a `ShareLink` of the rendered image plus `NightRecap.shareText`, and Done. Add `var shareText: String` to `NightRecap`: the localized "Tonight's dominoes" line, plus the App Store URL when it's set.
- **Card layout,** top to bottom, all Duo:
  1. The "dominoes" wordmark, then "Tonight · N games" with the date.
  2. Standings rows: rank, name, and wins as a large numeral (`DuoFont.score(28)`). The leader's row uses the gold edge.
  3. Pair rows: "Ana & Luis" with "2–1" in the pair's team-palette fill.
  4. Two `SummaryStatTile`-style tiles: "Biggest round 85" and "Streak 3". A tile is hidden when its value is nil.
- **Copy, English → Spanish:**
  - "Night recap" → "Resumen de la noche"
  - "Tonight · %lld games" → "Esta noche · %lld partidas" (a plural entry)
  - "Standings" → "Posiciones"
  - "Pairs" → "Parejas"
  - "Biggest round" → "Ronda más grande"
  - "Streak" → "Racha"
  - "Tonight's dominoes" → "El dominó de esta noche"
  - "Share the night" → "Compartir la noche"

- [ ] **Step 1: Write the failing test** `theShareTextOnlyLinksWhenThereIsALink`: with `appStoreURL == nil`, `shareText` contains no "http".
- [ ] **Step 2: Run.** Expected: it fails because `shareText` is undefined.
- [ ] **Step 3: Implement** the card, the sheet and `shareText`. In `GameSummaryView`, add `@Query private var allGames: [Game]` and show a `.duoCard` button "Night recap" (es "Resumen de la noche") with the `moon.stars.fill` icon under the stat tiles, only when `NightRecap(tonightWith: game, in: allGames) != nil`. The button opens `NightRecapView`. Add the catalog entries and a short "Night recap" section to `CLAUDE.md`.
- [ ] **Step 4: Run** the full suite and lint. Then, in the simulator with `-demoData`, finish the in-progress game, start and finish a second game with the same players, open its summary, then open Night recap. Screenshot it, and check one 15-character name. Expected: the suite is green and the card is readable at about a third of its size.
- [ ] **Step 5: Commit** `feat: a night recap card to share after a few games together`.
