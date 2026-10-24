# Two Language Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. (Native execution is this project's standing preference — do not use subagent-driven development.)

**Goal:** Settings gains two independent pickers — *App language* and *Voice language* — and the whole app speaks English or Spanish accordingly.

**Architecture:** A pure `LanguageSettings` type owns both stored identifiers and the rule that voice defaults to the app language. The app language is applied through the `AppleLanguages` override, which resolves at launch, so changing it prompts a relaunch; the voice language is just an identifier handed to `SpeechCapture` and `SpokenReply`, so it switches live. Model-layer copy that currently returns built-up `String` becomes `LocalizedStringResource` with real plural variants. `SWIFT_EMIT_LOC_STRINGS` is already `YES` in both configurations, so `Text("…")` literals extract into the catalog at build time; the work is the copy the compiler cannot see.

**Tech Stack:** SwiftUI, SwiftData, String Catalog (`Localizable.xcstrings`), `LocalizedStringResource`, `AVSpeechSynthesisVoice`, `SFSpeechRecognizer`, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md` (Constraints, plus the Feature 4 section)

## Global Constraints

- iOS 26 deployment target, Swift 5 language mode, SwiftUI + SwiftData.
- SwiftData syncs via CloudKit: **every new persisted property needs a default value and every new relationship must be optional.** This plan adds no `@Model` type and no persisted property — settings live in `UserDefaults`. Keep it that way.
- No `Color` literals in views; all colors from `Theme`. **No new colorsets** (one must be registered in `Theme.colorAssetNames` or `ThemeTests` fails).
- Type from `DuoFont` / `.duoLabel()`; cards `.duoCard()`; buttons `.buttonStyle(.duo(palette))`. No gradients, shadows, blur or glass.
- New or deleted Swift files must be registered: `ruby scripts/xcodeproj.rb add iScore <path>` / `add iScoreTests <path>`.
- Logic lives in pure, testable types in `iScore/Model/`; views stay thin.
- **English and Spanish ship first.** Spanish must use real Dominican/Puerto Rican domino vocabulary, not generic translation, and **the app's owner reviews it before it ships** — collect the domino-specific terms into one short list so they can be checked as a set.
- **Player names are never translated.** Numbers and dates use the app language's locale formatting.
- Test command: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` — the OS must be pinned; the bare name is ambiguous on this machine and xcodebuild falls through to macOS.
- Known noise: the simulator logs many CloudKit errors because there is no iCloud account. Judge a run by `✔ Test run with N tests … passed` and `** TEST SUCCEEDED **`.
- Baseline before Task 1: **300 tests in 38 suites** passing on `ffd15d1`.

## Review Focus

Input classes the spec implies that the happy path will not exercise. Each has its test pinned to the task that owns the code.

1. **A device language the app does not ship** (a French or Portuguese phone). Expected: English, with every screen filled — never empty strings or raw keys. → Task 1.
2. **Plural boundaries, in both languages**: 0 rounds, 1 round, 2 rounds, and the Spanish forms, which do not map one-to-one onto English's. → Task 3.
3. **A player name that looks like formatting** — containing `%@`, `%d`, or a leading `%`. Expected: shown literally, never interpreted as a format specifier and never crashing the formatter. → Task 4.
4. **A voice language with no installed `AVSpeechSynthesisVoice`.** Expected: the app still recognizes speech and still scores; it just does not speak back, and says so once rather than failing silently. → Task 6.
5. **The Lock Screen Live Activity while the app language changes.** The widget is a separate process with its own bundle, so its strings do not follow the app's `AppleLanguages` override automatically. Expected: the activity shows the chosen language after the relaunch, not stale English. → Task 7.

---

### Task 1: `LanguageSettings`

**Files:**
- Create: `iScore/Model/LanguageSettings.swift`
- Create: `iScoreTests/LanguageSettingsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:

```swift
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    var id: String { rawValue }
    /// The language's own name, in that language: "English", "Español".
    var endonym: String { get }
    /// The best match for a device locale, falling back to English.
    static func matching(_ locale: Locale) -> AppLanguage
}

