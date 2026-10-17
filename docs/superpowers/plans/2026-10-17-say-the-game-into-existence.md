# Say the Game Into Existence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One spoken or typed sentence in any word order — *"nine, two hundred, me and Carlos against Luis and Papo"* — produces a filled-in, startable New Game confirmation card.

**Architecture:** Two layers behind one interface. A pure deterministic parser (`SpokenNumber` → `GameCommand.parse` → `GameCommand.resolved`) is the primary path and works on every device; a Foundation Models guided-generation call is layered on top and only runs when the deterministic layer leaves the command incomplete *and* the hardware supports it. Speech-to-text is an on-device `SFSpeechRecognizer` wrapper. The UI is one sheet that renders a `ResolvedGame` and hands it to the existing `NewGameView.startGame` logic.

**Tech Stack:** SwiftUI, SwiftData, Speech (`SFSpeechRecognizer`), FoundationModels (`SystemLanguageModel`, `@Generable`), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md` (Feature 1; the Constraints section applies in full)

**Branch:** work on a branch off `main`, not `main` itself. The repo has unrelated staged asset changes at plan time — leave them alone.

## Global Constraints

- iOS 26 deployment target, Swift 5 language mode, SwiftUI + SwiftData.
- SwiftData syncs via CloudKit (`cloudKitDatabase: .automatic`): **every new persisted property needs a default value and every new relationship must be optional.** This plan adds no new `@Model` types; keep it that way.
- No `Color` literals in views. Semantic colors come from `Theme` only. Any new colorset goes in `Assets.xcassets` **and** `Theme.colorAssetNames`, or `ThemeTests` fails.
- Type is `DuoFont` (`.score`, `.title`, `.body`, `.label`). Cards: radius 16, 2pt border, 4pt bottom edge (`.duoCard`). Buttons: radius 14, 4pt darker bottom edge (`.duo`). No gradients, shadows, blur, or glass.
- Every new or deleted Swift file must be registered: `ruby scripts/xcodeproj.rb add iScore <path>` (app) or `add iScoreTests <path>` (tests).
- Target ranges are real and enforced through `GameType.clampedTarget`: Double-6 is `10...100`, Double-9 is `10...200`, step 10.
- Player names cap at `PlayerName.maxLength` (15) and compare case-insensitively via `PlayerName.isSame`. Reuse existing spelling with `PlayerName.resolve`.
- Logic lives in `iScore/Model/` as pure types with Swift Testing coverage in `iScoreTests`. Views stay thin.
- Test command used throughout:
  `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:<suite-path>`

## Review Focus

Input classes the spec implies that no task's happy-path tests would otherwise exercise. Each has its test pinned to the task that owns the code.

1. **Empty or garbage transcript** (the mic heard room noise, or nothing). Expected: the card opens with saved defaults and four empty seats, never a crash and never a wrong game. → Task 3.
2. **Speech permission denied, restricted, or revoked mid-session.** Expected: the mic button explains itself once and the touch path stays fully usable; it never silently does nothing. → Task 5.
3. **The same name heard twice** (*"me and Carlos vs Carlos and Papo"*). Expected: the duplicate is seated once, the lineup reports incomplete, and `PlayerLineup.hint` explains why — no duplicate player is created. → Task 3.
4. **A recognizer name that is too long or carries punctuation** (*"Luis,"*, a 20-character run-on). Expected: trimmed and truncated through `PlayerName`, seated, not rejected. → Task 3.
5. **Foundation Models available but the call throws, times out, or returns nonsense.** Expected: the deterministic result is used, within the normal time budget, with no error dialog. → Task 6.

---

### Task 1: Spoken number parsing

**Files:**
- Create: `iScore/Model/SpokenNumber.swift`
- Create: `iScoreTests/SpokenNumberTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum SpokenNumber { static func parse(_ token: String, locale: Locale) -> Int?; static func scan(_ words: [String], locale: Locale) -> [(value: Int, range: Range<Int>)] }` — `scan` returns every number found in a word array with the word indices it consumed, so the caller can remove those words before looking for names.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct SpokenNumberTests {

    private let en = Locale(identifier: "en_US")
    private let es = Locale(identifier: "es_DO")

    @Test func parsesDigits() {
        #expect(SpokenNumber.parse("200", locale: en) == 200)
        #expect(SpokenNumber.parse("9", locale: es) == 9)
        #expect(SpokenNumber.parse("abc", locale: en) == nil)
        #expect(SpokenNumber.parse("", locale: en) == nil)
    }

    @Test func parsesEnglishWords() {
        #expect(SpokenNumber.parse("nine", locale: en) == 9)
        #expect(SpokenNumber.parse("twenty-five", locale: en) == 25)
    }

    @Test func parsesSpanishWords() {
        #expect(SpokenNumber.parse("nueve", locale: es) == 9)
        #expect(SpokenNumber.parse("veinticinco", locale: es) == 25)
        #expect(SpokenNumber.parse("doscientos", locale: es) == 200)
    }

    @Test func scansCompoundsAcrossWords() {
        let hits = SpokenNumber.scan(["two", "hundred"], locale: en)
        #expect(hits.count == 1)
        #expect(hits[0].value == 200)
        #expect(hits[0].range == 0..<2)
    }

    @Test func scansSpanishCompounds() {
        let hits = SpokenNumber.scan(["ciento", "cincuenta"], locale: es)
        #expect(hits.map(\.value) == [150])
    }

    @Test func scansSeveralNumbersWithWordsBetween() {
        let hits = SpokenNumber.scan(["nine", "to", "two", "hundred"], locale: en)
        #expect(hits.map(\.value) == [9, 200])
        #expect(hits.map(\.range) == [0..<1, 2..<4])
    }

    @Test func scanFindsNothingInPlainWords() {
        #expect(SpokenNumber.scan(["me", "and", "carlos"], locale: en).isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iScoreTests/SpokenNumberTests`
