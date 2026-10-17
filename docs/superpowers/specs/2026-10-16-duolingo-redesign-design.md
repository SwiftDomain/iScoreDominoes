# iScore "Duo" redesign — design spec

Source: Refero style "Duolingo — Playful classroom mascot on white paper" (styles.refero.design), approved by the user on 2026-10-16 from rendered mockups of Home, Game and Add Score. This replaces the "Manga Paper" theme.

## Palette (fixed light, sRGB)

| Token (colorset) | Hex | Use |
|---|---|---|
| `background_primary`, `surface` | `#FFFFFF` | Canvas, cards |
| `surfaceSecondary` | `#F7F7F7` | Wells (number display, round circles, cancelled chip) |
| `dividerColor` | `#E5E5E5` | 2pt borders, card bottom edge, empty round cell "—" |
| `textPrimary` | `#4B4B4B` | Titles, body |
| `textSecondary` | `#777777` | Secondary text |
| `textMuted` (new) | `#AFAFAF` | Labels, toolbar icons, placeholder |
| `AccentColor`, `success`, `teamA` (new) | `#58CC02` | Team 1, primary action, wordmark |
| `accentInk`, `teamAShadow` (new) | `#58A700` | Pressed edge under green; green text on wash |
| `teamAWash` (new) | `#D7FFB8` | Green tint (FINISHED chip, feedback banner, preview bar) |
| `teamB` (new) | `#1CB0F6` | Team 2, links ("View all") |
| `teamBShadow` (new) | `#1899D6` | Pressed edge under blue |
| `teamBWash` (new) | `#DDF4FF` | Blue tint |
| `gold` / `goldShadow` (new) | `#FFC800` / `#E5B400` | Leader crown, trophies, Hall of fame tile |
| `streak` / `streakShadow` (new) | `#FF9600` / `#E08600` | Day-streak flame, win-rate tile |
| `learn` / `learnShadow` (new) | `#CE82FF` / `#A568CC` | How to play tile |
| `danger` / `dangerShadow` (new) | `#FF4B4B` / `#EA2B2B` | Destructive actions |

Text on any saturated fill (green, blue, gold, orange, purple, red) is white (`Theme.surface`).

## Type

SF Pro Rounded everywhere (`.fontDesign(.rounded)` at the app root). Scores: weight `.black`. Titles: `.title2` `.heavy`. Body: `.body` `.bold`. Labels and button titles: `.footnote` `.heavy`, uppercase, tracking 0.8.

## Shape and depth

Flat. No gradients, shadows, blur or glass on redesigned screens. Depth = a darker bottom edge:
- Buttons and keypad keys: radius 14, solid fill, 4pt bottom edge in the shadow color; pressed = content drops 4pt and the edge disappears. Disabled = `dividerColor` fill, `textMuted` title, no edge.
- Cards: radius 16, white, 2pt `dividerColor` border, 4pt bottom edge (2pt for small stat tiles and the speech bubble).
- Progress bars: capsule, `dividerColor` track, colored fill, a lighter 4pt highlight strip inset along the top of the fill.
- Chips: radius 8.

## Home (layout unchanged)

- Toolbar: leading wordmark "dominoes" (`.black`, 26pt, green). Trailing: flame chip (orange, day streak), trophy chip (gold, finished-games count), settings gear (muted). No large title.
- "Continue" card (game in progress): green fill + green edge. Label "GAME IN PROGRESS · DOUBLE 9" (wash color), "Ana & Luis vs Rafa & Mia", "105 – 45" + "to 200", white progress bar on dark-green track, white "CONTINUE" button with green title.
- 2×2 tiles (pressable cards, colored icon square 40pt radius 12): New game (green, plus), All games (blue, list), Hall of fame (gold, trophy), How to play (purple, graduation cap).
- "Recent games" + blue "VIEW ALL" (to All games). Cards 170pt wide: FINISHED chip (wash/green) or CANCELLED chip (well/gray), team 1 names, "vs team 2", "200 – 145", "D9 · Oct 12".
- "Your stats": three tiles — Games (blue stack icon), Wins (gold trophy), Win rate (orange target).

## Game

- Toolbar: system back, progress bar (leader's progress toward the target, leader's color; muted when tied), undo, info.
- Label "ROUND 6 · FIRST TO 200", headline (see copy).
- Two team cards: overlapping initial avatars, names, total (42pt, team color), team progress bar, "95 to win". Leader card gets a team-colored border and a gold crown badge.
- "Rounds" + "5 played"; rows newest first: gray numbered circle, "+35" in the scoring team's color in its column, "—" in the other. Long-press edits (existing behavior).
- Bottom bar: green "+ Ana & Luis" and blue "+ Rafa & Mia" pressable buttons; disabled when the game isn't playing.
- After a round is added (and the game isn't won): feedback banner replaces the bottom bar for 2 seconds — wash background in the scoring team's color, check badge, "Nice round!", "Ana & Luis +35 · 60 to win".

## Add score (sheet)

- Close (X) + progress bar showing the team's current progress plus a wash-colored preview of the projected total.
- Team avatars (40pt) + speech-bubble card: "We dominoed! How many points did we make?"
- Number well (84pt tall, 52pt `.black` digits; "0" muted when empty; border turns team color once a digit is entered).
- Projection line under the well, e.g. "105 → 140 · 60 to win".
- Keypad tiles 1–9, CLEAR, 0, delete. No system keyboard.
- Full-width team-colored button "ADD 35 POINTS" (disabled until a digit is entered).

## Copy (exact)

- Headline: "{team} won!" (finished) · "Let's play!" (no rounds) · "All tied up" (tie) · "{leader} lead by {n}".
- Projection: "{old} → {new} · {n} to win" or "{old} → {new} · Wins the game!".
- Add button: "Add {n} points" / "Add 1 point" / "Add points" (rendered uppercase).
- Team name: player names joined with " & "; fallback "Team 1" / "Team 2".
- Empty rounds: "No rounds yet. Add the first score below."

## Out of scope

New Game, All Games, Hall of Fame, Settings, Edit Score, Game Summary and How to Play keep their layouts and only pick up the new palette via re-valued colorsets. No tab bar, no navigation changes, no data-model migration.
