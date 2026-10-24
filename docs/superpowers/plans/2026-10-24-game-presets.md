# Game Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Save a named game setup (for example "Friday night": Double-9, 200, the usual four) and start it with one tap from Home or one phrase by voice.

**Architecture:** A new `GamePreset` SwiftData model stores the setup. All logic runs on a plain value copy, `PresetSetup`, so the tests need no store: resolving it into a `ResolvedGame`, naming, ordering, and matching a spoken phrase. Starting a preset goes through the existing `GameFactory`. The voice path checks preset names first, inside `VoiceSetup.resolve`, before free-form parsing.

**Tech Stack:** SwiftUI, SwiftData (CloudKit-synced), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md`, section 6 ("Game presets").

**Branch:** stacked on `worktree-live-spectate` (PR #8), because both edit `HomeView`. Rebase when #7 and #8 merge.

## Global Constraints

- **CloudKit:** every `GamePreset` property has a default, and there are no relationships. Players are stored as names, not `Player` references.
- **Fields:** `GamePreset` has `name`, `gameType`, `target`, four player names and a created date, as the spec lists them. It also has an optional `lastUsed: Date?`, which orders the Home row (my addition; optional, so CloudKit-safe).
- **Home row:** shows up to three presets. Full management lives in Settings.
- **Voice:** preset names are matched before free-form parsing (spec wording).
- **Valid presets only:** a preset needs a non-empty name and a complete lineup of four distinct players. Names are compared with `PlayerName.isSame`, which folds case and accents.
- **Copy:** every user-visible line is `LocalizedStringResource`, with Spanish in `iScore/Localizable.xcstrings`. `ruby scripts/lint-strings.rb` stays clean.
- **Theme:** Duo only (`Theme`, `DuoFont`, `.duoCard()`, `.buttonStyle(.duo(_:))`).
- **Project file:** new files go through `ruby scripts/xcodeproj.rb add <target> <path>`.
- **Tests:** `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`, after `xcrun simctl terminate booted SwiftDomainUI.iScore`.

## Review Focus

1. **A preset names a player who has since been deleted or renamed.** Starting it still makes a correct game. The name is reused when a player still matches; otherwise a new player is created. It never crashes and never makes an incomplete lineup. → Task 1.
2. **A preset whose name overlaps a free-form description** ("Ana", or "Double 9 night"). "Nine two hundred Ana Luis versus Rafa Mia" must **not** be read as the "Ana" preset. A preset matches only when the phrase is the name plus filler words. → Task 2.
3. **One preset name is a prefix of another** ("Friday", "Friday night"). "Start Friday night" picks the longer one. → Task 2.
4. **A stored target outside today's range** (synced from an older build, or edited elsewhere). It is clamped on start, never passed through. → Task 1.
5. **Spanish, and how the recognizer spells things:** "empieza el viernes" for a preset named "Viernes", "VIERNES" or "viérnes". Matching folds case and accents. → Task 2.

---

### Task 1: The model and its pure logic

**Files:**
- Create: `iScore/Model/GamePreset.swift`
- Modify: `iScore/iScoreApp.swift` (`Schema([Game.self, Player.self, GamePreset.self])`), `iScore/Views/Previewer.swift` (container types)
- Test: `iScoreTests/GamePresetTests.swift`

**Interfaces:**
- Produces:
  - `@Model final class GamePreset`, with:
    - `var name: String = ""`
    - `var gameType: GameType = GameType.nine`
    - `var target: Int = 200`
    - `var playerNames: [String] = ["", "", "", ""]`
    - `var created: Date = Date()`
    - `var lastUsed: Date? = nil`
    - `init(_ setup: PresetSetup)`
    - `var setup: PresetSetup`
  - `struct PresetSetup: Equatable, Sendable { var name: String; var gameType: GameType; var target: Int; var playerNames: [String] }`, with:
    - `init(name:gameType:target:playerNames:)`
    - `init(game: Game, name: String)`: team 1's names fill seats 0–1, team 2's fill seats 2–3.
    - `func resolved(known: [String]) -> ResolvedGame`: names are matched to `known` with `PlayerName.resolve`, then `PlayerName.limited`. The target is `gameType.clampedTarget(Double(target))`. `newNames` lists the names matching no known player.
    - `var isComplete: Bool`: four non-empty names, all distinct under `PlayerName.isSame`.
  - `enum PresetName`, with:
    - `static let maxLength = 24`
    - `static func cleaned(_ typed: String) -> String`: trims, then cuts to `maxLength`.
    - `static func isTaken(_ name: String, among existing: [String]) -> Bool`: compares folded, using `PlayerName.isSame`.
  - `enum PresetList { static func homeRow(_ presets: [GamePreset]) -> [GamePreset] }`: at most 3, ordered by `lastUsed ?? created`, newest first.

- [ ] **Step 1: Write the failing tests.** Each is one `@Test`:
  - `resolved` reuses the saved spelling: a preset holds "ana", the known players include "Ana", and the seat comes out "Ana".
  - A deleted player shows up in `newNames`, and the lineup stays complete (Review Focus 1).
  - A target of 990 for Double-9 resolves to 200, and 5 resolves to 10 (Review Focus 4).
  - `PresetSetup(game:name:)` seats names in team order.
  - `isComplete` is false with a blank seat, and false with "Ana" and "ana" both seated.
  - `cleaned` trims and cuts to 24.
  - `isTaken` ignores case and accents.
  - `homeRow` returns 3 out of 5, with recently used presets first.
  - `GamePreset(setup).setup == setup`, using an unattached model instance.
- [ ] **Step 2: Run them.** Expected: compile failure.
- [ ] **Step 3: Implement.** Add `GamePreset.self` to the app schema and to Previewer. Register the file with `add iScore`, and the test with `add iScoreTests`.
- [ ] **Step 4: Run them.** Expected: PASS. Then run the full suite. Expected: PASS, which shows the schema change still builds a container.
- [ ] **Step 5: Commit** `feat: game presets as a model with pure setup logic`.

---

### Task 2: Starting a preset by voice

**Files:**
- Create: `iScore/Model/PresetMatcher.swift`
- Modify: `iScore/Model/GameSetup.swift` (`VoiceSetup.resolve` gains `presets: [PresetSetup] = []`), `iScore/Views/VoiceGameSheet.swift` and its `voiceGameSheet(...)` helper (pass the presets in), plus the helper's call sites.
- Test: `iScoreTests/PresetMatcherTests.swift`

**Interfaces:**
- Consumes: `PresetSetup`.
- Produces:
  - `enum PresetMatcher { static func match(_ transcript: String, presets: [PresetSetup]) -> PresetSetup? }`
  - `VoiceSetup.resolve(_:locale:defaults:known:owner:presets:)`. When a preset matches, it returns `preset.resolved(known: known + owner)` and never calls the model.

Matching rule:
1. Fold the transcript and each name: lowercase, strip diacritics, turn punctuation into spaces, collapse whitespace.
2. Drop filler words from the transcript. English: `start, play, begin, lets, let's, new, game, the, a, preset, please, our, usual`. Spanish: `empieza, empezar, empecemos, comienza, juega, jugar, juguemos, nueva, partida, el, la, los, las, una, un, por, favor`.
3. A preset matches when what remains equals its folded name.
4. When several match, the longest name wins.

