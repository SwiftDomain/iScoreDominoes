# iScoreDominoes

2v2 domino game scoring app. SwiftUI + SwiftData. Supports Double-6 and Double-9 game types.

## Project path

`/Users/beastmode/Documents/GitHub/iScoreDominoes`

## Structure

- `iScore/Model/` — `Game.swift` (core model + enums), `Player.swift`, `Theme.swift` (semantic colors, team palettes, `DuoFont`), `Config.swift` (`Background`), `Tip.swift`, and pure, tested logic: `Game+Scoreboard` (totals, rounds, undo, Duo copy), `Game+Editing` (edit/delete rounds, outcomes, `deleteGameKeepingPlayers`), `GameSetup` (targets, `GameDefaults`, `PlayerLineup`, `PlayerName`), `GameList` (filters, month sections), `Leaderboard`, `ScoreEntry` (keypad entry), `PlayStreak` (day streak), `DemoData` (sample games; Debug `-demoData` launch argument)
- `iScore/Views/` screens — `HomeView`, `GameView`, `AddGameScoreView`, `EditScoreView`, `NewGameView` (+ `NewPlayerView` picker), `GamesView`, `HallOfFameView`, `SettingsView`, `GameSummaryView`, `InfoView` (`CollectionView`, How to play)
- `iScore/Views/` Duo components — `DuoStyle` (`.duo` buttons; `.duoCard`, `.duoKey`, `.duoChoice` card styles; `duoCard`/`duoSolid`/`duoLabel` modifiers), `DuoProgressBar`, `TeamAvatars`/`PlayerAvatar`, `TeamScoreCard`, `TeamSeatsCard`, `RoundRow`, `RoundFeedbackBanner`, `ScoreKeypad`, `ScoreWell`, `TeamSpeechBubble`, `SheetHeader`, `GameTypePicker`, `TargetStepper`, `SearchWell`, `StatusChip`, `GameListCard`, `PodiumView`, `SummaryStatTile`, `TrophyBurst`, `DominoGlyph`, `ActiveGameBanner`, `HomeCardView`, `RecentGameCard`, `QuickStatsBar`; plus `Previewer`
- `iScoreApp.swift` — Entry point, SwiftData ModelContainer
- `iScoreTests/` — Swift Testing target; `scripts/xcodeproj.rb` — registers files in the Xcode project

## Theme ("Duo")

Duolingo-inspired: white canvas, rounded gray text, green team 1, blue team 2, pressable buttons. Fixed light palette; `.preferredColorScheme(.light)` and `.fontDesign(.rounded)` are set at the app root. All colors are semantic via `Theme` (`iScore/Model/Theme.swift`) backed by colorsets in `Assets.xcassets` — never hardcode `Color` literals in views. `ThemeTests` checks every name in `Theme.colorAssetNames` exists; add new colorsets there. Full spec: `docs/superpowers/specs/2026-10-16-duolingo-redesign-design.md`.

- `background`/`surface` `#FFFFFF` · `surfaceSecondary` `#F7F7F7` wells · `divider` `#E5E5E5` borders and bottom edges
- `textPrimary` `#4B4B4B` · `textSecondary` `#777777` informational text (uppercase labels via `duoLabel()`, counts, dates, "to win") · `textMuted` `#AFAFAF` only for icons, placeholders and disabled titles. Both grays have Increase Contrast variants (`#595959`, `#767676`)
- Team 1: `teamA` `#58CC02` / `teamAShadow` `#58A700` / `teamAWash` `#D7FFB8` (also `accent`, `accentInk` = shadow)
- Team 2: `teamB` `#1CB0F6` / `teamBShadow` `#1899D6` / `teamBWash` `#DDF4FF`
- Accents: `gold` `#FFC800` (leader, trophies) · `streak` `#FF9600` · `learn` `#CE82FF` — each has a `…Shadow` edge color · `danger` `#FF4B4B` (destructive text)
- Use `Theme.palette(for: Team)` for team-colored UI; text on any saturated fill is `Theme.surface` (white)
- Type: `DuoFont.score(_:)` (.black) for numbers, `.title` (.heavy), `.body` (.bold), `.label` (.heavy, uppercase, tracking 0.8)
- Shape: cards radius 16 with 2pt border + 4pt bottom edge (`.duoCard`); buttons radius 14 with 4pt darker bottom edge (`.duo`); keypad keys are white cards with the button shape (`.duoKey`: radius 14, 4pt press drop); no gradients, shadows, blur or glass on Duo screens

