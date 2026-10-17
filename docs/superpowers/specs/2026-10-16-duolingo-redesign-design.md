# iScore "Duo" redesign — design spec

Source: Refero style "Duolingo — Playful classroom mascot on white paper" (styles.refero.design), approved by the user on 2026-10-16 from rendered mockups of Home, Game and Add Score. This replaces the "Manga Paper" theme.

## Palette (fixed light, sRGB)

| Token (colorset) | Hex | Use |
|---|---|---|
| `background_primary`, `surface` | `#FFFFFF` | Canvas, cards |
| `surfaceSecondary` | `#F7F7F7` | Wells (number display, round circles, cancelled chip) |
| `dividerColor` | `#E5E5E5` | 2pt borders, card bottom edge, empty round cell "—" |
| `textPrimary` | `#4B4B4B` | Titles, body |
| `textSecondary` | `#777777` | Secondary and informational text: uppercase labels ("ROUND 6 · FIRST TO 200"), "95 to win", round numbers, "5 played", tile subtitles, dates; Increase Contrast `#595959` |
| `textMuted` (new) | `#AFAFAF` | Toolbar icons, placeholder, disabled titles (not text people need to read); Increase Contrast `#767676` |
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
- Buttons: radius 14, solid fill, 4pt bottom edge in the shadow color; pressed = content drops 4pt and the edge disappears. Disabled = `dividerColor` fill, `textMuted` title, no edge.
- Keypad keys: white cards with the button shape — radius 14, 2pt `dividerColor` border, 4pt edge below it; pressed = drops 4pt.
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

- Toolbar: system back, progress bar (leader's progress toward the target, leader's color; muted when tied), undo, info. Undo and info turn `dividerColor` when disabled (game over, or no rounds to undo).
- Label "ROUND 6 · FIRST TO 200" ("3 ROUNDS · FIRST TO 200" once finished or cancelled), headline (see copy).
- Two team cards: overlapping initial avatars, names, total (42pt, team color), team progress bar, "95 to win". Leader card gets a team-colored border and a gold crown badge.
- "Rounds" + "5 played"; rows newest first: gray numbered circle, "+35" in the scoring team's color in its column, "—" in the other. Long-press edits (existing behavior) while the game is playing; the "Edit Scores" tip and the VoiceOver "Edit score" action only appear then, and only once there are rounds.
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

- Status label: "Round {n} · First to {target}" while playing · "{n} rounds · First to {target}" ("1 round") once finished or cancelled.
- Headline: "{team} won!" (finished) · "Game cancelled" (cancelled) · "Let's play!" (no rounds) · "All tied up" (tie) · "{leader} lead by {n}".
- VoiceOver: rounds read "Round {n}, {team}, {points} points"; progress bars are named "{team} progress" ("Game progress" when tied).
- Projection: "{old} → {new} · {n} to win" or "{old} → {new} · Wins the game!".
- Add button: "Add {n} points" / "Add 1 point" / "Add points" (rendered uppercase).
- Team name: player names joined with " & "; fallback "Team 1" / "Team 2".
- Empty rounds: "No rounds yet. Add the first score below."

## Remaining screens (approved 2026-10-17)

Approved by the user from rendered mockups (`.superpowers/mockups/duo-screens-v1.html`, not committed). Shared pieces: game-type tiles (domino drawing, selected = `teamB` border + `teamBWash` fill + `teamBShadow` text) and a target stepper (− / well / +, step 10) used by New game and Settings; player avatars colored by name (green, blue, purple or orange, stable per name); sheets close with a muted X instead of "Done".

- **New game:** "Who's playing?" headline; Team 1 / Team 2 cards (green / blue label) with two seat rows each (avatar + name, or dashed "+" and muted "Add player"), "VS" badge between them; "GAME" tiles Double 6 / Double 9; "FIRST TO" stepper (10–100 for Double 6, 10–200 for Double 9; picking a type resets the target to 20 / 100). Starts from the Settings defaults. Bottom bar: hint ("Add 2 more players to start", "Pick 4 different players") and green "START GAME", disabled until four different names are set.
- **Player picker (sheet):** X + "TEAM 2 · PLAYER 2" label, "Add a player", name well (team-colored border), "YOUR PLAYERS" list filtered by the typed text; players already in this game are grayed with a "PICKED" chip. Team-colored "ADD PLAYER" uses the typed name (matching an existing player's spelling when it differs only by case). Names are trimmed and capped at 15 characters.
- **All games:** title "All games" + "12 games · 1 in progress", search well (player names), chips All / Playing / Finished / Cancelled with counts, month headers ("October 2026"), one card per game: status chip (IN PROGRESS blue wash, FINISHED green wash, CANCELLED gray), "D9 · Oct 12", one row per team (avatars, name, total); winner gets a gold trophy, losers and cancelled games are muted; games in progress show a small progress bar and "First to 200". `+` in the toolbar starts a new game. Long-press → "Delete game" with confirmation (players are kept). Empty state: "No games yet" + START A GAME.
- **Hall of fame (podium):** X + "Hall of fame"; top three players on a podium (2nd, 1st, 3rd) — gold / silver (`textMuted`) / bronze (`streak`) blocks with the rank, avatar, name and wins, crown on 1st; everyone else in rows (rank, avatar, name, "12 played · 75%", wins). Ranked by wins, then win rate; ties share a rank; players with no finished games are last ("No finished games yet") and never on the podium. Empty state: "Finish a game to get on the board."
- **Settings:** X + "Settings"; "NEW GAME DEFAULTS" card (type tiles, "First to" stepper); "PLAYERS · 8" card (avatar, name, "12 games", trash → existing confirmation alert); "ABOUT" card (iCloud sync On, Version "2.0 (14)").
- **Edit score (sheet):** mirrors Add score: X + progress bar (team progress without this round, wash preview of the edited total), avatars + bubble "Fixing round 3? What should it be?", label "ROUND 3 · WAS +45", number well, projection "105 → 110 · 90 to win", keypad. Bottom: white trash button (red icon) → confirm "Delete round 3?" removes the row from `scoreTeam`; team-colored "SAVE 50 POINTS" ("Save 1 point" / "Save points"). Points come only from the keypad (always > 0).
- **Game summary (celebration):** gold trophy circle with colored sparkles, headline in the winner's edge color ("Ana & Luis won!"), "Double 9 · First to 200 · Oct 16"; three tiles with a colored header — FINAL "200–145" (gold), ROUNDS "6" (purple), WON BY "55" (orange); "Rounds" with team avatars + totals as column headers and `RoundRow`s newest first. Bottom: white share button (blue icon) + green "DONE". The shared image uses the same look.
- **How to play:** X, purple icon square + "How to play" / "Short videos on the rules and scoring", each video in a white card at 16:9 labeled "VIDEO 1"…

## Out of scope

No tab bar, no navigation changes, no data-model migration.
