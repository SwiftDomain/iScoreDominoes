# iScoreDominoes

2v2 domino game scoring app. SwiftUI + SwiftData. Supports Double-6 and Double-9 game types.

## Project path

`/Users/beastmode/Documents/GitHub/iScoreDominoes`

## Structure

- `iScore/Model/` — `Game.swift` (core model + enums), `Player.swift`, `Config.swift` (Background, shapes, cell views), `Tip.swift`
- `iScore/Views/` — `HomeView`, `GameView`, `GamesView`, `NewGameView`, `AddGameScoreView`, `EditScoreView`, `HallOfFameView`, `NewPlayerView`, `InfoView`, `Glass`, `AnimatedMeshGradient`
- `iScoreApp.swift` — Entry point, SwiftData ModelContainer

## Data model

- `Game` — `@Model` with `gameType` (six/nine), `maxScore`, `scoreTeam: [[Int]]`, `team1/team2: [String]`, `players: [Player]` relationship, `state` (playing/finished/cancelled), `inProcess` flag
- `Player` — `@Model` with `name`, `gamesPlayed`, `gamesWon`, `winPercentage`, inverse relationship to `Game`
- Score tracking: `scoreTeam` is an array of `[team1Score, team2Score]` pairs per round; totals are computed properties

## Known technical debt

- `GameView` uses `NavigationView` — must migrate to `NavigationStack`
- `Game` model conforms to `ObservableObject` — remove, SwiftData handles this
- `UIDevice.current.userInterfaceIdiom` checks in `NewGameView` and `HallOfFameView` — replace with `horizontalSizeClass`
- `showsIndicators: false` in `ScrollView` — use `.scrollIndicators(.hidden)`
- `.cornerRadius()` used in `GameView` — use `.clipShape(.rect(cornerRadius:))`
- `String(format: "%.0f", maxScore)` in `GameView`/`NewGameView` — use `.number.precision()` format
- `Background()` depends on a static image asset — replace with gradient
- Accent color (`#21FFC0` turquoise) used too broadly — needs < 10% discipline
- Button images missing text labels (accessibility issue)
- `HallOfFameView` uses `specifier` in `Text` — use modern format style
- Some `fontWeight(.light)` usage — evaluate if needed per CLAUDE.md

## Active plan

See `/Users/beastmode/.claude/plans/gentle-wibbling-widget.md`

Phases: CLAUDE.md updates → Color system (Navy + Amber Gold) → Home redesign → iPad adaptive → Settings → Undo score → Game summary
