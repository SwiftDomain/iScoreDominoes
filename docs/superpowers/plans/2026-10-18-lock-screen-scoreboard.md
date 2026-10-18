# Lock Screen Scoreboard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While a game is in progress, a Live Activity on the Lock Screen (and in the Dynamic Island) shows both team names, both totals, the round number and points to win for the leader, and carries a per-team grid of the point values that actually come up plus undo — so a whole night of common rounds is scored without ever unlocking the phone, and the in-app score matches exactly afterwards.

**Architecture:** Single-owner model, append-only handoff. The widget process **never** opens the CloudKit-backed SwiftData container. A tap on a Lock Screen button runs an App Intent in the widget process that (a) appends one line to a JSON-Lines pending-rounds file in the shared App Group container and (b) reloads the Live Activity optimistically from the content state it already holds. The app is the only writer to SwiftData: on foreground, and whenever it refreshes an activity, it drains the pending file in file order, applies each entry through the existing `Game.addRound` / `undoLastRound`, and republishes the authoritative content state. Draining truncates exactly the byte count it read (so a round tapped mid-drain is not lost) and skips entries whose ids are in a small applied-ids ledger (so a crash between apply and truncate does not double-count).

Everything decidable without ActivityKit lives in pure types in `iScore/Shared/`, compiled into the app, the widget **and** the test target: `PendingRound`, `PendingRoundsStore`, `AppliedRoundsLedger`, `PendingRoundsDrain`, `PointGrid`, `ScoreboardState`, `ScoreLink`, `LockScreenScoring`, `AppGroup`. The widget and the ActivityKit/SwiftUI wiring stay thin.

**Tech Stack:** SwiftUI, SwiftData, WidgetKit, ActivityKit, AppIntents, App Groups, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md` (Feature 2; the Constraints section applies in full)

**Branch:** `lock-screen-scoreboard`, off `main` (confirmed with the owner on 2026-10-18 — Feature 1 is open as PR #4 and unmerged, and Feature 2 does not depend on it; expect one merge conflict in `project.pbxproj` and possibly `SettingsView.swift` whenever the second of the two PRs lands). The repo has unrelated staged asset changes at plan time — leave them alone and never `git add -A`.

**App Group:** `group.SwiftDomainUI.iScore`. Added to both targets' entitlements files in Task 1. Verification throughout is on the iPhone 17 Pro simulator, which does not enforce provisioning; the capability must be enabled in the Apple Developer portal for `SwiftDomainUI.iScore` and `SwiftDomainUI.iScore.Widgets` before this runs on a real device. That portal step is the owner's, and is called out again in Task 10.

## Global Constraints

- iOS 26 deployment target, Swift 5 language mode, SwiftUI + SwiftData.
- SwiftData syncs via CloudKit (`cloudKitDatabase: .automatic`): **every new persisted property needs a default value and every new relationship must be optional.** This plan adds **no** new `@Model` types and **no** new properties to `Game` or `Player`. Keep it that way — the pending file and the applied-ids ledger exist precisely so the schema does not move.
- `Game.scoreTeam` is `[[Int]]` with a seed `[0, 0]` row; every real round is one-sided. Do not change this shape. Rounds are appended and undone **only** through the existing `Game.addRound(_:for:)` and `Game.undoLastRound()`.
- No `Color` literals in views, including the widget. Semantic colors come from `Theme` only. Any new colorset goes in `Assets.xcassets` **and** `Theme.colorAssetNames`, or `ThemeTests` fails. This plan adds no new colorsets.
- Type is `DuoFont` (`.score`, `.title`, `.body`, `.label`). Cards: radius 16, 2pt border, 4pt bottom edge. Buttons: radius 14, 4pt darker bottom edge. No gradients, shadows, blur, or glass. (Live Activity views cannot use the app's `.duo` button style verbatim — see Task 7 — but the shape and color vocabulary must match.)
- `Theme`, `DuoFont` and `Assets.xcassets` must become members of the widget target too; `Color("teamA")` resolves against `Bundle.main`, which inside an extension is the extension's own bundle.
- Every new or deleted Swift file must be registered: `ruby scripts/xcodeproj.rb add iScore <path>` (app), `add iScoreWidgets <path>` (widget), `add iScoreTests <path>` (tests). A shared file is registered against **each** target that needs it.
- Logic lives in pure types with Swift Testing coverage in `iScoreTests`. Views stay thin.
- Test command used throughout:
  `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:<suite-path>`
  **The OS must be pinned.** This machine has an iPhone 17 Pro on both 26.4 and 26.5, and the bare name makes `xcodebuild` fall through to a macOS destination and error out. Heavy CloudKit error logging in simulator output is known noise (no iCloud account in the simulator).

## Review Focus

Input classes the spec implies that no task's happy-path tests would otherwise exercise. Each has its test pinned to the task that owns the code.

1. **A round tapped while the app is draining.** Expected: the entry appended after the drain read survives — the drain truncates only the bytes it read, never the whole file. → Task 2.
2. **A crash (or kill) between applying to SwiftData and truncating the file.** Expected: the next drain skips the already-applied entries by id and the score does not double-count. → Task 3.
3. **An undo tapped when there is nothing left to undo** — the file holds `[undo]` and the game has no rounds, or `[add, undo, undo]`. Expected: the extra undo is a no-op, the drain does not crash, and no negative or phantom round appears. → Task 3.
4. **A pending file that is corrupt, truncated mid-line, or written by an older build.** Expected: unreadable lines are skipped, readable ones still apply in order, and the file is not left poisoned forever. → Task 2.
5. **Taps arriving for a game that is already finished, cancelled, or deleted.** Expected: the drain ignores entries whose `gameID` does not match a playing game, the activity ends rather than accepting more rounds, and nothing is written to a finished game. → Task 3 (pure) and Task 8 (wiring).
6. **A game whose rounds exhaust the grid** — a value outside the grid. Expected: the "Other" button deep-links into the app's Add Score sheet for that game, and the Lock Screen never silently does nothing. → Task 6.
7. **The unlock toggle on.** Expected: every scoring control becomes a deep link that requires unlock; no `Button(intent:)` remains reachable, and the grid still reads the same. → Task 9.

---

### Task 1: Widget Extension target and the shared App Group

The first new target in this project. `scripts/xcodeproj.rb` can create targets (it already does for `iScoreTests` in `setup-tests`), so extend the script rather than hand-editing `project.pbxproj`.

**Files:**
- Modify: `scripts/xcodeproj.rb` (new `setup-widget` command)
- Create: `iScoreWidgets/iScoreWidgets.entitlements`
- Modify: `iScore/iScore.entitlements` (add the App Group)
- Create: `iScoreWidgets/iScoreWidgetsBundle.swift` (placeholder `@main` bundle, empty body for now)
- Create: `iScore/Shared/AppGroup.swift`
- Create: `iScoreTests/AppGroupTests.swift`

**Interfaces:**
- Produces: `enum AppGroup { static let identifier = "group.SwiftDomainUI.iScore"; static var containerURL: URL? { get }; static var defaults: UserDefaults? { get }; static func pendingRoundsURL(containerURL: URL) -> URL }` — the `containerURL`-taking form is the testable one; the no-argument accessors are thin wrappers over `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`.
- Produces (build system): target `iScoreWidgets`, product type `app_extension`, bundle id `SwiftDomainUI.iScore.Widgets`, embedded in the app's PlugIns folder, depended on by `iScore`, sharing `Assets.xcassets`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct AppGroupTests {

    @Test func identifierMatchesTheEntitlements() {
        #expect(AppGroup.identifier == "group.SwiftDomainUI.iScore")
    }

    @Test func pendingRoundsFileSitsInTheContainer() {
        let container = URL(fileURLWithPath: "/tmp/container", isDirectory: true)
        let url = AppGroup.pendingRoundsURL(containerURL: container)
        #expect(url.lastPathComponent == "pending-rounds.jsonl")
        #expect(url.deletingLastPathComponent().lastPathComponent == "container")
    }

    @Test func bothEntitlementsFilesDeclareTheGroup() throws {
        // The target wiring is the point of this task, so assert on the files
        // themselves: a missing group here is a silent, device-only failure.
        for path in ["iScore/iScore.entitlements", "iScoreWidgets/iScoreWidgets.entitlements"] {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // iScoreTests
                .deletingLastPathComponent()   // repo root
                .appendingPathComponent(path)
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.contains("com.apple.security.application-groups"), "\(path)")
            #expect(text.contains(AppGroup.identifier), "\(path)")
        }
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:iScoreTests/AppGroupTests`
Expected: FAIL — `cannot find 'AppGroup' in scope`.

