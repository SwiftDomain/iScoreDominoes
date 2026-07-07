# iScoreDominoes

2v2 domino game scoring app. SwiftUI + SwiftData. Supports Double-6 and Double-9 game types.

## Project path

`/Users/beastmode/Documents/GitHub/iScoreDominoes`

## Structure

- `iScore/Model/` — `Game.swift` (core model + enums), `Player.swift`, `Config.swift` (Background, shapes, cell views), `Theme.swift` (semantic colors), `Tip.swift`
- `iScore/Views/` — `HomeView`, `GameView`, `GamesView`, `NewGameView`, `AddGameScoreView`, `EditScoreView`, `HallOfFameView`, `NewPlayerView`, `InfoView`, `Glass`, `AnimatedMeshGradient`
- `iScoreApp.swift` — Entry point, SwiftData ModelContainer

## Theme ("Manga Paper")

B&W noir/manga palette — paper white, ink black, screentone grays. Fixed light palette; `.preferredColorScheme(.light)` is forced at the app root. All colors are semantic via `Theme` (`iScore/Model/Theme.swift`) backed by colorsets in `Assets.xcassets` — never hardcode `Color` literals in views.

- `Theme.background` `#F7F7F5` paper · `surface` `#FFFFFF` · `surfaceSecondary` `#E9E9E6` screentone (input wells, form rows)
- `Theme.accent` `#1A1A1A` ink — text ON accent fills must use `Theme.background` (paper), never `accentInk`
- `Theme.accentInk` `#1A1A1A` — accent-colored text/glyphs (same as accent here; kept separate so future palettes can split them)
- `Theme.textPrimary` `#1A1A1A` ink · `textSecondary` `#767676` · `divider` `#1A1A1A` ink hairlines
- Win/loss is encoded by brightness: `success` `#3D3D3D` charcoal (dark = emphasis) · `danger` `#9B9B9B` faded gray (light = receded)

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
- Button images missing text labels (accessibility issue)
- `HallOfFameView` uses `specifier` in `Text` — use modern format style
- Some `fontWeight(.light)` usage — evaluate if needed per CLAUDE.md

## Active plan

See `/Users/beastmode/.claude/plans/gentle-wibbling-widget.md`

Phases: CLAUDE.md updates → Color system (now Cloud Blue, see Theme section) → Home redesign → iPad adaptive → Settings → Undo score → Game summary
