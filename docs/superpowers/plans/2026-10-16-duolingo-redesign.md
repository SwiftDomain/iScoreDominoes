# iScore "Duo" Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle iScoreDominoes in the approved Duolingo-inspired "Duo" look: new palette and type first, then rebuild Home, Game and Add Score to match the mockups.

**Architecture:** Re-value the existing colorsets and add new ones so every screen shifts palette at once; `Theme.swift` gains team palettes and rounded type helpers. Pure logic (scoreboard math, copy, keypad entry, day streak) lives in small model files with Swift Testing coverage. A thin layer of shared views (pressable button/card styles, progress bar, avatars) is then composed into the three redesigned screens.

**Tech Stack:** Swift 5 mode, SwiftUI, SwiftData, iOS 26.0, Swift Testing, Ruby `xcodeproj` gem (dev tooling only).

**Spec:** `docs/superpowers/specs/2026-10-16-duolingo-redesign-design.md` (palette hex values, type, shapes, per-screen layout and exact copy). Read it before every task.

## Global Constraints

- Work on branch `duo-redesign` cut from `main`. Never commit `.DS_Store` or `*.xcuserstate`.
- iOS deployment target 26.0, `SWIFT_VERSION = 5.0`, no new runtime dependencies.
- Colors only through `Theme` (CLAUDE.md rule); no `Color(...)` literals or `.opacity` hacks on brand colors in views. Only exception: the progress bar highlight uses `Theme.surface.opacity(0.3)`.
- No gradients, shadows, blur, `.glassEffect` or `.buttonStyle(.glass)` in redesigned screens.
- Keep `.preferredColorScheme(.light)` at the root; add `.fontDesign(.rounded)` there.
- Radii: cards 16, buttons/keys 14, chips 8, icon squares 12. Pressable edge 4pt (2pt for stat tiles and the speech bubble).
- Text on saturated fills is `Theme.surface` (white).
- Content max width stays 700 (iPad).
- Copy strings exactly as in the spec's Copy section.
- The project uses classic groups (objectVersion 56): every new or deleted Swift file goes through `ruby scripts/xcodeproj.rb add|remove` (Task 1).
- Test command (referred to below as **TEST**):
  `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -quiet`
  (if the name is ambiguous, use `id=1CCD5BAB-65A3-4751-A7E9-2E966580E6B9`). Pass = `** TEST SUCCEEDED **`.
- Visual check (referred to as **RUN-DEMO**): build with `-derivedDataPath "$TMPDIR/iscore-dd"`, `xcrun simctl install` the `Debug-iphonesimulator/iScore.app`, then `xcrun simctl launch <sim> SwiftDomainUI.iScore -demoData` and take a simulator screenshot. Compare against the spec's screen section, item by item.

## Review Focus

1. Totals past the target (e.g. 230 of 200): bars clamp at full, "to win" never goes negative, projection says "Wins the game!" — tests in Task 3.
2. Tied or empty games: no crown, no leader color, headline "All tied up" / "Let's play!" — tests in Task 3.
3. Missing or long player names (`team1` empty, 20+ characters): no index-out-of-range crash, names fall back to "Team 1"/"Team 2", text truncates — tests in Task 3, visual check in Task 8.
4. Keypad abuse: leading zeros, a 4th digit, delete on empty, Add with nothing entered → no 0-point rounds ever saved — tests in Task 4.
5. The seed row `[0, 0]` and rounds edited down to 0 must not appear as rounds, and numbering stays 1, 2, 3… — tests in Task 3.

---

### Task 1: Project tooling and test target

**Files:**
- Create: `scripts/xcodeproj.rb`
- Create: `iScoreTests/SmokeTests.swift`
- Modify (via script): `iScore.xcodeproj/project.pbxproj`, `iScore.xcodeproj/xcshareddata/xcschemes/iScore.xcscheme`

**Interfaces:**
- Produces: `ruby scripts/xcodeproj.rb setup-tests`, `ruby scripts/xcodeproj.rb add <target> <path>...`, `ruby scripts/xcodeproj.rb remove <path>...`; test target `iScoreTests` that can `@testable import iScore`.

