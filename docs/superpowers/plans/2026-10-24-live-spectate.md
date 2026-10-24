# Live Spectate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The scorekeeper shares a game with a short code, and the other players watch the live score on their own phones, read-only, with no internet.

**Architecture:** Four pure types hold every decision: `JoinCode`, `SpectateSnapshot` (the wire format and its validation), `SpectateGuest` (the guest's connection state machine and save offer), and `SpectateHost` (what gets published and who gets let in). They live in `iScore/Model/`. A thin `SpectateLink` wraps `MultipeerConnectivity` and passes every event through those types. Guests render a snapshot through a **detached** `Game` (never inserted into a context), so the scoreboard copy and cards are the same code the scorekeeper sees.

**Tech Stack:** SwiftUI, SwiftData, MultipeerConnectivity, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md`, section 5 ("Live spectate over a local connection").

**Branch:** stacked on `worktree-two-languages` (PR #7). This feature's copy follows Feature 4's rules (`LocalizedStringResource`, Spanish in the catalog, `scripts/lint-strings.rb`), so it cannot start from `main` until PR #7 merges. Rebase onto `main` once it does.

## Global Constraints

- `MCSession(..., encryptionPreference: .required)`. Wi-Fi and Bluetooth only: no internet, no iCloud account.
- Join code: 4 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no 0/O/1/I). It is the advertiser's discovery info, and the host checks it again on connect.
- The wire format is a full `Codable` snapshot sent on every change, never a diff: game type, target, both team name lists, `scoreTeam`, state, plus a final flag.
- Guests never write a snapshot to SwiftData, with one exception: the single tap on "Save to my games" after a **finished** game.
- Guest screens have no keypad, no undo and no edit controls. They are absent, not disabled.
- Guests keep the app open. There is no guest Live Activity. The spectate screen keeps the phone awake.
- Every user-visible line is `LocalizedStringResource`, with Spanish in `iScore/Localizable.xcstrings`. Plurals use catalog variations.
- New Swift files go through `ruby scripts/xcodeproj.rb add iScore <path>` (and `add iScoreTests <path>` for tests). Never edit `project.pbxproj` by hand.
- Duo theme only: `Theme` colors, `DuoFont`, `.duoCard()`, `.buttonStyle(.duo(_:))`.
- Tests: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`. Run `xcrun simctl terminate booted SwiftDomainUI.iScore` first.

## Review Focus

1. **Two games in the same room.** A guest who enters code A never sees game B, even when B's host is closer. → Task 4 (`acceptsInvitation`), Task 5 (browse filter).
2. **The host's phone locks or backgrounds mid-game.** Guests show "Lost connection", not a stale score presented as live. When the host comes back, guests get a full snapshot, including any rounds scored from the Lock Screen while it was away. → Task 3 (reducer), Task 6 (publish after drain).
3. **A malformed, oversized or wrong-version message.** The guest ignores it, keeps its last good state and never crashes. → Task 2.
4. **A guest on the same iCloud account as the host.** That guest already gets the game through CloudKit. The save offer says "Already in your games" and never creates a duplicate. → Task 3.
5. **The host starts the next game while sharing, or opens an old finished game.** Guests follow the new game automatically. An old game is never broadcast. → Task 4.

---

### Task 1: Join code

**Files:**
- Create: `iScore/Model/JoinCode.swift`
- Test: `iScoreTests/JoinCodeTests.swift`

**Interfaces:**
- Produces: `struct JoinCode: Equatable, Hashable, CustomStringConvertible { let value: String }`, `static let alphabet: String`, `static let length = 4`, `static func random<G: RandomNumberGenerator>(using: inout G) -> JoinCode`, `static func random() -> JoinCode`, `init?(typed: String)`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func alphabetHasNoLookalikes() {
    for ch in "0O1I" { #expect(!JoinCode.alphabet.contains(ch)) }
    #expect(JoinCode.alphabet.count == 32)
}
@Test func randomCodesAreFourCharactersFromTheAlphabet() {
    var rng = SystemRandomNumberGenerator()
    for _ in 0..<200 {
        let code = JoinCode.random(using: &rng)
        #expect(code.value.count == 4)
        #expect(code.value.allSatisfy(JoinCode.alphabet.contains))
    }
}
@Test func typedCodesAreForgiving() {
    #expect(JoinCode(typed: " k7mq ")?.value == "K7MQ")
    #expect(JoinCode(typed: "K7-MQ")?.value == "K7MQ")
    #expect(JoinCode(typed: "k 7 m q")?.value == "K7MQ")
}
@Test func typedCodesRejectWhatCannotBeACode() {
    #expect(JoinCode(typed: "K7M") == nil)       // short
    #expect(JoinCode(typed: "K7MQX") == nil)     // long
    #expect(JoinCode(typed: "K0MQ") == nil)      // 0 is not in the alphabet
    #expect(JoinCode(typed: "") == nil)
}
```

- [ ] **Step 2: Run them.** Expected: compile failure, `JoinCode` not defined.
- [ ] **Step 3: Implement `JoinCode`.** `init?(typed:)` uppercases, then removes whitespace and `-`, then requires exactly `length` characters, all from the alphabet. `description` returns `value`.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: join codes for live spectate`.

---

### Task 2: The snapshot and its validation

**Files:**
- Create: `iScore/Model/SpectateSnapshot.swift`
- Test: `iScoreTests/SpectateSnapshotTests.swift`

**Interfaces:**
- Consumes: `Game`, `GameType.targetRange`, `PlayerName.maxLength`.
- Produces:
  - `struct SpectateSnapshot: Codable, Equatable { var version: Int; var gameID: UUID; var gameType: GameType; var target: Int; var team1: [String]; var team2: [String]; var scoreTeam: [[Int]]; var state: GameState; var isFinal: Bool }`
  - `static let currentVersion = 1`, `static let maxBytes = 64 * 1024`, `static let maxRounds = 500`, `static let maxRoundPoints = 1000`
  - `init(game: Game)`. `isFinal` is `game.state != .playing`. `gameID` is `game.id`.
  - `func encoded() throws -> Data` (JSON)
  - `static func decode(_ data: Data) -> SpectateSnapshot?`. This returns nil when the data is over `maxBytes`, fails to decode, has the wrong version, or fails `isPlausible`.
  - `var isPlausible: Bool`. True only when: `target` is in `gameType.targetRange`; each team has at most 2 names of at most `PlayerName.maxLength` characters; `scoreTeam` is non-empty with at most `maxRounds + 1` rows; every row has exactly 2 entries, each in `0...maxRoundPoints`.
  - `func makeDetachedGame() -> Game`. A `Game` that is **never inserted into a context**, carrying the snapshot's type, target, names, `scoreTeam` and state. Guests render this.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func roundTripsAGame() throws {
    let game = makeTestGame(rows: demoGameRows)
    let snapshot = SpectateSnapshot(game: game)
    #expect(SpectateSnapshot.decode(try snapshot.encoded()) == snapshot)
    #expect(snapshot.gameID == game.id)
    #expect(snapshot.isFinal == false)
}
@Test func aFinishedGameIsFinal() {
    let game = makeTestGame(rows: demoGameRows); game.state = .finished
    #expect(SpectateSnapshot(game: game).isFinal)
}
@Test func theDetachedGameScoresLikeTheOriginal() {
    let game = makeTestGame(rows: demoGameRows)
    let copy = SpectateSnapshot(game: game).makeDetachedGame()
    #expect(copy.totalScore1 == game.totalScore1)
    #expect(copy.totalScore2 == game.totalScore2)
    #expect(String(localized: copy.headline) == String(localized: game.headline))
    #expect(copy.modelContext == nil)
}
// Review Focus 3
@Test func garbageAndOversizeAreIgnored() throws {
    #expect(SpectateSnapshot.decode(Data("not json".utf8)) == nil)
    #expect(SpectateSnapshot.decode(Data(count: SpectateSnapshot.maxBytes + 1)) == nil)
}
@Test func anotherVersionIsIgnored() throws {
    var snapshot = SpectateSnapshot(game: makeTestGame()); snapshot.version = 2
    #expect(SpectateSnapshot.decode(try snapshot.encoded()) == nil)
}
@Test func implausibleShapesAreIgnored() throws {
    let base = SpectateSnapshot(game: makeTestGame())
    var a = base; a.scoreTeam = [[0, 0], [5]]                      // short row
    var b = base; b.scoreTeam = [[0, 0], [-5, 0]]                  // negative
    var c = base; c.target = 990                                   // off range
    var d = base; d.team1 = ["Ana", "Luis", "Rafa"]                // three a side
    var e = base; e.team2 = [String(repeating: "x", count: 40)]    // long name
    var f = base; f.scoreTeam = []                                 // no seed row
    for bad in [a, b, c, d, e, f] {
        #expect(SpectateSnapshot.decode(try bad.encoded()) == nil)
    }
}
```

- [ ] **Step 2: Run them.** Expected: compile failure, `SpectateSnapshot` not defined.
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: the spectate snapshot, validated on arrival`.

---

### Task 3: The guest's state, and saving a finished game

**Files:**
- Create: `iScore/Model/SpectateGuest.swift`
- Test: `iScoreTests/SpectateGuestTests.swift`

**Interfaces:**
- Consumes: `SpectateSnapshot`, `GameFactory`/`PlayerName.isSame` (reuse players by name), `Game`.
- Produces:
  - `enum SpectateGuest.Phase: Equatable { case searching, live(SpectateSnapshot), lost(SpectateSnapshot?), finished(SpectateSnapshot) }`
  - `enum SpectateGuest.Event: Equatable { case received(Data), disconnected, reconnecting }`
  - `static func reduce(_ phase: Phase, _ event: Event) -> Phase`
  - `static func status(for phase: Phase) -> LocalizedStringResource`. The returned copy is: "Looking for the game…", "Live", "Lost connection. Reconnecting…", "Final score".
  - `enum SpectateSave { static func isAlreadySaved(_ s: SpectateSnapshot, in games: [Game]) -> Bool; @MainActor @discardableResult static func save(_ s: SpectateSnapshot, existing: [Player], in context: ModelContext) -> Game? }`

Reducer rules:
- `.received` with data that `decode` rejects leaves the phase unchanged.
- A valid snapshot gives `.live`, or `.finished` when `isFinal` and `state == .finished`. A final *cancelled* game gives `.live` with that state. The view shows it as over, with no save offer.
- `.disconnected` from `.live` gives `.lost(last)`. From `.searching` it stays `.searching`. From `.finished` it stays `.finished`, because the game is over and losing the host changes nothing.
- `.reconnecting` changes nothing (it is a hook for the view).
- A snapshot with a different `gameID` replaces the current one. This is how guests follow the host's next game.

`SpectateSave.save` returns nil, and inserts nothing, unless the snapshot is final and finished, and `isAlreadySaved` is false. Otherwise it inserts a `Game` with the snapshot's fields, `state = .finished` and `inProcess = false`. It reuses existing players by `PlayerName.isSame` and creates the rest, the same way `GameFactory.make` does. `isAlreadySaved` matches on game type, target, both team name lists (`PlayerName.isSame`, element-wise) and an identical `scoreTeam`.

- [ ] **Step 1: Write the failing tests**, one `@Test` per rule above. These cover: garbage leaves `.live(x)` unchanged; a finished final gives `.finished`; a cancelled final gives `.live` with no save; `.disconnected` from each phase; a new `gameID` replaces the current one; `status` in English and Spanish for every phase (`localized(_:in: "es")`); and for `save`, an in-memory container. Save inserts exactly one game and reuses an existing "Ana". It refuses a non-final snapshot. It refuses a second save of the same snapshot (Review Focus 4) and returns nil.
- [ ] **Step 2: Run them.** Expected: compile failure.
- [ ] **Step 3: Implement** `SpectateGuest` and `SpectateSave`. Add the four status lines to the catalog with Spanish: "Buscando la partida…", "En vivo", "Se perdió la conexión. Reconectando…", "Resultado final".
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: the guest's spectate state and the one save it may make`.

---

### Task 4: The host's policy

**Files:**
- Create: `iScore/Model/SpectateHost.swift`
- Test: `iScoreTests/SpectateHostTests.swift`

**Interfaces:**
- Consumes: `JoinCode`, `Game`.
- Produces:
  - `enum SpectatePolicy { static func acceptsInvitation(context: Data?, code: JoinCode) -> Bool; static func invitationContext(for code: JoinCode) -> Data; static func discoveryInfo(for code: JoinCode) -> [String: String]; static func matches(discoveryInfo: [String: String]?, code: JoinCode) -> Bool; static func shouldPublish(_ game: Game, sharedGameID: UUID?) -> Bool; static func sharedGameID(afterPublishing game: Game, current: UUID?) -> UUID?; static func watchingLabel(_ count: Int) -> LocalizedStringResource }`
  - `static let discoveryKey = "code"`

Rules: an invitation is accepted only when its context is exactly `code.value` as UTF-8. A nil or empty context is refused. `shouldPublish` is true when `game.id == sharedGameID`, which lets the final state of the game being shared go out. Otherwise it is true only when `game.state == .playing`, so a new game while sharing goes out and an old finished game opened from history never does. `sharedGameID(afterPublishing:current:)` returns `game.id` when `shouldPublish` is true, otherwise `current`; the link stores whatever it returns. `watchingLabel` uses the plural key `"%lld watching"`: "Nobody watching yet" for 0, "1 watching" / "%lld watching" in English, and "Nadie mirando todavía" / "1 mirando" / "%lld mirando" in Spanish.

- [ ] **Step 1: Write the failing tests:**
  - Invitations: the right code is accepted. A wrong code, nil, empty and lowercase are refused (Review Focus 1).
  - The discovery info round-trips through `matches`, and a different code does not match.
  - `shouldPublish` covers four cases: the shared game while it plays, the shared game after it finishes, a different playing game, and a different finished game (Review Focus 5). `sharedGameID(afterPublishing:current:)` keeps `current` for an old finished game and moves to a new playing one.
  - `watchingLabel` is checked for 0, 1 and 3 in both languages.
- [ ] **Step 2: Run them.** Expected: compile failure.
- [ ] **Step 3: Implement**, and add the catalog entries with plural variations.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: who a shared game lets in and what it sends`.

---

### Task 5: The local link and its permissions

**Files:**
- Create: `iScore/Model/SpectateLink.swift`
- Create: `iScore/InfoPlist.xcstrings` (register with `add iScore`)
- Modify: `iScore/Info.plist` (add `NSBonjourServices`)
- Modify: the build settings, via `ruby scripts/xcodeproj.rb set iScore INFOPLIST_KEY_NSLocalNetworkUsageDescription="…"`
- Test: `iScoreTests/SpectateLinkTests.swift`

**Interfaces:**
- Consumes: `SpectatePolicy`, `SpectateSnapshot`, `JoinCode`.
- Produces:
  - `enum SpectateService { static let type = "iscore-live" }`
  - `@MainActor @Observable final class SpectateHostLink`, with:
    - `var code: JoinCode?`
    - `var watching: Int`
    - `var sharedGameID: UUID?`
    - `func start(sharing game: Game)`: picks a code if none exists, advertises, and publishes.
    - `func publish(_ game: Game)`: no-op unless sharing and `shouldPublish`. It sets `sharedGameID` to the game's id, and sends the snapshot to every peer, `.reliable`.
    - `func stop()`.
  - On a new peer connecting, the host sends the last snapshot to that peer alone.
  - `@MainActor @Observable final class SpectateGuestLink`, with:
    - `private(set) var phase: SpectateGuest.Phase`
    - `func join(_ code: JoinCode)`: browses, invites the first peer whose discovery info `matches`, and sends `invitationContext`.
    - `func leave()`
  - Every delegate callback hops to the main actor and goes through `SpectateGuest.reduce`. Peers that don't match are never invited.

`MCPeerID.displayName` is the owner name (`OwnerIdentity.nameKey`) when it is set, otherwise "iScore". Both sides use `MCSession(peer:securityIdentity: nil, encryptionPreference: .required)`. After `.disconnected`, the guest keeps browsing with the same code, which is how it reconnects automatically.

The Info.plist entries are:
- `NSBonjourServices`: `_iscore-live._tcp` and `_iscore-live._udp`
- `NSLocalNetworkUsageDescription`: "iScore finds the scorekeeper's phone nearby so you can follow the score."

`InfoPlist.xcstrings` gives Spanish for the local network description, and also for `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`. Those two are the deferred Feature 4 minor: the prompts are in English today. Copy each English value from the current build settings.

- [ ] **Step 1: Write the failing tests:**
  - `Bundle.main.object(forInfoDictionaryKey: "NSBonjourServices")` contains `"_\(SpectateService.type)._tcp"` and `._udp`.
  - The local network description is non-empty.
  - `SpectateService.type` is 1–15 characters, lowercase ASCII letters, digits and hyphens (Bonjour's rule).
  - A `SpectateHostLink` that was never started ignores `publish` and reports `watching == 0`.
- [ ] **Step 2: Run them.** Expected: compile failure.
- [ ] **Step 3: Implement** the link, the plist entry, the build setting and `InfoPlist.xcstrings`.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: the local link for live spectate`.

---

### Task 6: Sharing from the scorekeeper's phone

**Files:**
- Modify: `iScore/iScoreApp.swift`. Own one `SpectateHostLink` and inject it with `.environment`, so sharing survives leaving the Game screen.
- Modify: `iScore/Views/GameView.swift`. Add a toolbar Share button (`person.2.wave.2`, accessibility label "Share live score") that opens the share sheet. Call `publish` in `.task`, in `.onChange(of: game.scoreTeam)` and in `.onChange(of: game.state)`. These are the same three places that keep the Live Activity in step.
- Modify: `iScore/Views/HomeView.swift`. After the Lock Screen drain (where it calls `ScoreActivityController.shared.drain`), also call `publish` (Review Focus 2).
- Create: `iScore/Views/SpectateShareSheet.swift`. `SheetHeader`, the code in `DuoFont.score` with letter spacing, "Read this code to the table" on the line under it, `watchingLabel`, and a "Stop sharing" button.

Sharing stays on across games until the user taps Stop sharing. While sharing, the host's screen does not sleep (`UIApplication.shared.isIdleTimerDisabled`). The flag is set when sharing starts and cleared on stop. **Ruling-worthy:** this is my call. If the scorekeeper's phone locks, every guest drops, and the spec asks for "all showing the same score within a second".

This task is wiring only. Every decision it makes is a Task 4 function with its own tests, so it adds no unit test: one written here would pass before the code exists. Its gate is the suite, the lint and the eye check.

- [ ] **Step 1: Implement** the environment object, the GameView hooks, the HomeView hook and the share sheet. Add catalog entries with Spanish: "Share live score" / "Compartir marcador en vivo", "Read this code to the table" / "Lee este código a la mesa", "Stop sharing" / "Dejar de compartir".
- [ ] **Step 2: Run the suite and the lint.** Expected: PASS.
- [ ] **Step 3: Check by eye** on the simulator, with `-demoData`. The Share button opens the sheet, the code is legible, and Stop sharing clears it.
- [ ] **Step 4: Commit** `feat: share a game's live score from the Game screen`.

---

### Task 7: Watching from a guest's phone

**Files:**
- Modify: `iScore/Views/HomeView.swift`. Add a full-width `HomeCardView` under the four tiles: icon `eye.fill`, "Watch a game" / "Enter a code", tint `Theme.streak`. It opens `JoinGameView`.
- Create: `iScore/Views/JoinGameView.swift`. A sheet with one code field (`.textInputAutocapitalization(.characters)`, `.autocorrectionDisabled()`, monospaced `DuoFont.score`) and a Join button. The button is enabled only when `JoinCode(typed:)` is non-nil. Joining presents `SpectateView` full screen.
- Create: `iScore/Views/SpectateView.swift`. It shows:
  - A `StatusChip` from `SpectateGuest.status(for:)`.
  - `statusLabel`, `headline`, two `TeamScoreCard`s and the round list, all rendered from `snapshot.makeDetachedGame()`.
  - In `.lost`, the last score at reduced opacity under the lost-connection chip. It is never presented as live.
  - In `.finished`, a "Save to my games" button. It becomes "Saved", or shows "Already in your games" up front when `SpectateSave.isAlreadySaved`.
  - A Close button that calls `leave()`.
  - **No keypad, no undo, no edit, no voice bar.**
  - The phone stays awake while the view is on screen.
  - Scene phase: anything other than `.active` calls `leave()`, and `.active` calls `join(code)` again.
- Modify: `CLAUDE.md`. Add a "Live spectate" section covering the four pure types, the detached-Game rule, the one-write rule, the sharing-survives-the-Game-screen rule, and the host stay-awake call.

Like Task 6, this task is views over decisions that Tasks 2 and 3 already test (the lost/live distinction is covered by the `status(for:)` test), so it adds no unit test.

- [ ] **Step 1: Implement** the Home card, `JoinGameView`, `SpectateView` and the CLAUDE.md section. Add catalog entries with Spanish:

  | English | Spanish |
  |---|---|
  | Watch a game | Ver una partida |
  | Enter a code | Escribe un código |
  | Join | Entrar |
  | Save to my games | Guardar en mis partidas |
  | Saved | Guardada |
  | Already in your games | Ya está en tus partidas |
  | Close | Cerrar |
- [ ] **Step 2: Run the suite and the lint** (`ruby scripts/lint-strings.rb`). Expected: PASS, and no un-localizable copy.
- [ ] **Step 3: Check by eye** on two simulators, using `xcrun simctl` for a second booted device. Share on one and join on the other. Record a round and watch it arrive. Kill the host app and watch "Lost connection" appear. Relaunch it and watch the guest recover.
- [ ] **Step 4: Commit** `feat: watch a shared game from another phone`.

## Not verifiable here (real-device list for the owner)

- Four devices with Wi-Fi and cellular off, all showing the same score within a second (the spec's done-line).
- Bluetooth-only discovery range across a real table.
- The local-network permission prompt in Spanish.
