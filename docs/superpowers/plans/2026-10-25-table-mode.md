# Table Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A layout for the phone lying face-up in the middle of the table. The scores are big enough to read from any seat, the screen stays awake, team 2's half is turned to face the other side, and tapping a half opens that team's keypad.

**Architecture:** One owner decides whether the screen may sleep: `ScreenAwake`, a pure set of reasons applied to `UIApplication`. Spectating and sharing already flip the idle timer independently, and table mode would be a third. Without a single owner, leaving one mode would put the screen to sleep while another still needs it awake. Table mode is a `TableModeView` that `GameView` swaps in. Its only state is an app-level session flag seeded from a Settings default, and everything it shows comes from `Game` and from small pure helpers.

**Tech Stack:** SwiftUI, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md`, section 7 ("Table mode").

**Branch:** `worktree-table-mode`, from `main` @ 3e3e267.

## Global Constraints

- **While table mode is active:** `.persistentSystemOverlays(.hidden)` and the screen kept awake (spec).
- **New font:** `DuoFont.tableScore` is a new font. `DuoFont.score` and the existing screens stay untouched (spec).
- **Team 2 faces the other side:** its half is rotated 180° so each side reads its own score right way up (spec).
- **Tap a half, get the keypad:** one large tap target per team opens that team's keypad, the existing `AddGameScoreView` sheet, directly (spec).
- **Duo only:** same colors, card shape and borders, just bigger. No gradients, shadows, blur or glass.
- **Leaving table mode restores the normal Game screen exactly** (spec done-line). Table mode is a conditional branch in `GameView`, not a modified copy of its layout.
- **Copy:** every user-visible line is `LocalizedStringResource`, with Spanish. `ruby scripts/lint-strings.rb` stays clean.
- **Project file:** new files go through `ruby scripts/xcodeproj.rb add <target> <path>`.
- **Tests:** `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`, after `xcrun simctl terminate booted SwiftDomainUI.iScore`.

## Review Focus

1. **Two reasons to stay awake at once.** Table mode is on while the game is being shared. Leaving table mode must not let the screen sleep while sharing still needs it awake, and the reverse. The same goes for a guest who is watching. → Task 1.
2. **A phone lying flat flips to landscape.** iOS keeps whatever orientation it last had. In landscape the two halves sit side by side, and team 2's half is still turned 180°. → Tasks 2 and 3.
3. **Three- and four-digit scores** (200, 1000) fit their half without truncation at every device size. → Task 2 (size function), Task 3 (eye check).
4. **The game ends in table mode.** The summary sheet still appears. The next game of the night opens in table mode too, because the session flag holds. → Task 3.
5. **VoiceOver on a rotated half.** Each half is one button whose label reads the team, the score and the points to win, in order. → Task 2 (label), Task 3.

---

### Task 1: One owner for keeping the screen awake

**Files:**
- Create: `iScore/Model/ScreenAwake.swift`
- Modify: `iScore/iScoreApp.swift` (the sharing host's `keepsAwake` goes through `ScreenAwake`), `iScore/Views/SpectateView.swift` (replace its own save-and-restore of `isIdleTimerDisabled`)
- Test: `iScoreTests/ScreenAwakeTests.swift`

**Interfaces:**
- Produces:
  - `enum AwakeReason: Hashable { case sharing, watching, tableMode }`
  - `@MainActor final class ScreenAwake`, with:
    - `static let shared`
    - `init(apply: @escaping (Bool) -> Void)`
    - `func set(_ reason: AwakeReason, _ on: Bool)`
    - `private(set) var reasons: Set<AwakeReason>`
    - `var keepsAwake: Bool { !reasons.isEmpty }`
  - `apply` is called with the new value only when `keepsAwake` changes. `shared` applies to `UIApplication.shared.isIdleTimerDisabled`.

- [ ] **Step 1: Write the failing tests**, each using an injected `apply` that records its calls:
  - Setting one reason keeps the screen awake.
  - With two reasons set, releasing one still keeps it awake (Review Focus 1).
  - Releasing the last reason lets it sleep.
  - Setting the same reason twice calls `apply` once.
  - Releasing a reason that was never set calls nothing.
- [ ] **Step 2: Run them.** Expected: compile failure.
- [ ] **Step 3: Implement.** Migrate the two existing owners:
  - `iScoreApp`'s `.onChange(of: spectateHost.keepsAwake)` calls `ScreenAwake.shared.set(.sharing, awake)`.
  - `SpectateView` calls `set(.watching, true)` in `.task` and `set(.watching, false)` in `.onDisappear`, and drops `wasIdleTimerDisabled`.
  - Update the CLAUDE.md "Live spectate" bullet on staying awake.
- [ ] **Step 4: Run the suite.** Expected: PASS.
- [ ] **Step 5: Commit** `refactor: one owner decides whether the screen may sleep`.

---

### Task 2: Table mode's pure parts

**Files:**
- Modify: `iScore/Model/Theme.swift` (`DuoFont`)
- Create: `iScore/Model/TableMode.swift`
- Test: `iScoreTests/TableModeTests.swift`

**Interfaces:**
- Produces:
  - `DuoFont.tableScoreSize(forHalf size: CGSize, digits: Int) -> CGFloat`: the largest size at which `digits` digits fit the half's width (glyph width ≈ 0.62 × size), capped at 70% of its height and at 280 points.
  - `DuoFont.tableScore(_ size: CGFloat) -> Font`: `.system(size:weight: .black, design: .rounded)` with monospaced digits. This is a new font; `score(_:)` is unchanged.
  - `enum TableLayout { static func isSideBySide(_ size: CGSize) -> Bool }`: true when the width is greater than the height.
  - `enum TableModeSettings { static let defaultKey = "tableModeByDefault" }`
  - `@Observable final class TableModeSession { var isOn: Bool; init(defaults: UserDefaults = .standard) }`: seeded from the default. The app owns one.
  - `Game.tableCardLabel(for team: Team) -> LocalizedStringResource`: "Ana & Luis, 105, 95 to win". At the target it reads "Ana & Luis, 200, won". Spanish: "%@, %lld, faltan %lld" and "%@, %lld, ganaron".

- [ ] **Step 1: Write the failing tests:**
  - `tableScoreSize` for a 400×380 half and 3 digits is at most 280, at most 0.7 × 380, and `3 × 0.62 × size ≤ 400`.
  - 4 digits gives a smaller size than 3. A 1000-point game never overflows (Review Focus 3).
  - A tiny half never returns a negative size.
  - `isSideBySide` is true for 900×400 and false for 400×900 (Review Focus 2).
  - `TableModeSession` seeds `true` when the default is set, and `false` with empty defaults.
  - `tableCardLabel` in English and Spanish, both for a team still playing and for a team at the target (Review Focus 5).
- [ ] **Step 2: Run them.** Expected: compile failure.
- [ ] **Step 3: Implement.** Register the new files, and add the catalog entries with Spanish.
- [ ] **Step 4: Run them, then the suite.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: table mode's sizes, layout rule and labels`.