## Data model

- `Game` — `@Model` with `gameType` (six/nine), `maxScore`, `scoreTeam: [[Int]]`, `team1/team2: [String]`, `players: [Player]` relationship, `state` (playing/finished/cancelled), `inProcess` flag
- `Player` — `@Model` with `name`, `gamesPlayed`, `gamesWon`, `winPercentage`, inverse relationship to `Game`
- Score tracking: `scoreTeam` is an array of `[team1Score, team2Score]` pairs per round; totals are computed properties

## Lock Screen scoreboard (`iScoreWidgets`)

A Widget Extension target hosts a Live Activity: a top line on the app's green, the rest on white. Both
totals, the round number, points to win for the leader, each team's score for
the latest six rounds (display only, not buttons), and a mic button ("Say a score" to VoiceOver).
The mic is a link (`iscoredominoes://voice`) — a widget cannot use the
microphone — so iOS asks for the unlock and the app opens on that game already
listening. Tapping anywhere else opens the app. Created and maintained by
`ruby scripts/xcodeproj.rb setup-widget` — never hand-edit `project.pbxproj`.

- **The app is the single owner of the store.** The widget process must never
  link SwiftData or CloudKit. No Lock Screen control scores today, but the
  scoring path stays for links from earlier versions: a `LiveActivityIntent`
  (or link) appends to `pending-rounds.jsonl` in the App Group
  (`group.SwiftDomainUI.iScore`) and updates the activity optimistically; the
  app drains that file into SwiftData on foreground, in file order and
  exactly once (`PendingRoundsDrain` plus `AppliedRoundsLedger`).
- `iScore/Shared/` holds the types both processes compile. A shared file must
  be registered against **each** target: `add iScore`, `add iScoreWidgets`,
  `add iScoreTests`. Anything touching `Game` stays out of it.
- Two build-system traps, both silent until install fails: an `.appex` needs a
  real `Info.plist` (`INFOPLIST_KEY_NSExtensionPointIdentifier` generates
  nothing) and version keys. `CFBundleURLTypes` and `NSSupportsLiveActivities`
  likewise come from `iScore/Info.plist`, merged with the generated one.
- The Lock Screen gives an activity roughly 160pt; past that the header and
  the mic row are clipped. Check a change on a real Lock Screen, not only in
  the expanded Dynamic Island.

## Voice scoring

A push-to-talk mic scores a round by voice: on the Game screen, and in the Add
Score sheet where the team is already known. It is **push-to-talk only** — no
always-listening, no wake phrase. A tap is the single thing that starts the
recognizer — the Lock Screen mic counts as that tap: `ScoreLinkRouter` carries
it to the game and `VoiceScoreBar(listenRequested:)` starts once the app is
active; it ends on a second tap, when the recognizer ends itself, on
`onDisappear`, or on any scene phase that is not `.active`. A locked or
backgrounded phone never keeps the mic open, and coming back does not restart
it. The keypad is never closed: when speech is denied or unsupported the mic
stays **visible and disabled** with a one-line reason, so the touch door and the
voice door are equals.

- **The layers are pure, and only one of them has a mic.** `ScoreCommand`
  (`iScore/Model/ScoreCommand.swift`) is the only place that reads words; it
  turns a transcript into a command. `VoiceScoring`
  (`iScore/Model/VoiceScoring.swift`) decides what that command does given
  `Permissions`, and **never sees a `Game`** — anything it needs arrives as a
  field on `Permissions` or `Answers`. `Game+Voice.swift` holds the spoken
  answer copy and the `ScoreContext`. `VoiceScoreBar`
  (`iScore/Views/VoiceScoreBar.swift`) is the only microphone in the app for
  scoring; a third screen that wants voice **embeds the bar** rather than
  growing its own recognizer.