- [ ] **Step 3: Add the `setup-widget` command to `scripts/xcodeproj.rb`**

Mirroring `setup_tests`:

- `project.new_target(:app_extension, 'iScoreWidgets', :ios, '26.0', project.products_group, :swift)`, then `remove_sdk_frameworks(widget)` (same SDK-path problem `setup_tests` already works around).
- Build settings on both configurations: `PRODUCT_NAME = $(TARGET_NAME)`, `PRODUCT_BUNDLE_IDENTIFIER = SwiftDomainUI.iScore.Widgets`, `GENERATE_INFOPLIST_FILE = YES`, `INFOPLIST_KEY_CFBundleDisplayName = iScore`, `INFOPLIST_KEY_NSExtensionPointIdentifier = com.apple.widgetkit-extension`, `SWIFT_VERSION = 5.0`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `TARGETED_DEVICE_FAMILY = 1,2`, `SKIP_INSTALL = YES`, `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = 5G4KHSNPYL` (read off the app target, as `setup_tests` does), `CODE_SIGN_ENTITLEMENTS = iScoreWidgets/iScoreWidgets.entitlements`.
- App target: `INFOPLIST_KEY_NSSupportsLiveActivities = YES` on both configurations (ActivityKit will not start an activity without it).
- Embed: `app.add_dependency(widget)` and a `PBXCopyFilesBuildPhase` named `Embed Foundation Extensions` with `dst_subfolder_spec = :plug_ins` containing the widget's product ref, with `ATTRIBUTES = (RemoveHeadersOnCopy,)`. Guard the whole command so re-running it is a no-op.
- Add `Assets.xcassets` to the widget's resources build phase (reuse the existing file reference).
- Make the command idempotent: `return if project.targets.any? { |t| t.name == 'iScoreWidgets' }` for target creation, and guard each settings/phase mutation.

Run `ruby scripts/xcodeproj.rb setup-widget`.

- [ ] **Step 4: Write the entitlements and the placeholder bundle**

`iScore/iScore.entitlements` gains:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.SwiftDomainUI.iScore</string>
</array>
```

`iScoreWidgets/iScoreWidgets.entitlements` is a new plist with the same `application-groups` array and nothing else (no CloudKit — the widget must never reach the store).

`iScoreWidgets/iScoreWidgetsBundle.swift`:

```swift
import SwiftUI
import WidgetKit

@main
struct iScoreWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity lands in Task 7.
        EmptyWidgetPlaceholder()
    }
}
```

…where the placeholder is the smallest `Widget` that compiles (a `StaticConfiguration` over an empty timeline provider). It is deleted in Task 7.

- [ ] **Step 5: Implement `AppGroup` and register the files**

```bash
ruby scripts/xcodeproj.rb add iScore iScore/Shared/AppGroup.swift
ruby scripts/xcodeproj.rb add iScoreWidgets iScore/Shared/AppGroup.swift iScoreWidgets/iScoreWidgetsBundle.swift
ruby scripts/xcodeproj.rb add iScoreTests iScoreTests/AppGroupTests.swift
```

Register `Theme.swift` with the widget target at the same time (`add iScoreWidgets iScore/Model/Theme.swift`) — Task 7 needs it and it costs nothing now.

- [ ] **Step 6: Run to verify they pass, and that the app still builds with the extension embedded**

Run: the Step 2 command, then the full suite:
`xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: PASS, 188 existing tests plus the three new ones, and the build log shows `iScoreWidgets.appex` being produced and copied.

- [ ] **Step 7: Commit**

```bash
git add scripts/xcodeproj.rb iScore/iScore.entitlements iScoreWidgets iScore/Shared/AppGroup.swift iScoreTests/AppGroupTests.swift iScore.xcodeproj
git commit -m "build: add iScoreWidgets extension target and the shared App Group"
```

---

### Task 2: The pending-rounds file

**Files:**
- Create: `iScore/Shared/PendingRound.swift`
- Create: `iScore/Shared/PendingRoundsStore.swift`
- Create: `iScoreTests/PendingRoundsStoreTests.swift`