Expected: FAIL — `cannot find 'SpokenNumber' in scope`.

- [ ] **Step 3: Implement `SpokenNumber` in `iScore/Model/SpokenNumber.swift`**

Word tables for English and Spanish, selected by the locale's language code, defaulting to English for anything else. `scan` walks the word array greedily, taking the longest run that forms one number (so "two hundred" beats "two"), consuming hyphenated tokens as single words. Register the file with `ruby scripts/xcodeproj.rb add iScore iScore/Model/SpokenNumber.swift` and the test with `add iScoreTests iScoreTests/SpokenNumberTests.swift`.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add iScore/Model/SpokenNumber.swift iScoreTests/SpokenNumberTests.swift iScore.xcodeproj
git commit -m "feat: parse spoken numbers in English and Spanish"
```

---

### Task 2: Parse a transcript into a raw command

**Files:**
- Create: `iScore/Model/GameCommand.swift`
- Create: `iScoreTests/GameCommandTests.swift`

**Interfaces:**
- Consumes: `SpokenNumber.scan` (Task 1).
- Produces:

```swift
struct GameCommand: Equatable {
    var gameType: GameType?
    var target: Int?
    var team1: [String] = []
    var team2: [String] = []
    /// True when the sentence carried nothing usable, so Task 6 knows to try the model.
    var isEmpty: Bool { gameType == nil && target == nil && team1.isEmpty && team2.isEmpty }