- **Team reference precedence**, in `ScoreCommand.team(in:locale:context:)`: an
  explicit player name beats a team name or colour, which beats "us", which
  beats "them". "Us"/"them" resolve through the owner's seat; when the owner is
  not seated they fall back to team 1 / team 2 by seat order. A number with no
  team is never guessed — it becomes `.askTeam`, and the two team buttons finish
  the sentence by touch.
- **Silent mode is honored by the audio session category, not by detection.**
  `SpokenReply` speaks on `.ambient`, which the Ring/Silent switch silences.
  There is no silent-switch detection code and none should be added.
- **The bar speaks `.said` and `.refused` itself**, so a host must not add a
  second synthesizer; a host only shows the same line on screen. **Both hosts
  pass `showsText: false`**: the bar is the mic button alone and reports a
  `VoiceBarState.Report` through `onPrompt`, because three flexible things in
  one row leave the prompt about 48pt and it wraps a syllable per line. The
  Game screen prints that line full width above the row; the Add Score sheet
  prints it in a fixed 48pt band below the mic, reserved so the keypad cannot
  shift mid-entry. `showsText` and `onPrompt` have **no defaults** — the
  draw-in-place layout has no call site today and needs a host wide enough for
  prose, so a new host must choose it deliberately. A host shows a spoken
  answer over the mic's idle state, and `Report.isLive` over both: a session
  under way clears the last answer, so it can never blank `Listening…`.
- `GameCommand` (spoken game setup) and `ScoreCommand` are deliberately separate
  parsers with separate stop words: "nine" is a game type in one and a round
  value in the other. Do not merge them.
- Every line the user can see **or hear** goes through `String(localized:)`.

## Live spectate

The scorekeeper taps Share on the Game screen and reads a 4-character code to
the table; the others tap **Watch a game** on Home and follow the score,
read-only, over MultipeerConnectivity (Wi-Fi/Bluetooth, encryption required,
no internet).

- **Four pure types hold every decision**, all in `iScore/Model/`: `JoinCode`
  (alphabet without 0/O/1/I), `SpectateSnapshot` (the whole game on every
  change, validated on arrival — oversize, wrong version or an implausible shape
  is ignored), `SpectateGuest` (connection phase reducer, plus `SpectateSave`)
  and `SpectatePolicy` (who is let in, which game goes out). `SpectateLink`
  only moves bytes; a new rule goes in a pure type with a test, not in the link.
- **Guests render a detached `Game`** (`SpectateSnapshot.makeDetachedGame()`),
  never inserted into a context, so the scoreboard is the scorekeeper's own
  code and nothing reaches the guest's store.
- **A guest writes exactly once**: "Save to my games" after a *finished* game,
  refused when the same game is already there (iCloud, or a second tap).
- **Guest screens have no keypad, undo, edit or mic** — absent, not disabled.
- **Sharing outlives the Game screen.** `iScoreApp` owns one
  `SpectateHostLink`. Every place that keeps the Live Activity in step also
  calls `publish` (GameView's three hooks and Home's Lock Screen drain). The
  policy sends the shared game and any game being played, never an old one.
- **Both phones stay awake while it matters**: the host while sharing (a
  locked scorekeeper drops every guest), the guest while watching. Advertising
  restarts when the host comes back to the foreground. Neither touches the idle
  timer directly: each holds a reason in `ScreenAwake`, the only owner.
- A killed or out-of-range host takes Multipeer roughly 10 seconds to notice;
  until then the guest still reads Live.

## Game presets

A preset is a saved setup ("Friday night": Double 9, 200, the usual four),
started with one tap from Home, by saying its name, or edited in Settings; a
finished game offers "Save this setup".

- **`GamePreset` only stores**; every rule runs on the value `PresetSetup`
  (`iScore/Model/GamePreset.swift`), so tests need no store. Players are kept
  as names (no relationship, CloudKit-safe) and matched to saved players with
  `PlayerName` when the preset starts; a deleted player is created again.
- **Voice checks preset names first**, in `VoiceSetup.resolve`, through
  `PresetMatcher`: a match is the name plus filler words only, never a
  substring, so a description that mentions a preset's name stays free-form.