enum LanguageSettings {
    static let appKey = "appLanguage"
    static let voiceKey = "voiceLanguage"
    static func app(from defaults: UserDefaults = .standard) -> AppLanguage
    /// Falls back to the app language when unset — the spec's "defaults to the
    /// app language on first run".
    static func voice(from defaults: UserDefaults = .standard) -> AppLanguage
    /// The `Locale` to hand `SFSpeechRecognizer` and `AVSpeechSynthesisVoice`.
    static func voiceLocale(from defaults: UserDefaults = .standard) -> Locale
}
```

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct AppLanguageTests {

    @Test func matchesSupportedLanguages() {
        #expect(AppLanguage.matching(Locale(identifier: "en_US")) == .english)
        #expect(AppLanguage.matching(Locale(identifier: "es_DO")) == .spanish)
        #expect(AppLanguage.matching(Locale(identifier: "es")) == .spanish)
    }

    /// Review Focus 1 — a language we do not ship falls back to English.
    @Test func fallsBackToEnglish() {
        #expect(AppLanguage.matching(Locale(identifier: "fr_FR")) == .english)
        #expect(AppLanguage.matching(Locale(identifier: "pt_BR")) == .english)
        #expect(AppLanguage.matching(Locale(identifier: "")) == .english)
    }

    @Test func namesItselfInItsOwnLanguage() {
        #expect(AppLanguage.english.endonym == "English")
        #expect(AppLanguage.spanish.endonym == "Español")
    }
}

struct LanguageSettingsTests {

    private func emptyDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func voiceFollowsAppWhenUnset() {
        let defaults = emptyDefaults("LanguageSettingsTests.unset")
        defaults.set("es", forKey: LanguageSettings.appKey)
        #expect(LanguageSettings.voice(from: defaults) == .spanish)
        #expect(LanguageSettings.voiceLocale(from: defaults).identifier.hasPrefix("es"))
    }

    @Test func voiceIsIndependentOnceSet() {
        let defaults = emptyDefaults("LanguageSettingsTests.split")
        defaults.set("en", forKey: LanguageSettings.appKey)
        defaults.set("es", forKey: LanguageSettings.voiceKey)
        #expect(LanguageSettings.app(from: defaults) == .english)
        #expect(LanguageSettings.voice(from: defaults) == .spanish)
    }

    @Test func anUnknownStoredValueFallsBackRatherThanCrashing() {
        let defaults = emptyDefaults("LanguageSettingsTests.junk")
        defaults.set("klingon", forKey: LanguageSettings.appKey)
        #expect(LanguageSettings.app(from: defaults) == .english)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/AppLanguageTests -only-testing:iScoreTests/LanguageSettingsTests`
Expected: FAIL — `cannot find 'AppLanguage' in scope`.

- [ ] **Step 3: Implement in `iScore/Model/LanguageSettings.swift`**

`matching` reads the locale's language code and maps it; everything unrecognized is `.english`. `app(from:)` with nothing stored falls back to `matching(.current)`, so a fresh Spanish phone opens in Spanish. Register both files with `scripts/xcodeproj.rb`.

- [ ] **Step 4: Run to verify they pass, then the full suite**

- [ ] **Step 5: Commit** — `feat: store the app and voice languages`

---

### Task 2: Localize the scoreboard copy

**Files:**
- Modify: `iScore/Model/Game+Scoreboard.swift` (`statusLabel`, `headline`, `progressLabel`, `feedbackDetail`, `projectionSummary`)
- Modify: `iScore/Model/Game.swift` (`Team.description`)
- Modify: `iScoreTests/GameScoreboardTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: the same property names, retyped from `String` to `LocalizedStringResource` where they are shown to the user. `displayName(for:)` stays `String` — it is player names, which are never translated.

- [ ] **Step 1: Retype the copy and update its tests**

Each of these becomes `LocalizedStringResource` built from a catalog key with interpolation, not Swift string concatenation. The existing tests assert against `String`; they become assertions against `String(localized:)` of the resource so they still pin the English wording exactly as they do today. Do not change any wording in this task — a reviewer must be able to see that only the type changed.

- [ ] **Step 2: Run the scoreboard suite**

Run: `… -only-testing:iScoreTests/GameScoreboardTests`
Expected: PASS, with the same English strings as before.

- [ ] **Step 3: Run the full suite** — the headline and status label appear in several views; a type change that breaks a call site must surface here.

- [ ] **Step 4: Commit** — `refactor: make the scoreboard copy localizable`

---

### Task 3: Plurals

**Files:**
- Modify: `iScore/Model/GameList.swift` (`countLabel`, the in-progress summary)
- Modify: `iScore/Model/Leaderboard.swift` (`PlayerRecord.summary`, `winsLabel`)
- Modify: `iScore/Model/GameSetup.swift` (`PlayerLineup.hint`)
- Modify: `iScore/Localizable.xcstrings` (plural variants)
- Modify: `iScoreTests/GameListTests.swift`, `iScoreTests/LeaderboardTests.swift`, `iScoreTests/GameSetupTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: the same names, returning `LocalizedStringResource`.

These are the strings the spec singles out: `"1 round"` / `"5 rounds"`, `"1 win"` / `"9 wins"`, `"Add 1 more player to start"` / `"Add 4 more players to start"`. Hand-built singular/plural branching must go; each gets a catalog entry with proper plural variants so Spanish can differ.

- [ ] **Step 1: Write the failing tests**

Extend the three existing suites with the boundaries, in both languages. Spanish assertions use `String(localized:locale: Locale(identifier: "es"))`:

```swift
/// Review Focus 2 — plural boundaries in both languages.
@Test func countLabelPluralizes() {
    #expect(String(localized: GameList.countLabel(0)) == "No games")
    #expect(String(localized: GameList.countLabel(1)) == "1 game")
    #expect(String(localized: GameList.countLabel(5)) == "5 games")
}

@Test func countLabelPluralizesInSpanish() {
    let es = Locale(identifier: "es")
    #expect(String(localized: GameList.countLabel(1), locale: es) == "1 partida")
    #expect(String(localized: GameList.countLabel(5), locale: es) == "5 partidas")
}
```

Mirror this for `winsLabel` (0/1/9) and `PlayerLineup.hint` (0/1/4 missing seats).

- [ ] **Step 2: Run to verify they fail**

- [ ] **Step 3: Add the plural variants to the catalog and retype the three call sites**

Use the catalog's plural variants, not `if count == 1`. The Spanish copy here is provisional — Task 8 is where the owner reviews it.

- [ ] **Step 4: Run the three suites, then the full suite**

- [ ] **Step 5: Commit** — `feat: pluralize counts through the catalog`

---

### Task 4: Audit the remaining literals

**Files:**
- Modify: any file under `iScore/` still holding user-visible copy the compiler cannot extract
- Modify: `iScoreTests/` as call sites require

**Interfaces:**
- Consumes: Tasks 2 and 3.
- Produces: nothing new.

`SWIFT_EMIT_LOC_STRINGS = YES` means `Text("Start game")` and `Button("Cancel")` already extract. What does **not** extract is copy assembled into a `String` before it reaches a view, accessibility labels built by interpolation, and anything handed to `AVSpeechSynthesisUtterance`. Sweep for those.

- [ ] **Step 1: Find them**

Run: `grep -rn 'String(format:\|" + \|\\(.*)" ' iScore/ --include=*.swift` and read `SpokenReply.swift`, `VoiceSetup`, `VoiceScoring` — the spoken copy is user-visible by ear and must localize too.

- [ ] **Step 2: Write the failing test for the name-safety case**

```swift
/// Review Focus 3 — a player name containing format specifiers is shown
/// literally, never interpreted and never crashing the formatter.
@Test func aPlayerNameThatLooksLikeAFormatSpecifierIsSafe() {
    let game = Game(gameType: .nine, maxScore: 200)
    game.team1 = ["%@ %d", "Ana"]
    game.team2 = ["Luis", "Papo"]
    #expect(game.displayName(for: .team1) == "%@ %d & Ana")
    #expect(String(localized: game.headline).contains("%@ %d") || game.rounds.isEmpty)
}
```

- [ ] **Step 3: Convert what the sweep found, and make names safe**

Player names must be interpolated as data, never used as a format string.

- [ ] **Step 4: Run the full suite**

- [ ] **Step 5: Commit** — `refactor: localize the copy the compiler cannot see`

---

### Task 5: The Language section in Settings

**Files:**
- Modify: `iScore/Views/SettingsView.swift`
- Create: `iScore/Model/LanguageRelaunch.swift`
- Create: `iScoreTests/LanguageRelaunchTests.swift`

**Interfaces:**
- Consumes: `AppLanguage`, `LanguageSettings` (Task 1).
- Produces: `enum LanguageRelaunch { static func needsRelaunch(changing from: AppLanguage, to: AppLanguage) -> Bool; static func apply(_ language: AppLanguage, to defaults: UserDefaults) }` — `apply` writes the `AppleLanguages` override.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func onlyAnActualChangeNeedsARelaunch() {
    #expect(!LanguageRelaunch.needsRelaunch(changing: .english, to: .english))
    #expect(LanguageRelaunch.needsRelaunch(changing: .english, to: .spanish))
}