    static func parse(_ transcript: String, locale: Locale) -> GameCommand
}
```

`parse` does **not** touch defaults, clamping, or the player list — that is Task 3. Names come out as heard, in order, split across the two teams by the separator word.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct GameCommandParseTests {

    private let en = Locale(identifier: "en_US")
    private let es = Locale(identifier: "es_DO")

    private func parse(_ text: String, _ locale: Locale? = nil) -> GameCommand {
        GameCommand.parse(text, locale: locale ?? en)
    }

    @Test func parsesTheCanonicalSentence() {
        let command = parse("nine, two hundred, me and Carlos against Luis and Papo")
        #expect(command.gameType == .nine)
        #expect(command.target == 200)
        #expect(command.team1 == ["me", "Carlos"])
        #expect(command.team2 == ["Luis", "Papo"])
    }

    @Test func wordOrderDoesNotMatter() {
        let a = parse("me and Carlos against Luis and Papo, two hundred, nine")
        let b = parse("two hundred nine me and Carlos vs Luis and Papo")
        #expect(a.gameType == .nine)
        #expect(a.target == 200)
        #expect(a.team1 == ["me", "Carlos"])
        #expect(a == b)
    }

    @Test func recognizesSeparators() {
        #expect(parse("Ana and Luis vs Papo and Tito").team2 == ["Papo", "Tito"])
        #expect(parse("Ana and Luis versus Papo and Tito").team2 == ["Papo", "Tito"])
        #expect(parse("Ana y Luis contra Papo y Tito", es).team2 == ["Papo", "Tito"])
    }

    @Test func numbersOutsideAnyTargetRangeAreDropped() {
        let command = parse("nine, five thousand, Ana and Luis vs Papo and Tito")
        #expect(command.gameType == .nine)
        #expect(command.target == nil)
    }

    @Test func sixAndNineAreGameTypesNotTargets() {
        #expect(parse("six, Ana and Luis vs Papo and Tito").gameType == .six)
        #expect(parse("six, Ana and Luis vs Papo and Tito").target == nil)
        #expect(parse("double six to one hundred").gameType == .six)
        #expect(parse("double six to one hundred").target == 100)
    }

    @Test func namesSurviveWithoutAGameTypeOrTarget() {
        let command = parse("Ana and Luis vs Papo and Tito")
        #expect(command.gameType == nil)
        #expect(command.target == nil)
        #expect(command.team1 == ["Ana", "Luis"])
    }

    @Test func noSeparatorPutsFirstTwoNamesOnTeamOne() {
        let command = parse("Ana, Luis, Papo, Tito")
        #expect(command.team1 == ["Ana", "Luis"])
        #expect(command.team2 == ["Papo", "Tito"])
    }

    @Test func emptyTranscriptIsEmpty() {
        #expect(parse("").isEmpty)
        #expect(parse("uh, hmm, okay so").isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/GameCommandParseTests`
Expected: FAIL — `cannot find 'GameCommand' in scope`.

- [ ] **Step 3: Implement `GameCommand.parse` in `iScore/Model/GameCommand.swift`**

Order of operations, since it is not determined by the signature: lowercase and split into words on whitespace and punctuation (keeping the original casing in a parallel array for name output) → `SpokenNumber.scan` → assign 6 and 9 to `gameType`, then the first remaining number inside that type's `targetRange` (or, with no type yet, inside the widest range `10...200`) to `target`, dropping the rest → remove consumed indices and all stop words (articles, "to", "and"/"y", "double"/"doble", the separators) → the words left are names, in order → split at the separator index if one was present, otherwise 2 and 2. Register both files with `scripts/xcodeproj.rb`.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add iScore/Model/GameCommand.swift iScoreTests/GameCommandTests.swift iScore.xcodeproj
git commit -m "feat: parse a spoken game description into a raw command"
```

---

### Task 3: Resolve a command into a startable game

**Files:**
- Modify: `iScore/Model/GameCommand.swift`
- Modify: `iScoreTests/GameCommandTests.swift`

**Interfaces:**
- Consumes: `GameCommand` (Task 2), `GameDefaults.load`, `GameType.clampedTarget`, `PlayerLineup`, `PlayerName` (all existing).
- Produces:

```swift
struct ResolvedGame: Equatable {
    let gameType: GameType
    let target: Int
    let lineup: PlayerLineup
    /// Heard names that match no existing player — shown as new on the card.
    let newNames: [String]
}

extension GameCommand {
    /// `known` is every saved player's name; `owner` is the device owner's
    /// player name, or nil when they are not a player.
    func resolved(defaults: (type: GameType, target: Int),
                  known: [String],
                  owner: String?) -> ResolvedGame
}
```

Resolution rules, all fixed by the spec: missing type and target come from `defaults`; the target is run through `clampedTarget` for the resolved type; `"me"` / `"yo"` becomes `owner` and is **dropped** when `owner` is nil; every other name goes through `PlayerName.resolve` against `known` so existing spelling wins; names are truncated with `PlayerName.limited`; a name already seated is not seated twice.

- [ ] **Step 1: Write the failing tests**

Append to `iScoreTests/GameCommandTests.swift`:

```swift
struct GameCommandResolveTests {

    private let defaults = (type: GameType.nine, target: 100)
    private let known = ["Ana", "Carlos", "Luis", "Papo"]

    private func resolve(_ text: String, owner: String? = "Ana", known: [String]? = nil) -> ResolvedGame {
        GameCommand.parse(text, locale: Locale(identifier: "en_US"))
            .resolved(defaults: defaults, known: known ?? self.known, owner: owner)
    }