- **Home shows three** (`PresetList.homeRow`): one card per name — two devices
  can save the same name before syncing; the oldest wins and Settings marks
  the other "Duplicate name" — ordered by last used.

## Table mode

For the phone lying face-up in the middle of the table: two big halves, team
2's turned 180° to face the other side, each half one tap from its keypad.
Turned on from the Game screen's "…" menu; Settings can make it the default.

- **`ScreenAwake` is the only owner of the idle timer** (`iScore/Model/ScreenAwake.swift`).
  Sharing, watching and table mode each hold a reason; nothing else sets
  `isIdleTimerDisabled`. Table mode's reason is keyed by game, so the next
  game's screen setting it is never undone by the old screen going away.
- **`TableModeSession`** (app-level, seeded from `TableModeSettings.defaultKey`)
  keeps table mode on for the night, so the next game opens the same way.
- **`DuoFont.tableScore`** is its own font, sized by `tableScoreSize(forHalf:digits:)`
  to fit the half; `DuoFont.score` and the other screens are untouched.
- **Leaving table mode restores the Game screen exactly** because table mode is
  a separate branch in `GameView.body` (`TableModeView`), not a modified copy;
  every sheet and alert stays attached to `GameView`, so the keypad, summary
  and undo confirmation work in both.

## Round drama

After a new round the app may call out one big moment — capicúa, the night's
biggest round, a comeback, and on a finished game a zapato (shutout), a
comeback win, a last-round win or a win streak.

- **`GameDrama` decides everything** (`iScore/Model/GameDrama.swift`), pure and
  tested: zero highlights most of the time, one at most, ranked, and never
  the same kind twice in a game (`GameView.shownDrama`; undo does not reset
  it). Copy is in `Game+Drama.swift`. Thresholds live there as constants.
- **It never blocks score entry**: the round banner keeps its 2-second life
  and its Undo; a finished game's highlight goes on the summary sheet.
- **Capicúa is input, not data**: the Add Score toggle or the spoken word sets
  it for the round being entered; nothing is persisted.
- **Spoken through the mic bar** (`VoiceScoreBar(announcement:)`), the only
  synthesizer, in the voice language, after the mic is free.
- Edit Score never asks for a highlight. Settings → "Call out big moments"
  (`DramaSettings`) turns it all off.

## Night recap

After two or more games with the same group, the Game Summary offers a
"Night recap" card — standings, each pair's record, the biggest round, the
longest streak — rendered at 2x and shared as an image.

- **`NightRecap` decides everything** (`iScore/Model/NightRecap.swift`), pure
  and tested. A night is inferred, never stored: finished games on the same
  calendar day sharing at least 3 players (`PlayerName.isSame`) with any game
  already in the night, so every summary of the night shows the same card.
- **The card is built for a chat thumbnail**: big numerals, few words, Duo
  parts only (`NightRecapCard`). `NightRecap.appStoreURL` is nil until the app
  has an App Store id; the share text links it only when set.

## Known technical debt

- Navigation mixes `NavigationLink(destination:)` (Home tiles, All Games, New Game) with `navigationDestination(for: Game.self)` (Home) — move to value-based links
- `Game.players` has a cascade delete rule although players are shared between games; always delete games with `ModelContext.deleteGameKeepingPlayers`
- Button images missing text labels (accessibility issue) — re-check after the Duo restyle

## Active plan

See `docs/superpowers/plans/2026-10-16-duolingo-redesign.md` (Home, Game, Add Score) and the spec's "Remaining screens" section (New Game, All Games, Hall of Fame, Settings, Edit Score, Game Summary, How to Play — all restyled).

String Catalogs are stored in Xcode's own JSON format through a git filter (`.gitattributes`, `scripts/xcstrings-format.swift`), so Xcode rewriting them is not a change. Run `sh scripts/setup-git.sh` once per clone. A script that edits a catalog writes ordinary JSON; pipe the result through the filter (or `git add` it) so the file on disk matches.

New or deleted Swift files must be registered with `ruby scripts/xcodeproj.rb add|remove` (classic Xcode groups). Tests: Swift Testing target `iScoreTests`, run with `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`. Debug builds launched with `-demoData` use an in-memory store with sample games and players.
