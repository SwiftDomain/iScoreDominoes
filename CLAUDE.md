# iScoreDominoes

2v2 domino game scoring app. SwiftUI + SwiftData. Supports Double-6 and Double-9 game types.

## Project path

`/Users/beastmode/Documents/GitHub/iScoreDominoes`

## Structure

- `iScore/Model/` — `Game.swift` (core model + enums), `Player.swift`, `Theme.swift` (semantic colors, `DuoFont`), `Config.swift` (`Background`), and pure, tested logic: `Game+Scoreboard` (totals, rounds, copy), `Game+Editing` (edit/delete rounds, outcomes, `deleteGameKeepingPlayers`), `GameSetup` (targets, `GameDefaults`, `PlayerLineup`, `PlayerName`), `GameList` (filters, month sections), `Leaderboard`, `ScoreEntry`, `PlayStreak`, `DemoData`
- `iScore/Views/` — screens: `HomeView`, `GameView`, `AddGameScoreView`, `EditScoreView`, `NewGameView` (+ `NewPlayerView` picker), `GamesView`, `HallOfFameView`, `SettingsView`, `GameSummaryView`, `InfoView` (`CollectionView`, How to play). Shared Duo pieces: `DuoStyle` (`.duo`, `.duoCard`, `.duoChoice`), `DuoProgressBar`, `TeamAvatars`/`PlayerAvatar`, `SheetHeader`, `ScoreKeypad`, `ScoreWell`, `TeamSpeechBubble`, `GameTypePicker`, `TargetStepper`, `SearchWell`, `StatusChip`, `RoundRow`
- `iScoreApp.swift` — Entry point, SwiftData ModelContainer

## Theme ("Duo")

Duolingo-inspired: white canvas, rounded gray text, green team 1, blue team 2, pressable buttons. Fixed light palette; `.preferredColorScheme(.light)` and `.fontDesign(.rounded)` are set at the app root. All colors are semantic via `Theme` (`iScore/Model/Theme.swift`) backed by colorsets in `Assets.xcassets` — never hardcode `Color` literals in views. `ThemeTests` checks every name in `Theme.colorAssetNames` exists; add new colorsets there. Full spec: `docs/superpowers/specs/2026-10-16-duolingo-redesign-design.md`.

- `background`/`surface` `#FFFFFF` · `surfaceSecondary` `#F7F7F7` wells · `divider` `#E5E5E5` borders and bottom edges
- `textPrimary` `#4B4B4B` · `textSecondary` `#777777` · `textMuted` `#AFAFAF` labels and toolbar icons
- Team 1: `teamA` `#58CC02` / `teamAShadow` `#58A700` / `teamAWash` `#D7FFB8` (also `accent`, `success`, `accentInk` = shadow)
- Team 2: `teamB` `#1CB0F6` / `teamBShadow` `#1899D6` / `teamBWash` `#DDF4FF`
- Accents: `gold` `#FFC800` (leader, trophies) · `streak` `#FF9600` · `learn` `#CE82FF` · `danger` `#FF4B4B` — each has a `…Shadow` edge color
- Use `Theme.palette(for: Team)` for team-colored UI; text on any saturated fill is `Theme.surface` (white)
- Type: `DuoFont.score(_:)` (.black) for numbers, `.title` (.heavy), `.body` (.bold), `.label` (.heavy, uppercase, tracking 0.8)
- Shape: cards radius 16 with 2pt border + 4pt bottom edge; buttons/keys radius 14 with 4pt darker bottom edge; no gradients, shadows, blur or glass on Duo screens

## Data model

- `Game` — `@Model` with `gameType` (six/nine), `maxScore`, `scoreTeam: [[Int]]`, `team1/team2: [String]`, `players: [Player]` relationship, `state` (playing/finished/cancelled), `inProcess` flag
- `Player` — `@Model` with `name`, `gamesPlayed`, `gamesWon`, `winPercentage`, inverse relationship to `Game`
- Score tracking: `scoreTeam` is an array of `[team1Score, team2Score]` pairs per round; totals are computed properties

## Known technical debt

- Navigation mixes `NavigationLink(destination:)` (Home tiles, All Games, New Game) with `navigationDestination(for: Game.self)` (Home) — move to value-based links
- `Glass.swift`, `Twirl` (`Config.swift`) and `Game.printPlayers()` are unused
- `Game.players` has a cascade delete rule although players are shared between games; always delete games with `ModelContext.deleteGameKeepingPlayers`

## Active plan

See `docs/superpowers/plans/2026-10-16-duolingo-redesign.md` (Home, Game, Add Score) and the spec's "Remaining screens" section (New Game, All Games, Hall of Fame, Settings, Edit Score, Game Summary, How to Play — all restyled).

New or deleted Swift files must be registered with `ruby scripts/xcodeproj.rb add|remove` (classic Xcode groups). Tests: Swift Testing target `iScoreTests`, run with `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`. Debug builds launched with `-demoData` use an in-memory store with sample games and players.