    @Test func fillsTheCanonicalSentence() {
        let game = resolve("nine, two hundred, me and Carlos against Luis and Papo")
        #expect(game.gameType == .nine)
        #expect(game.target == 200)
        #expect(game.lineup.names == ["Ana", "Carlos", "Luis", "Papo"])
        #expect(game.lineup.isComplete)
        #expect(game.newNames.isEmpty)
    }

    @Test func missingFieldsComeFromDefaults() {
        let game = resolve("Ana and Luis vs Papo and Carlos")
        #expect(game.gameType == .nine)
        #expect(game.target == 100)
    }

    @Test func targetIsClampedToTheResolvedType() {
        #expect(resolve("six, one hundred fifty, Ana and Luis vs Papo and Carlos").target == 100)
        #expect(resolve("nine, one hundred four, Ana and Luis vs Papo and Carlos").target == 100)
    }

    @Test func existingSpellingWins() {
        let game = resolve("nine, ana and carlos vs luis and papo")
        #expect(game.lineup.names == ["Ana", "Carlos", "Luis", "Papo"])
        #expect(game.newNames.isEmpty)
    }

    @Test func unknownNamesAreMarkedNew() {
        let game = resolve("Ana and Carlos vs Tito and Papo")
        #expect(game.newNames == ["Tito"])
        #expect(game.lineup.isComplete)
    }

    /// Review Focus 1 — the mic heard nothing usable.
    @Test func emptyTranscriptGivesDefaultsAndEmptySeats() {
        let game = resolve("uh, hmm")
        #expect(game.gameType == .nine)
        #expect(game.target == 100)
        #expect(game.lineup.names == ["", "", "", ""])
        #expect(!game.lineup.isComplete)
        #expect(game.lineup.hint == "Add 4 more players to start")
    }

    /// Review Focus 3 — the same name heard twice.
    @Test func aRepeatedNameIsSeatedOnce() {
        let game = resolve("me and Carlos vs Carlos and Papo")
        #expect(game.lineup.names == ["Ana", "Carlos", "Papo", ""])
        #expect(!game.lineup.isComplete)
        #expect(game.lineup.hint == "Add 1 more player to start")
    }

    /// Review Focus 4 — recognizer output with punctuation and over-long names.
    @Test func namesAreTrimmedAndTruncated() {
        let game = resolve("Ana and Bartholomewlongname vs Luis and Papo",
                           known: ["Ana", "Luis", "Papo"])
        #expect(game.lineup.names[1] == "Bartholomewlong")
        #expect(game.lineup.names[1].count == PlayerName.maxLength)
        #expect(game.lineup.isComplete)
    }

    @Test func meIsDroppedWhenTheOwnerIsNotPlaying() {
        let game = resolve("me and Carlos vs Luis and Papo", owner: nil)
        #expect(game.lineup.names == ["Carlos", "Luis", "Papo", ""])
        #expect(!game.lineup.isComplete)
    }