There is deliberately no substring match. That rule is what keeps a free-form description from being taken for a preset.

- [ ] **Step 1: Write the failing tests:**
  - "start Friday night" matches "Friday night".
  - "Friday night" on its own matches.
  - "let's play friday night please" matches.
  - With "Friday" and "Friday night" both saved, "start Friday night" picks "Friday night" and "start Friday" picks "Friday" (Review Focus 3).
  - "nine two hundred Ana Luis versus Rafa Mia" with a preset named "Ana" gives nil (Review Focus 2).
  - "empieza el viernes" matches "Viernes", and so do "VIERNES" and "viérnes" (Review Focus 5).
  - With no presets, the result is nil.
  - `VoiceSetup.resolve("start Friday night", …, presets: [friday])` returns that preset's type, target and lineup.
- [ ] **Step 2: Run them.** Expected: compile failure.
- [ ] **Step 3: Implement** the matcher and the `resolve` hook. `voiceGameSheet` gains a `presets: [GamePreset]` parameter. Each call site passes its `@Query` presets, sorted by name.
- [ ] **Step 4: Run them.** Expected: PASS. Then run the full suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat: start a preset by saying its name`.

---

### Task 3: The Home row

**Files:**
- Create: `iScore/Views/PresetRow.swift`
- Modify: `iScore/Views/HomeView.swift`

**Interfaces:**
- Consumes: `PresetList.homeRow`, `PresetSetup.resolved(known:)`, `GameFactory.make`.

What to build:
- **The row:** a horizontal row of up to three `.duoCard` buttons placed under the active-game banner, above the tiles. Each card shows the preset name in `DuoFont.body` and "Double 9 · 200" from `GameType.title` and the target, as `.duoLabel()`.
- **Hidden when empty:** the row is absent when there are no presets.
- **A tap starts the game:** it resolves against the saved players, calls `GameFactory.make`, sets `lastUsed = .now` and appends the game to `path`. This is the same navigation as the voice start.
- **Copy:** the row header is "Your presets" / "Tus partidas guardadas".

This task is wiring over Task 1's tested functions, so it adds no unit test (one written here would pass before the code exists).

- [ ] **Step 1: Implement** the row, and add the catalog entry with Spanish.
- [ ] **Step 2: Run the suite and the lint.** Expected: PASS.
- [ ] **Step 3: Check by eye** on the simulator with `-demoData`. Task 5 adds a demo preset, so this check is done after Task 5. One tap starts a game with the right type, target and four names.
- [ ] **Step 4: Commit** `feat: start a preset from Home in one tap`.

---

### Task 4: Managing presets in Settings

**Files:**
- Create: `iScore/Views/PresetEditorView.swift`
- Modify: `iScore/Views/SettingsView.swift` (add a "Presets" section)

What to build:
- **The section:** each preset is a row showing its name and setup, with a trash button. This mirrors the existing saved-player rows and their delete confirmation.
- **New preset:** a "New preset" button opens `PresetEditorView`. Tapping a row opens the same editor on that preset.
- **The editor:**
  - It is composed from the pieces New Game already uses: a name `TextField` (cleaned with `PresetName.cleaned`), `GameTypePicker`, `TargetStepper`, and two `TeamSeatsCard`s that open the `NewPlayerView` picker.
  - Save is enabled only when the name is non-empty, not taken by another preset (`PresetName.isTaken`, ignoring the preset being edited), and `PresetSetup.isComplete` is true.
  - A blocked Save shows its reason in one line: "Give it a name", "You already have a preset called %@", or "Pick all four players".
- **Copy and Spanish:**

  | English | Spanish |
  |---|---|
  | Presets | Partidas guardadas |
  | New preset | Nueva partida guardada |
  | Edit preset | Editar partida guardada |
  | Preset name | Nombre |
  | Save | Guardar |
  | Delete Preset | Borrar partida guardada |
  | Give it a name | Ponle un nombre |
  | You already have a preset called %@ | Ya tienes una partida guardada llamada %@ |
  | Pick all four players | Elige a los cuatro jugadores |

- [ ] **Step 1: Write the failing test.** `PresetEditorRules.blocker(name:setup:existing:editing:) -> LocalizedStringResource?` is a pure function in `GamePreset.swift`. Test that it returns nil when valid, and each blocker in order (name, then taken, then incomplete), in both languages. A name taken only by the preset being edited is not a blocker.
- [ ] **Step 2: Run it.** Expected: compile failure.
- [ ] **Step 3: Implement** `blocker`, the Settings section and the editor. Add the catalog entries.
- [ ] **Step 4: Run the suite and the lint.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: create, edit and delete presets in Settings`.

