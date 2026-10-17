# iScoreDominoes

2v2 domino game scoring app. SwiftUI + SwiftData. Supports Double-6 and Double-9 game types.

## Project path

`/Users/beastmode/Documents/GitHub/iScoreDominoes`

## Structure

- `iScore/Model/` — `Game.swift` (core model + enums), `Game+Scoreboard.swift` (totals, rounds, undo, Duo copy), `Player.swift`, `ScoreEntry.swift` (keypad entry), `PlayStreak.swift` (day streak), `DemoData.swift` (sample games; Debug `-demoData` launch argument), `Config.swift` (Background, shapes, cell views), `Theme.swift` (semantic colors, team palettes, `DuoFont`), `Tip.swift`
- `iScore/Views/` screens — `HomeView`, `GameView`, `AddGameScoreView` (Duo redesign), `GamesView`, `NewGameView`, `EditScoreView`, `GameSummaryView`, `HallOfFameView`, `NewPlayerView`, `SettingsView`, `InfoView`
- `iScore/Views/` Duo components — `DuoStyle` (`.duo` buttons, `.duoCard`/`.duoKey` styles, `duoCard`/`duoSolid`/`duoLabel` modifiers), `DuoProgressBar`, `TeamAvatars`, `TeamScoreCard`, `RoundRow`, `RoundFeedbackBanner`, `ScoreKeypad`, `ActiveGameBanner`, `HomeCardView`, `RecentGameCard`, `QuickStatsBar`; plus `Glass`, `Previewer`
- `iScoreApp.swift` — Entry point, SwiftData ModelContainer
- `iScoreTests/` — Swift Testing target; `scripts/xcodeproj.rb` — registers files in the Xcode project

## Theme ("Duo")

Duolingo-inspired: white canvas, rounded gray text, green team 1, blue team 2, pressable buttons. Fixed light palette; `.preferredColorScheme(.light)` and `.fontDesign(.rounded)` are set at the app root. All colors are semantic via `Theme` (`iScore/Model/Theme.swift`) backed by colorsets in `Assets.xcassets` — never hardcode `Color` literals in views. `ThemeTests` checks every name in `Theme.colorAssetNames` exists; add new colorsets there. Full spec: `docs/superpowers/specs/2026-10-16-duolingo-redesign-design.md`.

- `background`/`surface` `#FFFFFF` · `surfaceSecondary` `#F7F7F7` wells · `divider` `#E5E5E5` borders and bottom edges
- `textPrimary` `#4B4B4B` · `textSecondary` `#777777` informational text (counts, dates, "to win") · `textMuted` `#AFAFAF` only for uppercase labels, icons, placeholders and disabled titles. Both grays have Increase Contrast variants (`#595959`, `#767676`)
- Team 1: `teamA` `#58CC02` / `teamAShadow` `#58A700` / `teamAWash` `#D7FFB8` (also `accent`, `success`, `accentInk` = shadow)
- Team 2: `teamB` `#1CB0F6` / `teamBShadow` `#1899D6` / `teamBWash` `#DDF4FF`
- Accents: `gold` `#FFC800` (leader, trophies) · `streak` `#FF9600` · `learn` `#CE82FF` · `danger` `#FF4B4B` — each has a `…Shadow` edge color
- Use `Theme.palette(for: Team)` for team-colored UI; text on any saturated fill is `Theme.surface` (white)
- Type: `DuoFont.score(_:)` (.black) for numbers, `.title` (.heavy), `.body` (.bold), `.label` (.heavy, uppercase, tracking 0.8)
- Shape: cards radius 16 with 2pt border + 4pt bottom edge (`.duoCard`); buttons radius 14 with 4pt darker bottom edge (`.duo`); keypad keys are white cards with the button shape (`.duoKey`: radius 14, 4pt press drop); no gradients, shadows, blur or glass on Duo screens

## Data model

- `Game` — `@Model` with `gameType` (six/nine), `maxScore`, `scoreTeam: [[Int]]`, `team1/team2: [String]`, `players: [Player]` relationship, `state` (playing/finished/cancelled), `inProcess` flag
- `Player` — `@Model` with `name`, `gamesPlayed`, `gamesWon`, `winPercentage`, inverse relationship to `Game`
- Score tracking: `scoreTeam` is an array of `[team1Score, team2Score]` pairs per round; totals are computed properties

## Known technical debt

- Button images missing text labels (accessibility issue)
- Some `fontWeight(.light)` usage (EditScoreView, HallOfFameView, InfoView, NewGameView, NewPlayerView) — evaluate if needed

## Active plan

See `docs/superpowers/plans/2026-10-16-duolingo-redesign.md` — Duo theme, then Home, Game and Add Score redesigns.

New or deleted Swift files must be registered with `ruby scripts/xcodeproj.rb add|remove` (classic Xcode groups). Tests: Swift Testing target `iScoreTests`, run with `xcodebuild test -project iScore.xcodeproj -scheme iScore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