    @Test func spanishMeResolvesToTheOwner() {
        let command = GameCommand.parse("yo y Carlos contra Luis y Papo", locale: Locale(identifier: "es_DO"))
        let game = command.resolved(defaults: defaults, known: known, owner: "Ana")
        #expect(game.lineup.names == ["Ana", "Carlos", "Luis", "Papo"])
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/GameCommandResolveTests`
Expected: FAIL — `cannot find 'ResolvedGame' in scope`.

- [ ] **Step 3: Implement `ResolvedGame` and `GameCommand.resolved` in `iScore/Model/GameCommand.swift`**

Seats fill in order — team 1's heard names into seats 0–1, team 2's into 2–3 — and when one team overflows while the other has room, the extra name takes the next free seat (that is what makes the repeated-name and dropped-`me` cases land as the tests expect).

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command, then the whole suite:
`xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS, with no existing test broken.

- [ ] **Step 5: Commit**

```bash
git add iScore/Model/GameCommand.swift iScoreTests/GameCommandTests.swift
git commit -m "feat: resolve a parsed command into a startable lineup"
```

---

### Task 4: Owner identity

**Files:**
- Modify: `iScore/Model/GameSetup.swift`
- Modify: `iScore/Views/SettingsView.swift`
- Modify: `iScoreTests/GameSetupTests.swift`

**Interfaces:**
- Consumes: `PlayerName.isSame` (existing).
- Produces: `enum OwnerIdentity { static let nameKey = "ownerPlayerName"; static func load(from: UserDefaults) -> String?; static func resolve(_ stored: String?, known: [String]) -> String? }` — `resolve` returns nil when the stored name no longer matches any saved player, so a deleted player cannot haunt "me".

- [ ] **Step 1: Write the failing tests**

Append to `iScoreTests/GameSetupTests.swift`:

```swift
struct OwnerIdentityTests {

    @Test func loadsNothingByDefault() {
        let defaults = UserDefaults(suiteName: "OwnerIdentityTests.empty")!
        defaults.removePersistentDomain(forName: "OwnerIdentityTests.empty")
        #expect(OwnerIdentity.load(from: defaults) == nil)
    }

    @Test func resolvesAgainstSavedPlayers() {
        #expect(OwnerIdentity.resolve("ana", known: ["Ana", "Luis"]) == "Ana")
        #expect(OwnerIdentity.resolve("Ana", known: ["Ana", "Luis"]) == "Ana")
    }

    @Test func forgetsADeletedPlayer() {
        #expect(OwnerIdentity.resolve("Tito", known: ["Ana", "Luis"]) == nil)
        #expect(OwnerIdentity.resolve(nil, known: ["Ana"]) == nil)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/OwnerIdentityTests`
Expected: FAIL — `cannot find 'OwnerIdentity' in scope`.

- [ ] **Step 3: Implement `OwnerIdentity` in `iScore/Model/GameSetup.swift`**

- [ ] **Step 4: Add the Settings row**

In `SettingsView`, a "That's me" row in the Players section: a picker over saved players with a "Nobody" option, bound to `@AppStorage(OwnerIdentity.nameKey)`. Follow the existing `AboutRow` / `SettingsPlayerRow` shape and the Duo card styling; no new colorsets.

- [ ] **Step 5: Run the whole suite**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add iScore/Model/GameSetup.swift iScore/Views/SettingsView.swift iScoreTests/GameSetupTests.swift
git commit -m "feat: let the user say which player is them"
```

---

### Task 5: On-device speech capture

**Files:**
- Create: `iScore/Model/SpeechCapture.swift`
- Create: `iScoreTests/SpeechCaptureTests.swift`
- Modify: `iScore.xcodeproj` (Info.plist keys)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:

```swift
enum SpeechAvailability: Equatable { case ready, needsPermission, denied, unsupported }

@MainActor @Observable
final class SpeechCapture {
    private(set) var transcript = ""
    private(set) var isListening = false
    private(set) var availability: SpeechAvailability = .needsPermission

    init(locale: Locale)
    func requestAccess() async
    func start() throws
    /// Stops the recognizer and returns the final transcript.
    func stop() -> String
}
```

Plus a pure, testable mapper used by both the class and the tests:
`extension SpeechAvailability { static func from(speech: SFSpeechRecognizerAuthorizationStatus, microphone: AVAudioApplication.recordPermission, recognizerAvailable: Bool) -> SpeechAvailability }`

- [ ] **Step 1: Write the failing tests**

```swift
import AVFoundation
import Foundation
import Speech
import Testing
@testable import iScore

struct SpeechAvailabilityTests {

    /// Review Focus 2 — every permission combination has a defined answer.
    @Test func mapsAuthorizationStates() {
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .granted, recognizerAvailable: true) == .ready)
        #expect(SpeechAvailability.from(speech: .notDetermined, microphone: .granted, recognizerAvailable: true) == .needsPermission)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .undetermined, recognizerAvailable: true) == .needsPermission)
        #expect(SpeechAvailability.from(speech: .denied, microphone: .granted, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .restricted, microphone: .granted, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .denied, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .granted, recognizerAvailable: false) == .unsupported)
    }