---

### Task 5: Saving a setup from a finished game, and docs

**Files:**
- Modify: `iScore/Views/GameSummaryView.swift`. Add a "Save this setup" button. It opens an alert with a name `TextField`. On Save it inserts `GamePreset(PresetSetup(game:name:))`. If a preset with the same type, target and four names already exists, the button is replaced by "Saved as %@".
- Modify: `iScore/Model/DemoData.swift`. Seed one preset, "Friday night", from the demo players, so Home shows the row with `-demoData`.
- Modify: `CLAUDE.md`. Add a "Game presets" section covering the value-type rule, voice matching before free-form, and Home showing three.

- [ ] **Step 1: Write the failing test.** `PresetList.existing(matching: PresetSetup, in: [GamePreset]) -> GamePreset?` matches on type, target and names (`PlayerName.isSame`, seat by seat), ignoring the name. Test a match, a different target, and a different seat order.
- [ ] **Step 2: Run it.** Expected: compile failure.
- [ ] **Step 3: Implement** the function, the summary button, the alert, the demo preset and the CLAUDE.md section. Catalog with Spanish: "Save this setup" / "Guardar esta partida", "Saved as %@" / "Guardada como %@", "Name this setup" / "Ponle nombre a esta partida".
- [ ] **Step 4: Run the suite and the lint.** Expected: PASS.
- [ ] **Step 5: Check by eye** with `-demoData`:
  - The Home row shows "Friday night", and one tap starts the right game.
  - Settings lists the preset; the editor's Save blocks on a duplicate name.
  - Finishing a game offers "Save this setup".
- [ ] **Step 6: Commit** `feat: save a finished game's setup as a preset`.

## Not verifiable here (real-device list for the owner)

- A preset surviving iCloud sync to a second device (the spec's done-line).
- "Start Friday night" spoken aloud, in English and in Spanish.