---

### Task 3: The table layout, the toggle and the Settings default

**Files:**
- Create: `iScore/Views/TableModeView.swift`
- Modify: `iScore/iScoreApp.swift` (own a `TableModeSession` and inject it), `iScore/Views/GameView.swift`, `iScore/Views/SettingsView.swift`, `CLAUDE.md`

What to build:
- **`TableModeView(game:onAdd:onUndo:onExit:)`:**
  - It splits the screen into two halves with a thin center strip between them, stacked vertically in portrait and side by side when `TableLayout.isSideBySide`.
  - Team 1's half is right way up and team 2's is `.rotationEffect(.degrees(180))`.
  - Each half is one `Button` styled as a Duo card in that team's palette. It shows the team name in `DuoFont.title`, the total in `DuoFont.tableScore(tableScoreSize(...))`, measured with a `GeometryReader`, and the points to win as `.duoLabel()`.
  - Each half's VoiceOver label is `tableCardLabel` and its hint is "Add points" / "Agregar puntos".
  - The center strip has the status line (`game.statusLabel`), an Undo button with the same confirmation `GameView` uses, and "Exit table mode".
- **`GameView` toggle:**
  - The toolbar's "…" menu gets a "Table mode" item (`rectangle.split.1x2`) that turns `TableModeSession.isOn` on.
  - When it is on, `GameView`'s body shows `TableModeView` in place of its scroll view and bottom bar. It hides the navigation bar and applies `.persistentSystemOverlays(.hidden)`.
  - It calls `ScreenAwake.shared.set(.tableMode, isOn && isPlaying)` on change and on appear, and `false` on disappear.
  - `onAdd` sets the existing `team` state, which opens the existing keypad sheet, and `onExit` turns the flag off.
  - Every sheet and alert stays attached to `GameView`, so the keypad, the summary and the undo confirmation all work in table mode.
- **Settings:** a "Table mode" section with a toggle, "Start games in table mode", bound to `TableModeSettings.defaultKey`.
- **CLAUDE.md:** a "Table mode" section covering `ScreenAwake` as the only idle-timer owner, the session flag, the new font, the rotated half, and "leaving restores the normal screen" being a property of the conditional branch.
- **Spanish:**

  | English | Spanish |
  |---|---|
  | Table mode | Modo mesa |
  | Exit table mode | Salir del modo mesa |
  | Start games in table mode | Empezar partidas en modo mesa |
  | The phone lies flat between the players: big scores, screen stays on. | El teléfono queda en la mesa: marcadores grandes y la pantalla encendida. |

This task is views over Task 1 and Task 2's tested pieces, so it adds no unit test (one written here would pass before the code exists). Its gate is the suite, the lint and the eye check.

- [ ] **Step 1: Implement** the view, the toggle, the session, the Settings section, CLAUDE.md and the catalog entries.
- [ ] **Step 2: Run the suite and the lint.** Expected: PASS.
- [ ] **Step 3: Check by eye** with `-demoData`:
  - Turning table mode on shows two halves, with team 2 upside down.
  - A screenshot read at phone size from "above" (scaled to 25%) still shows both scores clearly.
  - Tapping a half opens that team's keypad, and the score updates.
  - Undo asks first.
  - Exit returns the normal screen unchanged; compare against a screenshot taken before.
  - Rotate the simulator to landscape: the halves sit side by side.
  - Finish a game: the summary appears.
- [ ] **Step 4: Commit** `feat: table mode for the phone in the middle of the table`.

## Not verifiable here (real-device list for the owner)

- The screen does not dim during a real game while table mode is on.
- Readability from about three feet above a real phone (spec done-line).
- How iOS orients a phone lying flat on a real table.