    @Test func deniedOutranksAMissingRecognizer() {
        #expect(SpeechAvailability.from(speech: .denied, microphone: .denied, recognizerAvailable: false) == .denied)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/SpeechAvailabilityTests`
Expected: FAIL — `cannot find 'SpeechAvailability' in scope`.

- [ ] **Step 3: Implement `SpeechCapture` and `SpeechAvailability` in `iScore/Model/SpeechCapture.swift`**

`SFSpeechAudioBufferRecognitionRequest` with `requiresOnDeviceRecognition = true` and `addsPunctuation = false`, fed from `AVAudioEngine`'s input node; the recognizer is built from the passed locale. `stop()` tears down the engine and the request and returns the last transcription. Nothing here is unit-tested beyond the mapper — the class is exercised by hand on device.

- [ ] **Step 4: Add the usage descriptions**

Add `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription` and `INFOPLIST_KEY_NSMicrophoneUsageDescription` to both build configurations in `iScore.xcodeproj/project.pbxproj`, alongside the existing `INFOPLIST_KEY_*` entries. Copy: *"iScore listens so you can set up a game and call out scores without touching your phone."*

- [ ] **Step 5: Verify it builds and the suite passes**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add iScore/Model/SpeechCapture.swift iScoreTests/SpeechCaptureTests.swift iScore.xcodeproj
git commit -m "feat: capture speech on-device for game setup"
```

---

### Task 6: Foundation Models enhancement layer

**Files:**
- Create: `iScore/Model/GameCommandModel.swift`
- Create: `iScoreTests/GameCommandModelTests.swift`

**Interfaces:**
- Consumes: `GameCommand`, `ResolvedGame` (Tasks 2–3).
- Produces:

```swift
/// Decides whether the model layer is worth running, and merges its answer.
enum GameCommandModel {
    /// True only when the deterministic command is missing names or a field
    /// the sentence clearly tried to express.
    static func needsModel(_ command: GameCommand) -> Bool

    /// Deterministic fields win; the model only fills what is still nil or empty.
    static func merged(deterministic: GameCommand, model: GameCommand) -> GameCommand

    /// Runs the model when available, else returns `deterministic` unchanged.
    /// Never throws and never exceeds `timeout`.
    static func enhance(_ deterministic: GameCommand,
                        transcript: String,
                        locale: Locale,
                        timeout: Duration) async -> GameCommand
}
```

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct GameCommandModelTests {

    @Test func skipsTheModelWhenTheSentenceIsComplete() {
        var command = GameCommand()
        command.gameType = .nine
        command.target = 200
        command.team1 = ["Ana", "Carlos"]
        command.team2 = ["Luis", "Papo"]
        #expect(!GameCommandModel.needsModel(command))
    }

    @Test func wantsTheModelWhenNamesAreMissing() {
        var command = GameCommand()
        command.gameType = .nine
        command.team1 = ["Ana"]
        #expect(GameCommandModel.needsModel(command))
        #expect(GameCommandModel.needsModel(GameCommand()))
    }

    @Test func deterministicFieldsAlwaysWin() {
        var deterministic = GameCommand()
        deterministic.gameType = .six
        deterministic.team1 = ["Ana", "Carlos"]

        var model = GameCommand()
        model.gameType = .nine
        model.target = 150
        model.team1 = ["Wrong", "Names"]
        model.team2 = ["Luis", "Papo"]

        let merged = GameCommandModel.merged(deterministic: deterministic, model: model)
        #expect(merged.gameType == .six)
        #expect(merged.team1 == ["Ana", "Carlos"])
        #expect(merged.target == 150)
        #expect(merged.team2 == ["Luis", "Papo"])
    }

    /// Review Focus 5 — no model, or a model that fails, must not change the answer.
    @Test func fallsBackToTheDeterministicCommand() async {
        var deterministic = GameCommand()
        deterministic.gameType = .nine
        deterministic.team1 = ["Ana"]

        let result = await GameCommandModel.enhance(
            deterministic,
            transcript: "nine, Ana and somebody",
            locale: Locale(identifier: "en_US"),
            timeout: .milliseconds(1)
        )
        #expect(result.gameType == .nine)
        #expect(result.team1.first == "Ana")
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `… -only-testing:iScoreTests/GameCommandModelTests`
Expected: FAIL — `cannot find 'GameCommandModel' in scope`.

- [ ] **Step 3: Implement `GameCommandModel` in `iScore/Model/GameCommandModel.swift`**

A `@Generable` struct mirroring `GameCommand`'s fields (game type as a `@Guide`-constrained string, target as an `Int?`, two name arrays) drives one `LanguageModelSession.respond(to:generating:)` call. Gate the whole thing on `SystemLanguageModel.default.availability == .available`; wrap the call in a task with the `timeout` and treat every throw, timeout, and unavailability as "return `deterministic`". The one-millisecond timeout in the test is what makes it pass on a machine that does have the model.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command.
Expected: PASS, on hardware with and without Apple Intelligence.

- [ ] **Step 5: Commit**

```bash
git add iScore/Model/GameCommandModel.swift iScoreTests/GameCommandModelTests.swift iScore.xcodeproj
git commit -m "feat: let on-device AI fill in sentences the parser cannot"
```

---

### Task 7: The confirmation card

**Files:**
- Create: `iScore/Views/VoiceGameSheet.swift`
- Create: `iScore/Localizable.xcstrings`
- Modify: `iScore/Views/NewGameView.swift`

**Interfaces:**
- Consumes: `SpeechCapture` (5), `GameCommand.parse` / `.resolved` (2–3), `GameCommandModel.enhance` (6), `OwnerIdentity` (4), existing `TeamSeatsCard`, `GameTypePicker`, `TargetStepper`, `SheetHeader`, `PlayerLineup`.
- Produces: `struct VoiceGameSheet: View { init(known: [String], owner: String?, onConfirm: (ResolvedGame) -> Void) }`.

- [ ] **Step 1: Add the String Catalog**

Create `iScore/Localizable.xcstrings` as an empty catalog and register it on the app target. Every string this task adds goes through it; the full extraction of the app's existing literals is Feature 4's job, not this one.

- [ ] **Step 2: Build the sheet**

Three states in one sheet, all inside the Duo system with no new colorsets:

- **Listening** — a large mic affordance, the live transcript as it comes in, and a Cancel. Tapping the mic again stops and parses.
- **Review** — the resolved game rendered with the *existing* `TeamSeatsCard`, `GameTypePicker`, and `TargetStepper`, so every field stays touch-editable exactly as on New Game. Names with no saved player carry a "new" chip. The primary button is `Button("Start game")` with `.buttonStyle(.duo(Theme.palette(for: .team1)))`, disabled on `!lineup.isComplete`, showing `lineup.hint` above it — matching `NewGameView`'s bottom inset.
- **Unavailable** — when `availability` is `.denied` or `.unsupported`, the sheet opens straight into Review with a one-line explanation and a text field for typing the sentence instead. **The sheet is never a dead end** (Review Focus 2).

The pipeline on stop: `GameCommand.parse` → `GameCommandModel.enhance` → `.resolved(defaults:known:owner:)` → Review.

- [ ] **Step 3: Wire it into New Game**

Add a mic button to `NewGameView`'s header that presents `VoiceGameSheet`. `onConfirm` writes the `ResolvedGame` into the existing `@State lineup`, `gameType`, and `target`, then calls the existing `startGame()`. **Do not duplicate `startGame`** — player creation and `Game` insertion stay where they are.

- [ ] **Step 4: Verify by hand on the simulator**

Run the app with `-demoData`, open New Game, tap the mic, and type the canonical sentence in the fallback field. Expected: four seats filled, type and target set, Start enabled.

- [ ] **Step 5: Run the whole suite**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS — `DuoViewTests` and `ThemeTests` included.

- [ ] **Step 6: Commit**

```bash
git add iScore/Views/VoiceGameSheet.swift iScore/Localizable.xcstrings iScore/Views/NewGameView.swift iScore.xcodeproj
git commit -m "feat: start a game from one spoken sentence"
```

---

### Task 8: Home and end-of-game entry points

**Files:**
- Modify: `iScore/Views/HomeView.swift`
- Modify: `iScore/Views/GameSummaryView.swift`

**Interfaces:**
- Consumes: `VoiceGameSheet` (Task 7).
- Produces: nothing new.

- [ ] **Step 1: Add the Home entry point**

A mic action on `HomeView` that presents `VoiceGameSheet` and, on confirm, creates the game and navigates straight to `GameView` — the same path New Game takes, without stopping on New Game.

- [ ] **Step 2: Add "Next game" to the summary**

On `GameSummaryView`, a "Next game" button presenting the same sheet. It seeds the sheet's defaults with **the finished game's** type and target rather than `GameDefaults`, so *"same but me and Luis"* keeps the night's settings unless the sentence overrides them.

- [ ] **Step 3: Verify by hand**

Run with `-demoData`: finish a game, tap Next game, type *"me and Luis vs Carlos and Papo"*. Expected: the new game keeps the previous type and target and seats the four names.

- [ ] **Step 4: Run the whole suite**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add iScore/Views/HomeView.swift iScore/Views/GameSummaryView.swift
git commit -m "feat: speak a new game from Home or the end of a game"
```