@Test func applyWritesTheLanguageOverride() {
    let defaults = UserDefaults(suiteName: "LanguageRelaunchTests")!
    defaults.removePersistentDomain(forName: "LanguageRelaunchTests")
    LanguageRelaunch.apply(.spanish, to: defaults)
    #expect(defaults.stringArray(forKey: "AppleLanguages")?.first == "es")
}
```

- [ ] **Step 2: Run to verify they fail**

- [ ] **Step 3: Implement `LanguageRelaunch`**

- [ ] **Step 4: Build the Settings section**

A "Language" section above About, in the existing `.duoCard` row style, with two pickers matching the "That's me" row exactly: *App language* and *Voice language*, each listing `AppLanguage.allCases` by `endonym`. Changing the app language shows a confirmation explaining plainly that the app must restart, and offers to do it; changing the voice language takes effect immediately with no prompt. Both rows carry accessibility labels.

- [ ] **Step 5: Verify by eye**

Run with `-demoData`, open Settings, switch each picker. Confirm the app-language change prompts and the voice-language change does not. Screenshot both.

- [ ] **Step 6: Run the full suite, then commit** — `feat: pick the app and voice languages in Settings`

---

### Task 6: Wire the voice language

**Files:**
- Modify: `iScore/Views/VoiceGameSheet.swift:344,376` (`.current` → the stored voice locale)
- Modify: `iScore/Views/VoiceScoreBar.swift:128` (the `locale` default)
- Modify: `iScore/Model/SpokenReply.swift` (voice selection and the no-voice case)
- Modify: `iScoreTests/SpokenReplyTests.swift`

**Interfaces:**
- Consumes: `LanguageSettings.voiceLocale(from:)` (Task 1).
- Produces: `SpokenReply.voice(for:)` keeps its signature; add `static func canSpeak(_ locale: Locale) -> Bool`.

- [ ] **Step 1: Write the failing test**

```swift
/// Review Focus 4 — a voice language with no installed voice must not break
/// recognition or scoring; it only means the app does not speak back.
@Test func reportsWhenItCannotSpeakALanguage() {
    #expect(SpokenReply.canSpeak(Locale(identifier: "en_US")))
    #expect(!SpokenReply.canSpeak(Locale(identifier: "zz_ZZ")))
    #expect(SpokenReply.voice(for: Locale(identifier: "zz_ZZ")) == nil)
}
```

- [ ] **Step 2: Run to verify it fails**

- [ ] **Step 3: Implement, and replace the three `.current` sites**

When `canSpeak` is false the app still listens and still scores; it just does not speak, and Settings says so beside the voice picker rather than failing silently mid-game.

- [ ] **Step 4: Run the full suite, then commit** — `feat: listen and speak in the chosen voice language`

---

### Task 7: The widget's strings

**Files:**
- Modify: `iScore.xcodeproj/project.pbxproj` (catalog membership for the widget target)
- Modify: the widget's view files under `iScore/` as the sweep requires

**Interfaces:**
- Consumes: the catalog.
- Produces: nothing new.

The Lock Screen activity runs in a separate process with its own bundle, so it does not inherit the app's `AppleLanguages` override automatically.

- [ ] **Step 1: Establish what the widget actually shows**

List the widget's user-visible strings. If it shows only numbers and player names, say so in the commit message and this task is a no-op beyond the check — that is a legitimate outcome, not a skipped task.

- [ ] **Step 2: Add `Localizable.xcstrings` to the widget target's Resources, and make the widget read the override**

- [ ] **Step 3: Verify by eye**

Start a game, switch to Spanish, relaunch, and look at the Lock Screen activity. Screenshot it. If the simulator cannot show the activity, say so plainly rather than reporting a build as a check.

- [ ] **Step 4: Run the full suite, then commit** — `feat: localize the Lock Screen activity`

---

### Task 8: Spanish

**Files:**
- Modify: `iScore/Localizable.xcstrings`
- Create: `docs/spanish-domino-terms.md`

**Interfaces:**
- Consumes: every key the previous tasks created.
- Produces: the reviewable term list.

- [ ] **Step 1: Translate every key**

Dominican and Puerto Rican table vocabulary, not generic translation. Numbers and dates come from the locale's own formatting, not hand-written.

- [ ] **Step 2: Write `docs/spanish-domino-terms.md`**

Only the domino-specific terms, one per line: the English, the Spanish chosen, and one line on why — so the owner can check them as a set rather than hunting the catalog. This is the artifact the spec asks for.

- [ ] **Step 3: Verify by eye**

Switch to Spanish, relaunch, and walk Home → New Game → Game → Add Score → Summary → Hall of Fame → Settings. Screenshot each. **Any English left on screen is a bug in this task.**

- [ ] **Step 4: Run the full suite, then commit** — `feat: Spanish throughout`

---

### Task 9: The no-bare-literals lint

**Files:**
- Create: `scripts/lint-strings.rb`
- Modify: `iScore.xcodeproj/project.pbxproj` (a build phase)

**Interfaces:**
- Consumes: nothing.
- Produces: a script that exits non-zero on a user-visible literal outside the catalog.

The spec calls for a build-phase script rather than a test, because `iScoreTests` has no source-scanning precedent and a test reading the project source root breaks on CI.

- [ ] **Step 1: Write the script**

Scan `iScore/**/*.swift` for user-visible literals that will not reach the catalog. It must be quiet on the tree as it stands after Task 8 — if it is not, either the finding is real and gets fixed, or the rule is too blunt and gets narrowed. An allowlist is acceptable where it carries a reason per entry.

- [ ] **Step 2: Prove it catches a regression**

Add a bare literal to a view, run the script, confirm non-zero and that it names the file and line. Remove it.

- [ ] **Step 3: Add the build phase, run a clean build, then commit** — `build: fail the build on un-localized copy`