- [ ] **Step 1: Create the branch** — `git switch -c duo-redesign`.
- [ ] **Step 2: Install the gem** (network download; ask the user first) — `gem install --user-install xcodeproj`. Pass = `ruby -e 'require "xcodeproj"; puts Xcodeproj::VERSION'` prints a version.
- [ ] **Step 3: Write `scripts/xcodeproj.rb`** — opens `iScore.xcodeproj` with the `xcodeproj` gem; all three commands are idempotent and save the project.
  - `setup-tests`: create native target `iScoreTests` (`:unit_test_bundle`, `:ios`, `'26.0'`, `:swift`), root group `iScoreTests` (path `iScoreTests`), dependency on target `iScore`. Build settings for Debug and Release: `PRODUCT_BUNDLE_IDENTIFIER = SwiftDomainUI.iScoreTests`, `TEST_HOST = $(BUILT_PRODUCTS_DIR)/iScore.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/iScore`, `BUNDLE_LOADER = $(TEST_HOST)`, `GENERATE_INFOPLIST_FILE = YES`, `SWIFT_VERSION = 5.0`, `TARGETED_DEVICE_FAMILY = 1,2`, `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM` copied from target `iScore`. Add the target as a testable in the shared scheme's TestAction.
  - `add <target> <path>...`: for each repo-relative path, walk/create groups matching its directories (each group's `path` = folder name), add a file reference, and add it to the target's sources phase.
  - `remove <path>...`: remove the build files and the file reference.
- [ ] **Step 4: Write `iScoreTests/SmokeTests.swift`** — `@Test func appModuleLoads() { #expect(GameType.allCases.count == 2) }` with `import Testing` and `@testable import iScore`.
- [ ] **Step 5: Wire it up** — `ruby scripts/xcodeproj.rb setup-tests && ruby scripts/xcodeproj.rb add iScoreTests iScoreTests/SmokeTests.swift`.
- [ ] **Step 6: Run TEST** — expect `** TEST SUCCEEDED **` with 1 test.
- [ ] **Step 7: Commit** — `git add scripts iScoreTests iScore.xcodeproj/project.pbxproj iScore.xcodeproj/xcshareddata && git commit -m "Add iScoreTests target and xcodeproj helper script"`

### Task 2: Duo palette, Theme and rounded type

**Files:**
- Modify: the 10 colorsets in `Assets.xcassets/` (`AccentColor` both entries, `accentInk`, `background_primary`, `surface`, `surfaceSecondary`, `textPrimary`, `textSecondary`, `success`, `danger`, `dividerColor`) to the spec's hex values.
- Create colorsets in `Assets.xcassets/`: `textMuted`, `teamA`, `teamAShadow`, `teamAWash`, `teamB`, `teamBShadow`, `teamBWash`, `gold`, `goldShadow`, `streak`, `streakShadow`, `learn`, `learnShadow`, `dangerShadow` (same `Contents.json` shape as `surface.colorset`: one universal sRGB entry, components as 0–1 decimals). The asset catalog is a folder reference, so it needs no pbxproj change.
- Modify: `iScore/Model/Theme.swift`, `iScore/Model/Config.swift` (`Background`), `iScore/iScoreApp.swift`, `CLAUDE.md`
- Test: `iScoreTests/ThemeTests.swift`

**Interfaces:**
- Produces: `Theme.textMuted`, `.teamA`, `.teamAShadow`, `.teamAWash`, `.teamB`, `.teamBShadow`, `.teamBWash`, `.gold`, `.goldShadow`, `.streak`, `.streakShadow`, `.learn`, `.learnShadow`, `.dangerShadow` (all `Color`); `struct TeamPalette { let fill: Color; let edge: Color; let wash: Color }`; `static func Theme.palette(for team: Team) -> TeamPalette`; `static let Theme.colorAssetNames: [String]`; `enum DuoFont { static func score(_ size: CGFloat) -> Font; static let title: Font; static let body: Font; static let label: Font }`.
- Existing `Theme` members keep their names (other screens depend on them). `backgroundGradient` and `surfaceGradient` are deleted.

- [ ] **Step 1: Write the failing tests** in `iScoreTests/ThemeTests.swift`:
  - `@Test(arguments: Theme.colorAssetNames) func colorAssetExists(_ name: String)` → `#expect(UIColor(named: name) != nil)`. This catches misspelled colorset names, which `Color("…")` otherwise fails on silently.
  - `@Test func colorAssetNamesAreComplete()` → `#expect(Theme.colorAssetNames.count == 24)` (10 existing + 14 new).
  - `@Test func teamPalettes()` → `palette(for: .team1)` is `(teamA, teamAShadow, teamAWash)`, `.team2` is `(teamB, teamBShadow, teamBWash)`, `.none` is `(textMuted, textSecondary, surfaceSecondary)`.
- [ ] **Step 2: Register and run** — `ruby scripts/xcodeproj.rb add iScoreTests iScoreTests/ThemeTests.swift`, run TEST. Expect a compile failure (`colorAssetNames`/`palette` missing).
- [ ] **Step 3: Implement** the colorsets and the `Theme` additions. `DuoFont.score(size)` = `.system(size:weight: .black, design: .rounded)`; `title` = `.system(.title2, design: .rounded, weight: .heavy)`; `body` = `.system(.body, design: .rounded, weight: .bold)`; `label` = `.system(.footnote, design: .rounded, weight: .heavy)`. Rewrite the file header comment to describe the Duo palette. `Background` becomes `Theme.background.ignoresSafeArea()`. In `iScoreApp`, add `.fontDesign(.rounded)` next to `.preferredColorScheme(.light)` and update its comment.
- [ ] **Step 4: Run TEST** — expect pass.
- [ ] **Step 5: Update `CLAUDE.md`** — replace the "Theme (Manga Paper)" section with a "Theme (Duo)" summary of the spec's palette table, type and shape rules, and the white-on-fill rule. Point "Active plan" at this file.
- [ ] **Step 6: Visual check** — build and launch normally (no demo data yet). Expect a white background, gray rounded text and green accents on every screen, with no missing-color (clear) elements.
- [ ] **Step 7: Commit** — `git commit -am "Switch Theme to Duo palette and rounded type"` (stage the new colorsets and test file too).

### Task 3: Scoreboard logic and copy

**Files:**
- Create: `iScore/Model/Game+Scoreboard.swift`
- Test: `iScoreTests/GameScoreboardTests.swift`

**Interfaces:**
- Produces:
  - `struct Round: Identifiable, Equatable { let id: Int /* scoreTeam index */; let number: Int; let team: Team; let points: Int }`
  - `extension GameType { var pips: Int }` (six → 6, nine → 9)
  - `extension Game`: `func total(for: Team) -> Int` · `func progress(for: Team) -> Double` · `func pointsToWin(for: Team) -> Int` · `var leader: Team` · `var lead: Int` · `var rounds: [Round]` · `var currentRoundNumber: Int` · `func names(for: Team) -> [String]` · `func displayName(for: Team) -> String` · `var headline: String` · `func projectionSummary(adding points: Int, to team: Team) -> String` · `func feedbackDetail(for round: Round) -> String` · `func addRound(_ points: Int, for team: Team)` · `static func initials(of name: String) -> String`
- Rules: `.none` → total 0, names `[]`, displayName `""`. `progress` = total / maxScore clamped to 0…1, and 0 when `maxScore <= 0`. `pointsToWin` = `max(0, Int(maxScore) - total)`. `leader` = the higher total, `.none` on a tie. A `scoreTeam` row becomes a `Round` for team 1 if `row[0] > 0`, else team 2 if `row[1] > 0`, else it is skipped; rounds are numbered 1… in order. `addRound` appends `[p, 0]` / `[0, p]` and ignores `p <= 0` and `.none`. `feedbackDetail` = `"{name} +{points} · {pointsToWin} to win"`. Headline and projection copy as in the spec.

- [ ] **Step 1: Write failing tests** with a helper `makeGame(maxScore: Double = 200, rows: [[Int]], team1: [String] = ["Ana", "Luis"], team2: [String] = ["Rafa", "Mia"], state: GameState = .playing) -> Game`. It builds an unmanaged `Game`; if SwiftData traps outside a context, insert it into an in-memory `ModelContainer` the way `Previewer` does. Let `demoRows = [[0,0],[25,0],[0,30],[45,0],[0,15],[35,0]]`.
  - `totalsAndProgress` (demoRows): totals 105/45, `progress(for: .team1) == 0.525`, `pointsToWin(for: .team2) == 155`, `leader == .team1`, `lead == 60`, `currentRoundNumber == 6`, `headline == "Ana & Luis lead by 60"`.
  - `progressClampsPastTarget` (`[[0,0],[230,0]]`): progress 1.0, `pointsToWin == 0`.
  - `zeroMaxScoreIsSafe` (maxScore 0): `progress(for: .team1) == 0`.
  - `tieHasNoLeader` (`[[0,0],[20,0],[0,20]]`): `leader == .none`, headline `"All tied up"`.
  - `emptyGame` (`[[0,0]]`): `rounds.isEmpty`, headline `"Let's play!"`, `currentRoundNumber == 1`.
  - `finishedHeadline` (`[[0,0],[200,0]]`, `.finished`): `"Ana & Luis won!"`.
  - `roundsSkipSeedAndZeroRows` (`[[0,0],[10,0],[0,0],[0,5]]`): numbers `[1,2]`, teams `[.team1,.team2]`, points `[10,5]`, ids `[1,3]`.
  - `displayNameFallbacks`: team1 `[]` → `"Team 1"`, team2 `[]` → `"Team 2"`, team2 `["Solo"]` → `"Solo"`.
  - `initials`: `"ana"` → `"A"`, `"  "` → `"?"`, `""` → `"?"`.
  - `projection` (demoRows): `(35, .team1)` → `"105 → 140 · 60 to win"`, `(100, .team1)` → `"105 → 205 · Wins the game!"`.
  - `feedback` (demoRows): `feedbackDetail(for: rounds.last!) == "Ana & Luis +35 · 95 to win"`.
  - `addRound`: `addRound(35, for: .team2)` → `scoreTeam.last == [0,35]`; `addRound(0, for: .team1)` and `addRound(5, for: .none)` leave the count unchanged.
  - `pips`: `GameType.six.pips == 6`, `.nine.pips == 9`.
- [ ] **Step 2: Register both files** with `xcodeproj.rb add` (app file → `iScore`, test → `iScoreTests`). Run TEST → compile failure.
- [ ] **Step 3: Implement `Game+Scoreboard.swift`.**
- [ ] **Step 4: Run TEST** — all pass.
- [ ] **Step 5: Commit** — `"Add scoreboard logic and copy for Duo screens"`.

### Task 4: Keypad score entry

**Files:**
- Create: `iScore/Model/ScoreEntry.swift`
- Test: `iScoreTests/ScoreEntryTests.swift`

**Interfaces:**
- Produces: `struct ScoreEntry: Equatable { private(set) var digits: String; static let maxDigits = 3; mutating func append(_ digit: Int); mutating func deleteLast(); mutating func clear(); var value: Int? { get }; var buttonTitle: String { get } }`. `append` ignores values outside 0…9, a leading 0 and any digit past `maxDigits`; `value` is nil when `digits` is empty.

- [ ] **Step 1: Write failing tests:**
  - `typesNumber`: 3, 5 → `digits == "35"`, `value == 35`, `buttonTitle == "Add 35 points"`.
  - `ignoresLeadingZero`: 0 → `digits == ""`, `value == nil`; then 5, 0 → `"50"`.
  - `capsAtThreeDigits`: 1, 2, 3, 4 → `"123"`.
  - `deleteAndClear`: `deleteLast()` on empty is a no-op; 4, 2, `deleteLast()` → `"4"`; `clear()` → `value == nil`.
  - `ignoresInvalidDigit`: `append(12)` and `append(-1)` → `""`.
  - `buttonTitles`: empty → `"Add points"`, 1 → `"Add 1 point"`.
- [ ] **Step 2: Register files, run TEST** → compile failure.
- [ ] **Step 3: Implement `ScoreEntry`.**
- [ ] **Step 4: Run TEST** — pass.
- [ ] **Step 5: Commit** — `"Add ScoreEntry keypad model"`.

### Task 5: Demo data for previews and visual checks

**Files:**
- Create: `iScore/Model/DemoData.swift` (whole file inside `#if DEBUG`)
- Modify: `iScore/iScoreApp.swift` (init), `iScore/Views/Previewer.swift`
- Test: `iScoreTests/DemoDataTests.swift`

**Interfaces:**
- Consumes: `Game` APIs from Task 3.
- Produces: `enum DemoData { static let launchArgument = "-demoData"; @MainActor static func seed(into context: ModelContext) -> Game }`, which returns the active game.
- Seed contents:
  - **Active game:** `.nine`, max 200, Ana/Luis vs Rafa/Mia, the demo rows from Task 3, `.playing`, `inProcess = true`, now.
  - **Finished game:** `.nine`, 200, Ana/Luis vs Rafa/Mia, `[[0,0],[120,0],[0,145],[80,0]]`, `.finished`, `inProcess = false`, 4 days ago.
  - **Cancelled game:** `.six`, 200, Rafa/Mia vs Tito/Eva, `[[0,0],[80,0],[0,95]]`, `.cancelled`, `inProcess = false`, 7 days ago.

- [ ] **Step 1: Write failing tests** (in-memory container): `seed` inserts 3 games, exactly 1 has `inProcess`, and the returned game has totals 105/45.
- [ ] **Step 2: Register files, run TEST** → compile failure.
- [ ] **Step 3: Implement.**
  - In `iScoreApp.init`, under `#if DEBUG`: when `ProcessInfo.processInfo.arguments` contains `DemoData.launchArgument`, build the container with `ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)` and call `seed(into: modelContainer.mainContext)`. Otherwise keep today's CloudKit configuration unchanged.
  - Change `Previewer.game` to come from `DemoData.seed`.
- [ ] **Step 4: Run TEST** — pass. Then RUN-DEMO. The current Home should show a resume banner with 105 – 45 and two recent games. A normal launch must still show your real data.
- [ ] **Step 5: Commit** — `"Add DEBUG demo data launch argument"`.

### Task 6: Shared Duo components

**Files:**
- Create: `iScore/Views/DuoStyle.swift`, `iScore/Views/DuoProgressBar.swift`, `iScore/Views/TeamAvatars.swift`

**Interfaces:**
- Consumes: `TeamPalette`, `DuoFont`, `Theme` (Task 2); `Game.initials(of:)` (Task 3).
- Produces:
  - `struct DuoButtonStyle: ButtonStyle { let fill: Color; let edge: Color; var foreground: Color = Theme.surface }`, plus `extension ButtonStyle where Self == DuoButtonStyle { static func duo(_ palette: TeamPalette) -> DuoButtonStyle; static func duo(fill: Color, edge: Color, foreground: Color) -> DuoButtonStyle }`. Full width, min height 50, radius 14, `DuoFont.label` uppercased with tracking 0.8. It reads `\.isEnabled`: disabled = `Theme.divider` fill, `Theme.textMuted` text, no edge.
  - `struct DuoCardStyle: ButtonStyle { var edge: CGFloat = 4 }` + `static var duoCard: DuoCardStyle`. Pressable card: white, radius 16, 2pt `Theme.divider` border, bottom edge; pressed = content drops by `edge`.
  - `extension View { func duoCard(edge: CGFloat = 4, border: Color = Theme.divider) -> some View; func duoLabel() -> some View }`. `duoLabel` = `DuoFont.label`, uppercase, tracking 0.8, `Theme.textMuted`.
  - `struct DuoProgressBar: View { let value: Double; var preview: Double? = nil; var tint: Color = Theme.teamA; var previewTint: Color = Theme.teamAWash; var track: Color = Theme.divider; var height: CGFloat = 16 }`. Values are clamped to 0…1. The preview segment is drawn under the fill. Highlight strip: `Theme.surface.opacity(0.3)`, 4pt tall, inset 8pt, only when the fill is wider than 24pt. Animate with `.spring` on value changes.
  - `struct TeamAvatars: View { let names: [String]; let palette: TeamPalette; var size: CGFloat = 28 }`. Overlapping circles (overlap = size × 0.3): the first in `fill`, the second in `edge`. White initials in `DuoFont.score(size * 0.42)`, a 2pt white ring, `accessibilityHidden(true)`.

- [ ] **Step 1: Register the three files** with `xcodeproj.rb add iScore …`.
- [ ] **Step 2: Implement** each with a `#Preview`:
  - **Buttons:** green and blue `.duo` buttons, a disabled button, and a white "Continue" `.duo(fill: Theme.surface, edge: Theme.teamAWash, foreground: Theme.teamA)` on a green card.
  - **Cards:** a `.duoCard` tile.
  - **Progress bars:** at 0, 0.525, 1.0 and with `preview: 0.7`.
  - **Avatars:** with 2 names and with `[]`.
- [ ] **Step 3: Verify** — run TEST (still passes, which proves the build) and render each preview (Xcode canvas or `xcodebuild build`). Press states must offset the content instead of shrinking it.
- [ ] **Step 4: Commit** — `"Add Duo button, card, progress bar and avatar components"`.

### Task 7: Home

**Files:**
- Create: `iScore/Model/PlayStreak.swift`
- Modify: `iScore/Views/HomeView.swift`, `iScore/Views/ActiveGameBanner.swift`, `iScore/Views/HomeCardView.swift`, `iScore/Views/RecentGameCard.swift`, `iScore/Views/QuickStatsBar.swift`
- Test: `iScoreTests/PlayStreakTests.swift`

**Interfaces:**
- Consumes: Tasks 2, 3 and 6.
- Produces:
  - `enum PlayStreak { static func days(endingOn today: Date, playDates: [Date], calendar: Calendar = .current) -> Int }`. Counts consecutive calendar days with at least one game, starting at `today`, or at yesterday when there's no game today.
  - `HomeCardView(icon: String, title: String, subtitle: String, tint: Color)` draws content only; the grid applies `.buttonStyle(.duoCard)`.
  - `ActiveGameBanner(game:)`, `RecentGameCard(game:)` and `QuickStatsBar(totalGames:totalWins:winPercentage:)` keep their signatures.

- [ ] **Step 1: Write failing tests** (fixed `today` = 2026-10-16 noon, Gregorian calendar):
  - today, yesterday and 2 days ago → 3;
  - yesterday and 2 days ago → 2;
  - only 3 days ago → 0;
  - `[]` → 0;
  - two games today → 1.
- [ ] **Step 2: Register files, run TEST** → compile failure. **Step 3:** implement `PlayStreak`. **Step 4:** run TEST → pass.
- [ ] **Step 5: Rebuild Home per the spec's Home section:**
  - **Toolbar:** "dominoes" wordmark at leading (`DuoFont.score(26)`, `Theme.teamA`, `.sharedBackgroundVisibility(.hidden)`). Trailing: flame chip (`flame.fill`, `Theme.streak`, `PlayStreak.days(endingOn: .now, playDates: allGames.map(\.timestamp))`), trophy chip (`trophy.fill`, `Theme.gold`, finished-games count) and the settings gear (`Theme.textMuted`). Keep `navigationTitle("Dominoes")` so pushed screens' back buttons read "Dominoes", but don't display a large title. Remove `.toolbarColorScheme(.dark…)`.
  - **Continue card:** `ActiveGameBanner` (whole card stays the `NavigationLink`). Label "Game in progress · Double \(pips)", and a `DuoProgressBar` with `tint: Theme.surface, track: Theme.teamAShadow, height: 12` at `progress(for: leader)`, or for team 1 when tied.
  - **Tiles:** New game `plus` / `teamA`, All games `list.bullet.rectangle` / `teamB`, Hall of fame `trophy.fill` / `gold`, How to play `graduationcap.fill` / `learn`. Keep the existing subtitles.
  - **Recent games header:** "Recent games" plus a "View all" `NavigationLink` to `GamesView(path:)` in `Theme.teamB` with `duoLabel` sizing.
  - **Recent game cards:** 170pt wide. Show a FINISHED/CANCELLED chip, `displayName`s, "200 – 145" in `DuoFont.score(22)` and "D\(pips) · \(date abbreviated)".
  - **Stats:** three `.duoCard(edge: 2)` tiles — `square.stack.fill` / `teamB`, `trophy.fill` / `gold`, `target` / `streak`.
- [ ] **Step 6: RUN-DEMO and compare** to the spec's Home list. Also check an iPad simulator (max width 700) and a run without `-demoData` and no games (no banner, no recents, no stats, tiles only).
- [ ] **Step 7: Commit** — `"Redesign Home in Duo style"`.

### Task 8: Game screen and round feedback

**Files:**
- Create: `iScore/Views/TeamScoreCard.swift`, `iScore/Views/RoundRow.swift`, `iScore/Views/RoundFeedbackBanner.swift`
- Modify: `iScore/Views/GameView.swift`

**Interfaces:**
- Consumes: Tasks 2, 3 and 6.
- Produces: `TeamScoreCard(game: Game, team: Team)`, `RoundRow(round: Round)`, `RoundFeedbackBanner(round: Round, game: Game)` (title "Nice round!", detail `game.feedbackDetail(for:)`, background `palette.wash`, text `palette.edge`, white check badge with a `palette.fill` check).

- [ ] **Step 1: Register the three new files.**
- [ ] **Step 2: Build the components** to the spec's Game section, each with a `#Preview` using `Previewer`:
  - **`TeamScoreCard`:** the leader gets a `palette.fill` border plus a gold `crown.fill` badge at the top trailing corner. Total in `DuoFont.score(42)`. Bar height 10. Footer "\(pointsToWin) to win". Use `.accessibilityElement(children: .combine)`.
  - **`RoundRow`:** a 28pt round-number circle on `surfaceSecondary`. The scoring column shows "+\(points)" in its team color; the other column shows "—" in `Theme.divider`.
- [ ] **Step 3: Rewrite the `GameView` body:**
  - **Toolbar:** principal = `DuoProgressBar` (width 180) at the leader's progress in the leader's color, or `Theme.textMuted` and team 1's value when tied. Trailing = undo and info, tinted `Theme.textMuted`.
  - **Header and team cards:** `duoLabel` "Round \(currentRoundNumber) · First to \(Int(maxScore))", the `headline` in `DuoFont.title`, then the two `TeamScoreCard`s.
  - **Rounds:** a "Rounds" / "\(rounds.count) played" header, then `rounds.reversed()` as `RoundRow`s. Long-press keeps opening `EditScoreView`: build a `GameScoreIndex()` and set `index = round.id`, `team = round.team`, `value = round.points`, as today. Keep `.popoverTip(editScore)` and the empty-state copy.
  - **Bottom bar:** `.safeAreaInset(edge: .bottom)` with a 2pt top divider and two buttons ("plus" + `displayName`, `.lineLimit(1)`, `.minimumScaleFactor(0.7)`) styled `.duo(Theme.palette(for:))`. Keep `.disabled(game.state != .playing)`.
  - **Feedback banner:** remember `rounds.count` when presenting Add Score. In `onDismiss`, when the count grew and the game is still `.playing` after the existing win check, set `@State var feedback: Round?` to `rounds.last`. While it's set, `RoundFeedbackBanner` replaces the bottom bar (`.transition(.move(edge: .bottom))`) and `.task(id: feedback)` clears it after 2 seconds.
  - **Keep and delete:** keep the undo alert, both sheets, `GameSummaryView` on win and `maxWidth: 700`. Delete `TeamView`, `CircularProgressAroundIcon`, `NotifyAnimationPhase`, `progress1`/`progress2`, all glass modifiers and `BlobShape` use in this file.
- [ ] **Step 4: Run TEST, then RUN-DEMO:**
  - Tap Continue and compare to the spec's Game list.
  - Long-press round 5 → Edit Score opens.
  - Undo → the alert removes round 5 and the headline updates.
  - Temporarily seed a team name of 24 characters and check that the buttons and cards truncate cleanly (Review Focus 3), then revert.
- [ ] **Step 5: Commit** — `"Redesign Game screen with team cards, rounds and feedback banner"`.

### Task 9: Add Score

**Files:**
- Create: `iScore/Views/ScoreKeypad.swift`
- Modify: `iScore/Views/AddGameScoreView.swift`
- Delete: `iScore/Views/AnimatedMeshGradient.swift`. Grep first: its only use is in `AddGameScoreView`. Remove it via `xcodeproj.rb remove` before deleting the file.

**Interfaces:**
- Consumes: `ScoreEntry` (Task 4), `Game.addRound` / `progress` / `projectionSummary` (Task 3), Duo components (Task 6).
- Produces: `ScoreKeypad(entry: Binding<ScoreEntry>)`, a 3-column grid of 52pt `.duoCard` keys: 1–9, "Clear", 0, `delete.backward`. Accessibility labels "Clear" and "Delete". `.sensoryFeedback(.selection, trigger: entry.wrappedValue)`. `AddGameScoreView(game:team:)` keeps its signature.

- [ ] **Step 1: Register `ScoreKeypad.swift`** and implement it with a `#Preview`.
- [ ] **Step 2: Rewrite `AddGameScoreView`** per the spec's Add Score section, with `@State var entry = ScoreEntry()` and `let palette = Theme.palette(for: team)`:
  - **Top row:** an `xmark` close button (`Theme.textMuted`, label "Close") and a `DuoProgressBar` (`value: progress(for: team)`, `preview: Double(total + (entry.value ?? 0)) / maxScore`, `tint: palette.fill`, `previewTint: palette.wash`).
  - **Speech bubble:** `TeamAvatars(size: 40)` beside a `.duoCard(edge: 2)` bubble with the exact copy.
  - **Number well:** `surfaceSecondary` fill, height 84, radius 16. The border is `palette.fill` when `entry.value != nil`, otherwise `Theme.divider`. Show `entry.digits`, or "0" in `textMuted`, in `DuoFont.score(52)`.
  - **Projection line:** `projectionSummary`, shown only while `entry.value != nil`.
  - **Keypad and button:** the keypad, then a bottom `Button(entry.buttonTitle)` with `.duo(palette)`, disabled when `entry.value == nil`. Its action is `game.addRound(value, for: team)` then `dismiss()`.
  - **Remove:** the player image, the `TextField`, `BlobShape` and the mesh gradient.
- [ ] **Step 3: Run TEST, then RUN-DEMO:**
  - **Normal round:** Continue → "+ Ana & Luis" → 3, 5. The well shows 35, the line reads "105 → 140 · 60 to win" and the button reads "ADD 35 POINTS". Tap it: back on Game, totals are 140 – 45, round 6 is on top, and "Nice round!" shows for about 2 seconds.
  - **Winning round:** "+ Ana & Luis" → 1, 0, 0 → "Wins the game!". Add it → `GameSummaryView` appears and no banner shows.
  - **Empty entry:** the button is disabled and gray.
  - **Leading zero:** 0 first does nothing.
- [ ] **Step 4: Commit** — `"Redesign Add Score with keypad and live projection"`.