**Interfaces:**
- Consumes: `AppGroup`.
- Produces: `enum PendingAction: Codable, Equatable { case add(points: Int, team: TeamSide); case undo }`, `enum TeamSide: String, Codable { case team1, team2 }` (an `@Model`-free mirror of `Team`, with `var team: Team` and `init?(_ team: Team)` bridges), and `struct PendingRound: Codable, Equatable, Identifiable { let id: UUID; let gameID: UUID; let action: PendingAction; let date: Date }`.
- Produces: `struct PendingRoundsStore { let url: URL; init(url: URL); func append(_ round: PendingRound) throws; func load() throws -> [PendingRound]; func drain() throws -> [PendingRound] }`. One JSON object per line, UTF-8, appended with `FileHandle.seekToEnd`. `drain` reads the whole file, notes the byte count it read, parses, then truncates to **exactly that offset** — anything appended during the read survives. Unparseable lines are skipped, not fatal.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct PendingRoundsStoreTests {

    private func tempStore() -> PendingRoundsStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return PendingRoundsStore(url: dir.appendingPathComponent("pending-rounds.jsonl"))
    }

    private func round(_ points: Int, _ team: TeamSide = .team1, game: UUID = UUID()) -> PendingRound {
        PendingRound(id: UUID(), gameID: game, action: .add(points: points, team: team), date: Date())
    }

    @Test func loadingAnAbsentFileIsEmptyNotAnError() throws {
        #expect(try tempStore().load().isEmpty)
    }

    @Test func appendsKeepFileOrder() throws {
        let store = tempStore()
        let game = UUID()
        let first = round(25, .team1, game: game)
        let second = round(30, .team2, game: game)
        let third = PendingRound(id: UUID(), gameID: game, action: .undo, date: Date())
        try store.append(first)
        try store.append(second)
        try store.append(third)

        let loaded = try store.load()
        #expect(loaded.map(\.id) == [first.id, second.id, third.id])
        #expect(loaded[0].action == .add(points: 25, team: .team1))
        #expect(loaded[1].action == .add(points: 30, team: .team2))
        #expect(loaded[2].action == .undo)
    }

    @Test func drainReturnsEverythingAndEmptiesTheFile() throws {
        let store = tempStore()
        try store.append(round(10))
        try store.append(round(20))

        #expect(try store.drain().map(\.action) == [.add(points: 10, team: .team1),
                                                    .add(points: 20, team: .team1)])
        #expect(try store.load().isEmpty)
        #expect(try store.drain().isEmpty)
    }

    // Review Focus 1
    @Test func anAppendDuringADrainSurvives() throws {
        let store = tempStore()
        try store.append(round(10))
        let readBytes = try Data(contentsOf: store.url).count

        // A tap lands after the drain has read, before it truncates.
        try store.append(round(99))
        try store.truncate(toOffset: UInt64(readBytes))   // what drain() does internally

        let left = try store.load()
        #expect(left.count == 1)
        #expect(left[0].action == .add(points: 99, team: .team1))
    }

    // Review Focus 4
    @Test func corruptLinesAreSkippedAndTheRestStillLoad() throws {
        let store = tempStore()
        try store.append(round(10))
        let handle = try FileHandle(forWritingTo: store.url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{not json\n".utf8))
        try handle.close()
        try store.append(round(20))

        let loaded = try store.load()
        #expect(loaded.map(\.action) == [.add(points: 10, team: .team1),
                                         .add(points: 20, team: .team1)])
    }

    @Test func aTruncatedFinalLineIsSkipped() throws {
        let store = tempStore()
        try store.append(round(10))
        let handle = try FileHandle(forWritingTo: store.url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"id\":\"half".utf8))   // no newline: a kill mid-write
        try handle.close()

        #expect(try store.load().map(\.action) == [.add(points: 10, team: .team1)])
        // Draining clears the poison rather than leaving it to fail forever.
        _ = try store.drain()
        #expect(try store.load().isEmpty)
    }

    @Test func teamSideBridgesToTeam() {
        #expect(TeamSide.team1.team == .team1)
        #expect(TeamSide.team2.team == .team2)
        #expect(TeamSide(.team1) == .team1)
        #expect(TeamSide(.none) == nil)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: the test command with `-only-testing:iScoreTests/PendingRoundsStoreTests`.
Expected: FAIL — `cannot find 'PendingRoundsStore' in scope`.

- [ ] **Step 3: Implement**

`PendingRound.swift` holds `TeamSide`, `PendingAction` and `PendingRound`; `PendingAction` gets an explicit `Codable` conformance (an enum with associated values encodes fine with the synthesized one, but pin the keys so an older build's file still decodes). `PendingRoundsStore` creates the file on first append, uses one `JSONEncoder`/`JSONDecoder` with `.iso8601` dates, and exposes `truncate(toOffset:)` as the internal operation the drain and the test above share. Register with `add iScore`, `add iScoreWidgets`, `add iScoreTests`.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add iScore/Shared/PendingRound.swift iScore/Shared/PendingRoundsStore.swift iScoreTests/PendingRoundsStoreTests.swift iScore.xcodeproj
git commit -m "feat: append-only pending-rounds file for Lock Screen taps"
```

---

### Task 3: Draining into SwiftData, exactly once, in order

**Files:**
- Create: `iScore/Shared/AppliedRoundsLedger.swift`
- Create: `iScore/Model/PendingRoundsDrain.swift`
- Create: `iScoreTests/PendingRoundsDrainTests.swift`

**Interfaces:**
- Consumes: `PendingRound`, `Game.addRound(_:for:)`, `Game.undoLastRound()`.
- Produces: `struct AppliedRoundsLedger { init(defaults: UserDefaults, key: String = "appliedPendingRoundIDs", limit: Int = 200); func contains(_ id: UUID) -> Bool; mutating func record(_ ids: [UUID]) }` — a FIFO of the last `limit` applied ids in the shared `UserDefaults` suite.
- Produces: `enum PendingRoundsDrain { @discardableResult static func apply(_ entries: [PendingRound], to game: Game, ledger: inout AppliedRoundsLedger) -> Int }` — returns how many entries changed the game. Entries for another `gameID` are ignored; entries already in the ledger are skipped; entries are applied strictly in the order given; an `undo` with no round left is a no-op; a game that is not `.playing` accepts nothing.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct PendingRoundsDrainTests {

    private func ledger() -> AppliedRoundsLedger {
        let defaults = UserDefaults(suiteName: "drain-tests-\(UUID().uuidString)")!
        return AppliedRoundsLedger(defaults: defaults)
    }

    private func playingGame() -> Game {
        let game = Game(gameType: .nine, maxScore: 200)
        return game
    }

    private func add(_ points: Int, _ team: TeamSide, game: UUID) -> PendingRound {
        PendingRound(id: UUID(), gameID: game, action: .add(points: points, team: team), date: Date())
    }

    private func undo(game: UUID) -> PendingRound {
        PendingRound(id: UUID(), gameID: game, action: .undo, date: Date())
    }

    @Test func appliesRoundsInOrder() {
        let game = playingGame()
        var book = ledger()
        let applied = PendingRoundsDrain.apply(
            [add(25, .team1, game: game.id), add(30, .team2, game: game.id), add(10, .team1, game: game.id)],
            to: game, ledger: &book
        )
        #expect(applied == 3)
        #expect(game.rounds.map(\.points) == [25, 30, 10])
        #expect(game.rounds.map(\.team) == [.team1, .team2, .team1])
        #expect(game.totalScore1 == 35)
        #expect(game.totalScore2 == 30)
    }

    @Test func undoTakesBackTheLastRound() {
        let game = playingGame()
        var book = ledger()
        PendingRoundsDrain.apply(
            [add(25, .team1, game: game.id), add(30, .team2, game: game.id), undo(game: game.id)],
            to: game, ledger: &book
        )
        #expect(game.rounds.map(\.points) == [25])
        #expect(game.totalScore2 == 0)
    }

    // Review Focus 3
    @Test func anUndoWithNothingToUndoIsANoOp() {
        let game = playingGame()
        var book = ledger()
        let applied = PendingRoundsDrain.apply([undo(game: game.id), undo(game: game.id)], to: game, ledger: &book)
        #expect(applied == 0)
        #expect(game.rounds.isEmpty)
        #expect(game.totalScore1 == 0)
        #expect(game.totalScore2 == 0)
    }

    @Test func extraUndosAfterARoundStopAtEmpty() {
        let game = playingGame()
        var book = ledger()
        PendingRoundsDrain.apply(
            [add(20, .team1, game: game.id), undo(game: game.id), undo(game: game.id)],
            to: game, ledger: &book
        )
        #expect(game.rounds.isEmpty)
        #expect(game.totalScore1 == 0)
    }

    // Review Focus 2
    @Test func replayingTheSameEntriesDoesNotDoubleCount() {
        let game = playingGame()
        var book = ledger()
        let entries = [add(25, .team1, game: game.id), add(30, .team2, game: game.id)]
        PendingRoundsDrain.apply(entries, to: game, ledger: &book)
        let applied = PendingRoundsDrain.apply(entries, to: game, ledger: &book)

        #expect(applied == 0)
        #expect(game.rounds.count == 2)
        #expect(game.totalScore1 == 25)
        #expect(game.totalScore2 == 30)
    }

    // Review Focus 5
    @Test func entriesForAnotherGameAreIgnored() {
        let game = playingGame()
        var book = ledger()
        let applied = PendingRoundsDrain.apply([add(25, .team1, game: UUID())], to: game, ledger: &book)
        #expect(applied == 0)
        #expect(game.rounds.isEmpty)
    }

    @Test func aFinishedGameAcceptsNothing() {
        let game = playingGame()
        game.state = .finished
        var book = ledger()
        let applied = PendingRoundsDrain.apply([add(25, .team1, game: game.id)], to: game, ledger: &book)
        #expect(applied == 0)
        #expect(game.rounds.isEmpty)
    }

    @Test func nonPositivePointsAreIgnored() {
        let game = playingGame()
        var book = ledger()
        PendingRoundsDrain.apply([add(0, .team1, game: game.id), add(-5, .team2, game: game.id)], to: game, ledger: &book)
        #expect(game.rounds.isEmpty)
    }

    @Test func theLedgerForgetsOldIDsButKeepsRecentOnes() {
        let defaults = UserDefaults(suiteName: "ledger-\(UUID().uuidString)")!
        var book = AppliedRoundsLedger(defaults: defaults, limit: 3)
        let ids = (0..<4).map { _ in UUID() }
        book.record(ids)
        #expect(book.contains(ids[0]) == false)
        #expect(book.contains(ids[1]))
        #expect(book.contains(ids[3]))
    }

    @Test func theLedgerSurvivesANewInstanceOverTheSameDefaults() {
        let defaults = UserDefaults(suiteName: "ledger-\(UUID().uuidString)")!
        var book = AppliedRoundsLedger(defaults: defaults)
        let id = UUID()
        book.record([id])
        #expect(AppliedRoundsLedger(defaults: defaults).contains(id))
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: the test command with `-only-testing:iScoreTests/PendingRoundsDrainTests`.
Expected: FAIL — `cannot find 'PendingRoundsDrain' in scope`.

- [ ] **Step 3: Implement**

`AppliedRoundsLedger` stores `[String]` of UUID strings and keeps the **last** `limit`. `PendingRoundsDrain.apply` records an entry's id in the ledger when it is consumed — including entries skipped as no-ops for this game, so they are not retried forever — but **not** entries belonging to another game (another game's drain owns those). `apply` writes nothing to disk and takes no `ModelContext`: the caller (Task 8) saves.

Register `AppliedRoundsLedger.swift` with `iScore`, `iScoreWidgets` and `iScoreTests`; `PendingRoundsDrain.swift` with `iScore` and `iScoreTests` only (the widget must never touch `Game`).

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add iScore/Shared/AppliedRoundsLedger.swift iScore/Model/PendingRoundsDrain.swift iScoreTests/PendingRoundsDrainTests.swift iScore.xcodeproj
git commit -m "feat: drain pending rounds into SwiftData in order, exactly once"
```

---

### Task 4: The point grid

**Files:**
- Create: `iScore/Shared/PointGrid.swift`
- Create: `iScoreTests/PointGridTests.swift`

**Interfaces:**
- Consumes: `GameType`.
- Produces: `enum PointGrid { static let size = 6; static func defaults(for type: GameType) -> [Int]; static func values(for type: GameType, history: [Int], limit: Int = size) -> [Int] }` — history is every round value the user has recorded for that game type, most recent last. Values are **selected** by frequency (then by the type's default order as a tiebreak, then by value) and **displayed** sorted ascending, so buttons keep their positions between rounds and muscle memory holds.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct PointGridTests {

    @Test func defaultsAreSixValuesPerGameType() {
        #expect(PointGrid.defaults(for: .six).count == PointGrid.size)
        #expect(PointGrid.defaults(for: .nine).count == PointGrid.size)
        #expect(PointGrid.defaults(for: .six).allSatisfy { $0 > 0 && $0 % 5 == 0 })
        #expect(PointGrid.defaults(for: .nine).allSatisfy { $0 > 0 && $0 % 5 == 0 })
        #expect(PointGrid.defaults(for: .six) == PointGrid.defaults(for: .six).sorted())
        #expect(PointGrid.defaults(for: .nine) == PointGrid.defaults(for: .nine).sorted())
    }

    @Test func doubleNineRunsHigherThanDoubleSix() {
        let six = PointGrid.defaults(for: .six)
        let nine = PointGrid.defaults(for: .nine)
        #expect(nine.max()! > six.max()!)
    }

    @Test func noHistoryGivesTheDefaults() {
        #expect(PointGrid.values(for: .six, history: []) == PointGrid.defaults(for: .six))
    }

    @Test func aFrequentUnusualValueEarnsASlot() {
        let grid = PointGrid.values(for: .six, history: Array(repeating: 47, count: 20))
        #expect(grid.contains(47))
        #expect(grid.count == PointGrid.size)
        #expect(grid == grid.sorted())
    }

    @Test func aRareValueDoesNotDisplaceADefault() {
        let grid = PointGrid.values(for: .six, history: [47])
        #expect(grid == PointGrid.defaults(for: .six))
    }

    @Test func theGridIsAlwaysFullAndFreeOfDuplicates() {
        let grid = PointGrid.values(for: .nine, history: [30, 30, 30, 30, 30])
        #expect(grid.count == PointGrid.size)
        #expect(Set(grid).count == PointGrid.size)
    }

    @Test func garbageHistoryIsIgnored() {
        let grid = PointGrid.values(for: .six, history: [0, -5, 0, 0, 0, 0, 0, 0])
        #expect(grid == PointGrid.defaults(for: .six))
    }

    @Test func aSmallerLimitStillReturnsTheMostCommonValues() {
        let grid = PointGrid.values(for: .six, history: Array(repeating: 25, count: 10), limit: 3)
        #expect(grid.count == 3)
        #expect(grid.contains(25))
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: the test command with `-only-testing:iScoreTests/PointGridTests`.
Expected: FAIL — `cannot find 'PointGrid' in scope`.

- [ ] **Step 3: Implement**

Defaults: `.six` → `[5, 10, 15, 20, 25, 30]`, `.nine` → `[10, 20, 25, 30, 40, 50]`. Selection: count positive history values, score each candidate (history values plus the defaults) by `(count, -defaultIndex)`, take `limit`, sort ascending. A history value only displaces a default when its count beats that default's — the default's own baseline count is a small constant (2), which is what makes `aRareValueDoesNotDisplaceADefault` and `aFrequentUnusualValueEarnsASlot` both hold; pin that constant in a named `static let defaultWeight = 2`.

Register with `iScore`, `iScoreWidgets`, `iScoreTests`.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add iScore/Shared/PointGrid.swift iScoreTests/PointGridTests.swift iScore.xcodeproj
git commit -m "feat: per-game-type point grid re-ranked from history"
```

---

### Task 5: The activity's content state

**Files:**
- Create: `iScore/Shared/ScoreboardActivityAttributes.swift`
- Create: `iScoreTests/ScoreboardStateTests.swift`

**Interfaces:**
- Consumes: `PointGrid`, `TeamSide`, `GameType`, `Game`.
- Produces: `struct ScoreboardActivityAttributes: ActivityAttributes` with static `gameID: UUID`, `name1: String`, `name2: String`, `gameType: GameType`, `target: Int`, and `struct ContentState: Codable, Hashable { var total1: Int; var total2: Int; var recent: [Int]; var grid: [Int]; var requiresUnlock: Bool }` — `recent` is the last ≤12 round values signed by team (positive = team 1, negative = team 2), which is what makes optimistic undo possible without the store.
- Produces, as pure functions on `ContentState` (the part under test): `var roundNumber: Int`, `var leader: TeamSide?`, `func pointsToWin(_ side: TeamSide) -> Int` (needs the target, so these live on a small `ScoreboardState` struct carrying `target`), `func applyingRound(_ points: Int, for side: TeamSide) -> Self`, `func applyingUndo() -> Self`, `var canUndo: Bool`, and `static func make(from game: Game, grid: [Int], requiresUnlock: Bool) -> Self`.

To keep the ActivityKit type out of the test target, put the math in `struct ScoreboardState: Codable, Hashable` and make `ScoreboardActivityAttributes.ContentState = ScoreboardState` via a typealias. `ScoreboardState` is registered with all three targets; the `ActivityAttributes` wrapper only with the app and the widget.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct ScoreboardStateTests {

    private func state(_ t1: Int, _ t2: Int, recent: [Int] = [], target: Int = 200) -> ScoreboardState {
        ScoreboardState(target: target, total1: t1, total2: t2, recent: recent, grid: [10, 20, 25, 30, 40, 50], requiresUnlock: false)
    }

    @Test func roundNumberIsOneMoreThanRoundsPlayed() {
        #expect(state(0, 0).roundNumber == 1)
        #expect(state(55, 30, recent: [25, -30, 30]).roundNumber == 4)
    }

    @Test func leaderAndPointsToWin() {
        #expect(state(120, 80).leader == .team1)
        #expect(state(80, 120).leader == .team2)
        #expect(state(100, 100).leader == nil)
        #expect(state(120, 80).pointsToWin(.team1) == 80)
        #expect(state(120, 80).pointsToWin(.team2) == 120)
        #expect(state(220, 80).pointsToWin(.team1) == 0)
    }

    @Test func applyingARoundUpdatesTotalAndRecent() {
        let next = state(25, 0, recent: [25]).applyingRound(30, for: .team2)
        #expect(next.total1 == 25)
        #expect(next.total2 == 30)
        #expect(next.recent == [25, -30])
        #expect(next.roundNumber == 3)
    }

    @Test func applyingAnUndoReversesTheLastRound() {
        let next = state(25, 30, recent: [25, -30]).applyingUndo()
        #expect(next.total1 == 25)
        #expect(next.total2 == 0)
        #expect(next.recent == [25])
    }

    @Test func undoIsUnavailableWithNothingToTakeBack() {
        #expect(state(0, 0).canUndo == false)
        #expect(state(0, 0).applyingUndo() == state(0, 0))
        #expect(state(25, 0, recent: [25]).canUndo)
    }

    @Test func recentIsCappedButTotalsStayWhole() {
        var s = state(0, 0)
        for _ in 0..<15 { s = s.applyingRound(10, for: .team1) }
        #expect(s.total1 == 150)
        #expect(s.recent.count == ScoreboardState.recentLimit)
        // Undo past the cap stops changing totals rather than inventing rounds.
        #expect(s.recent.allSatisfy { $0 == 10 })
    }

    @Test func nonPositivePointsChangeNothing() {
        let s = state(25, 0, recent: [25])
        #expect(s.applyingRound(0, for: .team1) == s)
        #expect(s.applyingRound(-10, for: .team2) == s)
    }

    @Test func madeFromAGameItMatchesTheGame() {
        let game = Game(gameType: .nine, maxScore: 200)
        game.addRound(25, for: .team1)
        game.addRound(30, for: .team2)
        let s = ScoreboardState.make(from: game, grid: [10, 20, 25, 30, 40, 50], requiresUnlock: true)

        #expect(s.total1 == 25)
        #expect(s.total2 == 30)
        #expect(s.recent == [25, -30])
        #expect(s.target == 200)
        #expect(s.roundNumber == game.currentRoundNumber)
        #expect(s.leader == .team2)
        #expect(s.pointsToWin(.team2) == game.pointsToWin(for: .team2))
        #expect(s.requiresUnlock)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: the test command with `-only-testing:iScoreTests/ScoreboardStateTests`.
Expected: FAIL — `cannot find 'ScoreboardState' in scope`.

- [ ] **Step 3: Implement**

`ScoreboardState.recentLimit = 12`. `applyingUndo` pops the last `recent` entry and subtracts it from the matching total, clamped at 0; with `recent` empty it returns `self`. `make(from:)` takes the last `recentLimit` of `game.rounds` signed by team. Register `ScoreboardState` with all three targets, `ScoreboardActivityAttributes` with app + widget.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add iScore/Shared/ScoreboardActivityAttributes.swift iScoreTests/ScoreboardStateTests.swift iScore.xcodeproj
git commit -m "feat: Live Activity content state with optimistic round and undo"
```

---

### Task 6: App Intents and the deep-link fallback

**Files:**
- Create: `iScore/Shared/ScoreLink.swift`
- Create: `iScore/Shared/ScoreIntents.swift`
- Create: `iScoreTests/ScoreLinkTests.swift`

**Interfaces:**
- Consumes: `AppGroup`, `PendingRoundsStore`, `ScoreboardState`, `TeamSide`.
- Produces: `enum ScoreLink { static let scheme = "iscoredominoes"; static func record(gameID: UUID, points: Int, team: TeamSide) -> URL; static func undo(gameID: UUID) -> URL; static func other(gameID: UUID, team: TeamSide) -> URL; static func parse(_ url: URL) -> Action? }` with `enum Action: Equatable { case record(gameID: UUID, points: Int, team: TeamSide); case undo(gameID: UUID); case other(gameID: UUID, team: TeamSide) }`.
- Produces: `struct RecordRoundIntent: LiveActivityIntent` (`gameID: String`, `points: Int`, `team: String` parameters) and `struct UndoRoundIntent: LiveActivityIntent`, whose `perform()` appends to the store and returns `.result()`. The activity reload is driven from the app side (Task 8) plus the widget's own optimistic update (Task 7).

Intents must be `LiveActivityIntent` (not `AppIntent`) so they run in-process from the Lock Screen without launching the app. Their `perform()` is three lines; the substance is already tested in Tasks 2 and 5. What gets tested here is the URL vocabulary, which is what the unlock-required path and the "Other" button ride on.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct ScoreLinkTests {

    private let game = UUID()

    @Test func recordRoundTrips() throws {
        let url = ScoreLink.record(gameID: game, points: 25, team: .team2)
        #expect(url.scheme == ScoreLink.scheme)
        #expect(ScoreLink.parse(url) == .record(gameID: game, points: 25, team: .team2))
    }

    @Test func undoRoundTrips() {
        #expect(ScoreLink.parse(ScoreLink.undo(gameID: game)) == .undo(gameID: game))
    }

    // Review Focus 6
    @Test func otherOpensTheAppForAValueOffTheGrid() {
        let url = ScoreLink.other(gameID: game, team: .team1)
        #expect(ScoreLink.parse(url) == .other(gameID: game, team: .team1))
    }

    @Test func foreignOrMalformedURLsParseToNil() {
        #expect(ScoreLink.parse(URL(string: "https://example.com/record")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=notauuid&points=25&team=team1")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=\(game.uuidString)&points=0&team=team1")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://record?game=\(game.uuidString)&points=25&team=team9")!) == nil)
        #expect(ScoreLink.parse(URL(string: "iscoredominoes://wat?game=\(game.uuidString)")!) == nil)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: the test command with `-only-testing:iScoreTests/ScoreLinkTests`.
Expected: FAIL — `cannot find 'ScoreLink' in scope`.

- [ ] **Step 3: Implement, and register the URL scheme**

`ScoreLink` with `URLComponents`. Add `CFBundleURLTypes` for `iscoredominoes` to the app target — with `GENERATE_INFOPLIST_FILE = YES` this needs a real `Info.plist` fragment, so add `iScore/Info.plist` carrying only `CFBundleURLTypes` and point `INFOPLIST_FILE` at it from a new `scripts/xcodeproj.rb` step (`GENERATE_INFOPLIST_FILE` stays `YES`; Xcode merges the two). Verify after building with:

```bash
plutil -p "$(xcodebuild -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2}')/iScore.app/Info.plist" | grep -A5 CFBundleURLTypes
```

`ScoreIntents.swift` registers with `iScore` and `iScoreWidgets` (both processes must know the intent types); `ScoreLink.swift` with all three.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command, then the full suite. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add iScore/Shared/ScoreLink.swift iScore/Shared/ScoreIntents.swift iScore/Info.plist iScoreTests/ScoreLinkTests.swift scripts/xcodeproj.rb iScore.xcodeproj
git commit -m "feat: scoring intents and the iscoredominoes:// deep-link vocabulary"
```

---

### Task 7: The Live Activity itself

**Files:**
- Create: `iScoreWidgets/ScoreboardLiveActivity.swift`
- Create: `iScoreWidgets/ScoreboardLockScreenView.swift`
- Create: `iScoreWidgets/ScoreButton.swift`
- Modify: `iScoreWidgets/iScoreWidgetsBundle.swift` (real body)
- Delete: the placeholder widget from Task 1

**Interfaces:**
- Consumes: `ScoreboardActivityAttributes`, `ScoreboardState`, `RecordRoundIntent`, `UndoRoundIntent`, `ScoreLink`, `Theme`, `DuoFont`.
- Produces: the `ActivityConfiguration` — Lock Screen presentation and all four Dynamic Island regions.

**Layout, from the spec:**
- **Lock Screen / banner:** a header row with both team names and both totals (team colors, `DuoFont.score`), a line under it reading `Round N · M to win` for the leader, then **two rows of six point buttons** — one row per team, tinted `Theme.teamA` / `Theme.teamB` — then a bottom row with `Undo` and `Other…`. This is the presentation that must work on every iPhone; nothing scoring-related may be exclusive to the expanded island.
- **Dynamic Island compact:** leading = team 1 total in `Theme.teamA`, trailing = team 2 total in `Theme.teamB`. Nothing else, per the spec.
- **Minimal:** the leader's total in their color.
- **Expanded:** the same content as the Lock Screen view, reusing `ScoreboardLockScreenView`.

**Style notes:** Live Activity views render in the system's own context, so `.duo`/`.duoCard` (which assume the app's palette and pressed-edge animation) are not reused verbatim — `ScoreButton` is a small local view that reproduces the vocabulary: radius 14, flat team fill, 4pt darker bottom edge from the palette's `edge`, `Theme.surface` label in `DuoFont.label`. No gradients, shadows, blur or glass. Keep the whole Lock Screen presentation under the 160pt height budget; with 6 columns the buttons are tight, so size the grid with `GridRow`/`LazyVGrid` at `minimum: 40` and let numbers shrink with `.minimumScaleFactor(0.7)` rather than wrapping.

**Unlock toggle:** when `state.requiresUnlock` is true, every control renders as `Link(destination: ScoreLink.…)` instead of `Button(intent:)`; the visual result is identical. One `@ViewBuilder` branch, exercised by Task 9's test of the stored flag.

- [ ] **Step 1: Build and look at it**

There is no unit test for a widget view — the Swift Testing target cannot host WidgetKit previews — so verification here is visual and is done honestly rather than skipped:

```bash
xcodebuild build -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

- [ ] **Step 2: Write the views**

As above. Register each new file with `ruby scripts/xcodeproj.rb add iScoreWidgets <path>` and remove the Task 1 placeholder with `ruby scripts/xcodeproj.rb remove <path>`.

- [ ] **Step 3: See it on the Lock Screen**

Task 8 provides the app-side start, so a full visual check lands at the end of Task 8. Here, confirm the build produces the appex and that `#Preview` entries for `ScoreboardLockScreenView` (with `.previewContext(WidgetPreviewContext(family: .systemMedium))` equivalents for activities: `ScoreboardActivityAttributes.preview.previewContext(state, viewKind: .content)`) render in Xcode's canvas, and that the compact island preview shows exactly two numbers.

- [ ] **Step 4: Run the full suite**

Expected: PASS, unchanged count — a widget target that fails to compile breaks the app build, so this is the real check that nothing regressed.

- [ ] **Step 5: Commit**

```bash
git add iScoreWidgets iScore.xcodeproj
git commit -m "feat: Lock Screen scoreboard activity with per-team point grid"
```

---

### Task 8: App-side wiring — start, drain, refresh, deep links

**Files:**
- Create: `iScore/Model/ScoreActivityController.swift`
- Create: `iScore/Model/GameHistory.swift`
- Create: `iScoreTests/GameHistoryTests.swift`
- Modify: `iScore/Views/GameView.swift`, `iScore/iScoreApp.swift`, `iScore/Views/HomeView.swift`

**Interfaces:**
- Produces: `enum GameHistory { static func roundValues(in games: [Game], type: GameType) -> [Int] }` — every round value the user has recorded for that game type, oldest first, feeding `PointGrid.values`. Pure and tested.
- Produces: `@MainActor @Observable final class ScoreActivityController` with `func start(for game: Game, history: [Int]) async`, `func refresh(_ game: Game) async`, `func end(_ game: Game) async`, and `@discardableResult func drain(into game: Game, context: ModelContext) -> Int` (reads the store, calls `PendingRoundsDrain.apply`, saves the context, then `refresh`). Not unit-tested directly — it is ActivityKit plumbing; everything it decides is already covered.

**Wiring:**
- `GameView.task`: drain, then `start` if `game.state == .playing` and no activity is running for this id.
- `GameView` `.onChange(of: scenePhase)` → `.active`: drain. Same on `HomeView` (the user may have scored from the Lock Screen while the app was backgrounded on Home).
- Every in-app score change (`addRound`, undo, edit, delete) already runs through `GameView`; add a `refresh` after each so the Lock Screen matches the app immediately.
- Game finished, cancelled, or deleted → `end` the activity (Review Focus 5). A game that reaches its target during a drain ends the activity with a final content state rather than accepting another tap.
- `iScoreApp`: `.onOpenURL` parses `ScoreLink.Action` and routes — `.record` applies it directly and saves; `.undo` likewise; `.other` navigates to that game and opens the Add Score sheet for the named team.
- Activity push updates are not used; `Activity.update(_:)` from the app and the widget's own optimistic reload are enough, and nothing in this feature touches the network.

- [ ] **Step 1: Write the failing tests** (for the pure part)

```swift
import Foundation
import Testing
@testable import iScore

struct GameHistoryTests {

    private func game(_ type: GameType, rounds: [(Int, Team)]) -> Game {
        let g = Game(gameType: type, maxScore: type == .six ? 100 : 200)
        for (points, team) in rounds { g.addRound(points, for: team) }
        return g
    }

    @Test func collectsEveryRoundValueForTheType() {
        let games = [
            game(.nine, rounds: [(25, .team1), (30, .team2)]),
            game(.nine, rounds: [(25, .team2)]),
            game(.six, rounds: [(15, .team1)])
        ]
        #expect(GameHistory.roundValues(in: games, type: .nine) == [25, 30, 25])
        #expect(GameHistory.roundValues(in: games, type: .six) == [15])
    }

    @Test func noGamesGivesNoHistory() {
        #expect(GameHistory.roundValues(in: [], type: .six).isEmpty)
    }

    @Test func theSeedRowIsNotARound() {
        #expect(GameHistory.roundValues(in: [game(.six, rounds: [])], type: .six).isEmpty)
    }

    @Test func historyFeedsTheGrid() {
        let games = Array(repeating: game(.six, rounds: [(47, .team1)]), count: 20)
        let grid = PointGrid.values(for: .six, history: GameHistory.roundValues(in: games, type: .six))
        #expect(grid.contains(47))
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: the test command with `-only-testing:iScoreTests/GameHistoryTests`.
Expected: FAIL — `cannot find 'GameHistory' in scope`.

- [ ] **Step 3: Implement `GameHistory`, `ScoreActivityController`, and the view wiring**

Register `GameHistory.swift` and `ScoreActivityController.swift` with `iScore` (and `GameHistory` with `iScoreTests`). Keep `GameView`'s additions to a handful of lines: one `.task`, one `.onChange(of: scenePhase)`, one `refresh` call per existing mutation site.

- [ ] **Step 4: Run to verify they pass, then see it end to end**

Run: the Step 2 command, then the full suite.

Then, on the simulator:
```bash
xcrun simctl boot "iPhone 17 Pro" ; open -a Simulator
```
Install the app, start a game, background it, lock the simulator (`Device ▸ Lock`), and confirm: the activity appears, a point button records a round, the totals move, undo takes one back, and reopening the app shows exactly the same score. Record what was seen in the commit message.

- [ ] **Step 5: Commit**

```bash
git add iScore/Model/GameHistory.swift iScore/Model/ScoreActivityController.swift iScore/Views/GameView.swift iScore/Views/HomeView.swift iScore/iScoreApp.swift iScoreTests/GameHistoryTests.swift iScore.xcodeproj
git commit -m "feat: start, refresh and drain the Lock Screen activity from the app"
```

---

### Task 9: The "Require unlock to score from Lock Screen" toggle

**Files:**
- Create: `iScore/Shared/LockScreenScoring.swift`
- Create: `iScoreTests/LockScreenScoringTests.swift`
- Modify: `iScore/Views/SettingsView.swift`

**Interfaces:**
- Produces: `enum LockScreenScoring { static let requireUnlockKey = "requireUnlockToScore"; static func requiresUnlock(_ defaults: UserDefaults) -> Bool }` — **off** by default, read from the App Group suite so the widget sees the same value, and surfaced in `SettingsView` with `@AppStorage(LockScreenScoring.requireUnlockKey, store: AppGroup.defaults)`.
- The flag rides into the activity on `ScoreboardState.requiresUnlock` (Task 5), so a change in Settings takes effect on the next `refresh`; `SettingsView`'s toggle calls `refresh` for the in-progress game, if any.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import iScore

struct LockScreenScoringTests {

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "lock-\(UUID().uuidString)")!
    }

    // Review Focus 7
    @Test func unlockIsNotRequiredByDefault() {
        #expect(LockScreenScoring.requiresUnlock(defaults()) == false)
    }

    @Test func theToggleIsReadBack() {
        let store = defaults()
        store.set(true, forKey: LockScreenScoring.requireUnlockKey)
        #expect(LockScreenScoring.requiresUnlock(store))
        store.set(false, forKey: LockScreenScoring.requireUnlockKey)
        #expect(LockScreenScoring.requiresUnlock(store) == false)
    }

    @Test func theFlagReachesTheActivityState() {
        let game = Game(gameType: .six, maxScore: 100)
        let on = ScoreboardState.make(from: game, grid: PointGrid.defaults(for: .six), requiresUnlock: true)
        let off = ScoreboardState.make(from: game, grid: PointGrid.defaults(for: .six), requiresUnlock: false)
        #expect(on.requiresUnlock)
        #expect(off.requiresUnlock == false)
        #expect(on != off)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: the test command with `-only-testing:iScoreTests/LockScreenScoringTests`.
Expected: FAIL — `cannot find 'LockScreenScoring' in scope`.

- [ ] **Step 3: Implement, and add the Settings row**

A new "Lock Screen" section in `SettingsView`, above "About", in the existing `.duoCard` idiom: a `Toggle` row with `Theme.teamB` tint, title "Require unlock to score", and a `Theme.textSecondary` footnote — "Lock Screen buttons will open the app instead of scoring straight away." Register the file with all three targets.

- [ ] **Step 4: Run to verify they pass**

Run: the Step 2 command. Expected: PASS.

Then on the simulator: turn the toggle on, lock the device, tap a point button, and confirm it asks to unlock and lands on that game's Add Score sheet rather than scoring silently.

- [ ] **Step 5: Commit**

```bash
git add iScore/Shared/LockScreenScoring.swift iScore/Views/SettingsView.swift iScoreTests/LockScreenScoringTests.swift iScore.xcodeproj
git commit -m "feat: Settings toggle to require unlock before Lock Screen scoring"
```

---

### Task 10: Full-game verification and documentation

**Files:**
- Modify: `CLAUDE.md` (new target, new `iScore/Shared/` folder, the single-owner rule, `setup-widget`)
- Modify: `docs/superpowers/specs/2026-10-17-hands-free-dominoes-design.md` (mark Feature 2 built, if the spec tracks status per feature)

- [ ] **Step 1: Run the whole suite**

`xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
Expected: PASS — the 188 existing tests plus everything added here, with no `-only-testing` filter.

- [ ] **Step 2: Play a whole game from the Lock Screen**

The spec's "done looks like", performed and reported honestly, on a **non-Pro** simulator (iPhone 17, no Dynamic Island) to prove the grid is not island-only:

1. Start a Double-9 game to 200 with four named players.
2. Background and lock the device.
3. Score at least eight rounds for both teams entirely from the Lock Screen, using grid values only, including one undo.
4. Keep a tally by hand.
5. Unlock, open the app, and compare: the in-app totals, round count, and per-round values must match the tally exactly.
6. Repeat once with the app **force-quit** before locking, to prove the drain picks up rounds the app never saw live.

- [ ] **Step 3: Update `CLAUDE.md`**

Add: the `iScoreWidgets` target and what may and may not go in it (never SwiftData, never CloudKit); `iScore/Shared/` as the three-target folder; `ruby scripts/xcodeproj.rb setup-widget`; the rule that a shared file must be registered against each target; and the pinned-OS test destination.

- [ ] **Step 4: Commit and open the PR**

```bash
git add CLAUDE.md docs/superpowers
git commit -m "docs: record the widget target and the single-owner scoring rule"
git push -u origin lock-screen-scoreboard
gh pr create --title "Lock Screen scoreboard with live score entry" --body "…"
```

The PR body states what was verified on device/simulator and what was not, and repeats that the App Group capability must be enabled in the Apple Developer portal for both bundle ids before a real-device build.
