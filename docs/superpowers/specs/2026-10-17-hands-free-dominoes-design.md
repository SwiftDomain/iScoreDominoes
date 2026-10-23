# Hands-free dominoes — design

Date: 2026-10-17
Status: awaiting approval

## Intent

iScoreDominoes is already correct. It is not yet effortless, and at a real
domino table effortless is the only thing that matters.

The phone sits face-up on the table all night. Every interaction today costs
an unlock and a look: tap in, find the game, tap the keypad, lock it again.
Starting a game costs more — four names typed into four seats before anybody
has played a tile. The people at that table are mid-conversation, holding
dominoes, and sometimes not speaking English.

This project makes the app something you talk to and glance at. You say a
sentence and a game exists. You say a score or tap a Lock Screen button and
the round is recorded. The other three players watch the score on their own
phones without being able to touch it. And the whole thing speaks the
player's language, not the developer's.

Ten features, to be built in the order listed. Each one ships on its own and
leaves the app better than it found it.

## Goals

- Starting a game takes one spoken sentence, in any word order.
- A full night of dominoes requires unlocking the phone only for an unusual
  round value.
- Every action has two equal doors: voice and touch. Neither is the
  "real" one.
- Interface language and voice language are chosen separately by the user.
- The other three players can follow the score live, read-only, with no
  internet.
- The app gives people reasons to come back and reasons to pass it around.

## Non-goals

- Playing dominoes in the app. This is a scorekeeper, not a game engine.
- Multiple simultaneous scorekeepers, score voting, or conflict resolution.
  One phone owns the score.
- Accounts, logins, or a server. Nothing the app does requires a backend.
- Remote spectating by someone not at the table.
- Watch, Mac, or iPad versions.

## Anti-goals

Things that would make this a failure even if every feature technically works:

- **Voice that has to be obeyed.** If the app ever waits on speech, blocks on
  a network round-trip, or forces a confirmation dialog the user has to read,
  it is slower than typing and people will stop using it. Voice must always
  be interruptible and always have a visible touch equivalent on screen.
- **A second-class keypad.** The existing touch flow must not regress to make
  room for voice.
- **Mid-game ceremony.** Celebrations, animations, and recaps belong between
  rounds and after games. Anything that blocks score entry for more than a
  beat is wrong.
- **Translated-looking Spanish.** Domino vocabulary is regional and specific
  (capicúa, zapato/blanqueado, paso). Machine-flavored strings will read as
  fake to exactly the people this is for.
- **Sharing that needs setup.** If joining a game takes more than reading a
  code off the table phone, nobody will do it.

## Constraints

Taken from the existing project; a builder should treat these as fixed.

- SwiftUI + SwiftData, iOS 26 deployment target, Swift 5 language mode.
- SwiftData store syncs through CloudKit (`cloudKitDatabase: .automatic`).
  **Every new persisted property must have a default value and every new
  relationship must be optional** — CloudKit requires it and the container
  will fail to build otherwise.
- The Duo theme is law: semantic colors from `Theme` only (never a `Color`
  literal in a view), `DuoFont`, cards at radius 16 with a 2pt border and 4pt
  bottom edge, buttons at radius 14 with a 4pt darker edge. No gradients,
  shadows, blur, or glass. New colorsets go in `Assets.xcassets` **and** in
  `Theme.colorAssetNames`, or `ThemeTests` fails.
- Fixed light palette; `.preferredColorScheme(.light)` at the app root.
- New or deleted Swift files must be registered with
  `ruby scripts/xcodeproj.rb add|remove`.
- Logic lives in `iScore/Model/` as pure, testable types with Swift Testing
  coverage in `iScoreTests`. Views stay thin. Follow the existing split
  (`Game+Scoreboard`, `GameSetup`, `ScoreEntry`, …).
- `Game.scoreTeam` is `[[Int]]` with a seed `[0, 0]` row; every real round is
  one-sided (`[points, 0]` or `[0, points]`). Do not change this shape.
- Target ranges are real: Double-6 is 10…100, Double-9 is 10…200, in steps
  of 10. Player names cap at 15 characters and are compared case-insensitively.

## The ten features

### 1. Say the game into existence

**What it does.** The user speaks or types one free-form sentence — *"nine,
two hundred, me and Carlos against Luis and Papo"* — and the app produces a
filled-in New Game screen ready to start. Word order does not matter.
Anything the sentence leaves out comes from the saved `GameDefaults`, not
from a follow-up question.

A microphone button on New Game and on Home starts it. The result is a
confirmation card showing game type, target, and the four seats, with one tap
to start and every field still editable by touch. **Nothing is ever started
without that tap.**

The same entry point runs at the end of a game: the Game Summary screen
offers "Next game", which takes a sentence like *"same but me and Luis"* and
builds the next game, reusing the previous game's type and target unless the
sentence overrides them.

**How.** Speech-to-text is `SFSpeechRecognizer` configured for on-device
recognition in the user's chosen voice language (feature 4).

Turning that transcript into a game has **two layers, and the deterministic
one is primary** (my call — `SystemLanguageModel` only exists on Apple
Intelligence-capable hardware with the assets downloaded, and plenty of
iOS 26 phones at a domino table will not have it; voice has to work for
everybody):

1. `GameCommand` parses the transcript itself — scanning for numbers, type
   words, team separators ("vs", "against", "contra"), and known player
   names. This is pure Swift, fully unit-testable, works on every device,
   and handles the sentence shapes people actually use.
2. When Foundation Models **is** available, a `@Generable` struct with
   fields for game type, target, and four names runs a guided-generation
   call and takes over for sentences layer 1 could not resolve — unusual
   phrasing, unfamiliar name spellings, "same as last time but…". Nothing
   leaves the phone and there is no API cost.

The confirmation card is identical either way, so the user never learns which
layer answered.

**Resolution rules** live in a new pure type (`GameCommand` in
`iScore/Model/`), separate from the model call, so they are unit-testable
against transcript strings:

- "me" / "yo" resolves to the device owner's player name, stored once in
  Settings (`@AppStorage`) the first time it is needed. The scorekeeper is
  often **not** one of the four players, so when the owner is not seated,
  "me" is dropped rather than guessed, and "us"/"them" in feature 3 fall
  back to team 1 / team 2 by seat order. Naming a player always works
  regardless. (My call.)
- Spoken names are matched against existing `Player` records with the
  existing `PlayerName.resolve` so "ana" does not create a second "Ana".
  Unmatched names are offered as new players on the confirmation card,
  visibly marked as new.
- Bare numbers are disambiguated by range: 6 and 9 are game types; anything
  in the type's `targetRange` is the target. A number valid as neither is
  dropped and the field falls back to the default.
- The target is run through `clampedTarget`, so "two hundred and five"
  becomes 200.
- If fewer than four names are heard, the card opens with the heard names
  seated and the rest empty, and the existing `PlayerLineup.hint` explains
  what is missing.

**Done looks like:** with four saved players, speaking the example sentence
produces a correct, startable confirmation card in under two seconds on the
deterministic path, and `GameCommand` has tests covering word orders, missing
fields, "me", an unseated owner, unknown names, out-of-range targets, and
Spanish phrasing. On a device with no Apple Intelligence, feature 1 works —
only the hard sentences are lost.

### 2. Lock Screen scoreboard with live score entry

**What it does.** While a game is in progress, a Live Activity shows on the
Lock Screen and in the Dynamic Island: both team names, both totals, points
to win for the leader, and the round number. It carries interactive buttons
to record a round for either team without unlocking the phone, plus undo.

**How.** A new Widget Extension target with ActivityKit, sharing an App Group
with the app. Buttons are `Button(intent:)` with App Intents that write
through to the same `Game.addRound` / `undoLastRound` logic.

The important architectural piece: the widget process cannot open the
CloudKit-backed SwiftData container safely while the app is running. The
intent should write the round into a small append-only pending-rounds file in
the App Group container and reload the activity optimistically; the app
drains that file into SwiftData on next foreground and on activity updates.
This keeps the model single-owner and avoids two processes racing the store.

**Activity content** must be legible at arm's length on a table — follow the
Duo type scale, use `Theme.teamA` / `Theme.teamB`, and keep the compact
Dynamic Island presentation to the two totals.

**How many points?** A Lock Screen button cannot show a keypad, so the
activity carries **a small grid of the point values that actually come up**,
per team — chosen by game type, and ideally re-ranked over time from the
user's own history. A round outside that set opens the app; everything else
is one tap with the phone still locked.

This must work on every iPhone, so the grid lives in the **Lock Screen
presentation**, not only the expanded Dynamic Island. The compact Dynamic
Island shows the two totals and nothing else.

**The scorekeeper guard.** Anyone who picks up the table phone can press
these buttons. That is accepted — it is the scorekeeper's own phone, on their
own table. A Settings toggle, "Require unlock to score from Lock Screen",
defaults to off and turns the buttons into deep links for people who want it.
(My call.)

**Done looks like:** a game whose rounds are all common values can be scored
start to finish without the phone ever being unlocked, on a non-Pro iPhone,
and the app's in-app score matches exactly afterward.

**Out of scope:** the pending-rounds file is device-local and does not sync,
so a user signed in on two devices could in principle diverge. One device
keeps score; this is accepted and not defended against.

### 3. Voice and keypad as equal doors

**What it does.** Everything the keypad can do can be said, and everything
that can be said has a visible touch equivalent. In-game commands:

- *"twenty-five us" / "thirty them" / "veinticinco nosotros"* — record a round
- *"undo" / "quita eso"* — undo the last round
- *"who's winning?" / "¿quién va ganando?"* — spoken answer
- *"how many to go?"* — spoken answer for both teams
- *"end the game" / "cancel the game"* — with a confirmation tap

**Push-to-talk, not always-listening.** A large, always-visible mic button on
`GameView` and in the Add Score sheet: one tap, then speak. No wake phrase
and no continuous recognition — the mic never runs unattended, there is no
battery drain across a four-hour night, no permanent recording indicator, and
no chance of table conversation being heard as a score. The tap is the price
and it is one tap, not an unlock.

**How.** The mic button holds the same on-device recognizer as feature 1. A
second pure type
(`ScoreCommand` in `iScore/Model/`) turns a transcript into an action. Team
reference resolves by: explicit player name > team name > "us"/"nosotros"
meaning the scorekeeper's own team > "them"/"ellos". Numbers are spelled-out
or digits, in the voice language.

Spoken answers go through `AVSpeechSynthesizer` in the voice language, and
are suppressed when the device is on silent or the user turns speech off in
Settings.

Recording a round by voice reuses the existing `RoundFeedbackBanner` so the
visual confirmation is identical to the touch path — and that banner is the
undo affordance.

**Done looks like:** `ScoreCommand` has tests over English and Spanish
transcripts for all commands above, and a scorekeeper can play a full game
without ever reading the screen or typing a number — one mic tap per round.

### 4. Two language settings, not one

**What it does.** Settings gains a Language section with **two** pickers:
*App language* and *Voice language*. They are independent — a Spanish-speaking
table with an English interface is a supported combination, as is the
reverse. English and Spanish ship first.

**How.** This is the largest cross-cutting piece of work in the project,
because the app currently has **no localization at all**: every user-visible
string is a hardcoded English literal, and a good number of them are built in
the model layer (`Game.statusLabel`, `Game.headline`, `PlayerRecord.summary`,
`PlayerLineup.hint`, `GameList.countLabel`, `Team.description`, …).

Three parts, in order:

1. **Extract.** Add a String Catalog (`Localizable.xcstrings`) and move every
   literal into it. Model-layer copy that interpolates counts and names must
   become `LocalizedStringResource` with proper plural variants — Spanish
   pluralization differs and "1 round"/"5 rounds" string-building must go.
2. **Translate.** Spanish strings must use real Dominican/Puerto Rican domino
   vocabulary, not generic translation. **The app's owner reviews the Spanish
   himself before it ships** — the domino-specific terms are pulled into a
   separate short list so they can be checked as a set rather than hunted
   through the catalog. Spanish ships with this feature, not behind a flag.
3. **Switch.** App language is applied with the app's own locale override
   (`AppleLanguages` in `UserDefaults`). **This resolves at launch, so
   changing app language prompts a restart** — the picker says so plainly and
   offers to relaunch. (My call: a live switch would require resolving every
   string at render time through an explicitly loaded `.lproj` bundle with a
   locale threaded through the whole view tree and every model-layer
   `LocalizedStringResource`, which is a large amount of machinery for a
   setting touched roughly once.) **Voice language switches live** — it is
   just a stored identifier used to construct `SFSpeechRecognizer` and
   `AVSpeechSynthesisVoice`, and it defaults to the app language on first run.

Player names are never translated. Numbers and dates use the app language's
locale formatting.

**Done looks like:** after relaunch, switching app language changes every
screen with no English left behind; switching voice language alone changes
what the app hears and says, immediately, while the interface stays put.
Enforcement of "no bare literals" is a **build-phase lint script** over
`iScore/` that fails the build on a user-facing literal outside the catalog
(my call — `iScoreTests` has no source-scanning precedent and a test reading
the project source root would break on CI).

### 5. Live spectate over a local connection

**What it does.** The scorekeeper taps Share on a game and the app shows a
short join code. The other three open the app, tap Join, enter the code, and
see the live scoreboard on their own phones — read-only. Their screen updates
as rounds are recorded.

**Guests keep the app open.** `MCSession` does not survive backgrounding or
locking, and there is no background mode that keeps a Multipeer session
browsing — so a guest Lock Screen Live Activity is not buildable over this
transport and is **not** part of this feature. (My call, following from the
local-connection choice; the trade was offline-anywhere over lock-screen
guests.) Guest phones stay awake on the spectate screen while it is open, and
that screen is built to be glanceable from across the table like table mode.

Only the phone that created the game can change the score. Guest screens have
no keypad, no undo, and no edit affordances — not disabled ones, absent ones.

**How.** `MultipeerConnectivity` with `encryptionPreference: .required`, over
Wi-Fi and Bluetooth, no internet and no iCloud account needed. The
scorekeeper advertises, guests browse. The join code is a short human-readable
string (4–5 characters, unambiguous alphabet — no 0/O/1/I) used as the
advertiser's discovery info and checked on connect, so two games in the same
room don't cross.

The wire format is a small `Codable` snapshot — game type, target, both team
name lists, `scoreTeam`, state — sent in full on every change. Games are
small; there is no reason to send diffs. Guests render the snapshot in a
dedicated read-only view and never write it to their own SwiftData store.

**When the game ends**, the final snapshot is sent with a flag, and each guest
is offered one tap to save the finished game into their own history and stats.
That is the only time a guest writes anything.

**Reconnection:** a guest who backgrounds the app and comes back reconnects
automatically and receives a fresh full snapshot. A guest who is out of range
or whose session has dropped sees a clear "lost connection" state rather than
a stale score presented as live.

**Done looks like:** four devices with Wi-Fi off and cellular off, one
scorekeeper and three guests with the app open, all showing the same score
within a second of each round, and guests unable to alter it.

### 6. Game presets

**What it does.** A saved, named setup — *"Friday night"* = Double-9, 200,
the usual four — startable with one tap from Home or one phrase by voice
(*"start Friday night"*). Presets are created from Settings or saved from a
finished game ("Save this setup").

**How.** A new `GamePreset` SwiftData model (name, game type, target, four
player names, created date — all with defaults, per the CloudKit constraint).
A presets row on Home showing up to three, and full management in Settings.
Preset names are matched by the voice parser from feature 1 before it tries
to parse a free-form game description.

**Done looks like:** a preset starts a correct game in one tap, survives
iCloud sync to a second device, and is reachable by voice.

### 7. Table mode

**What it does.** A mode for the phone lying face-up in the middle of the
table: score numerals large enough to read from any seat, the screen kept
awake, and the two team cards arranged so the opposing team is not reading
upside-down.

**How.** A toggle on `GameView` (and a Settings default). It applies:

- `.persistentSystemOverlays(.hidden)` and an idle-timer disable while active
- A much larger score type scale — a new `DuoFont.tableScore` rather than
  scaling `DuoFont.score`, so the existing screens are untouched
- A split layout with team 2's card rotated 180°, so each side reads its own
  score right way up
- A single large tap target per team that opens the keypad directly, skipping
  the current navigation step

Everything stays inside the Duo system: same colors, same card shape, same
borders, just bigger.

**Done looks like:** a screenshot from 3 feet above the phone is readable, the
screen does not dim during a game, and leaving table mode restores the normal
layout exactly.

### 8. Rivalries and head-to-head records

**What it does.** Hall of Fame grows beyond individual win counts: *"You &
Carlos are 14–9 against Luis & Papo."* Pairings get records. A player's
profile shows their best partner, their worst matchup, and their current
streak.

**How.** A new pure type (`Rivalry` in `iScore/Model/`) computed over finished
games — no new persistence needed, the data is already in `Game.team1`,
`Game.team2`, and `winningTeam`. Pairings are order-independent and compared
case-insensitively (reuse `PlayerName.isSame`). Head-to-head records need a
minimum number of games before they are shown, so a 1–0 record does not get
announced as a rivalry; the threshold is 3 (my call).

Surfaced on Hall of Fame, on the Game Summary screen ("that makes it 15–9"),
and in the pre-game confirmation card from feature 1 ("last time, they won").

**Done looks like:** `Rivalry` is fully unit-tested against the existing
`DemoData` sample games, and the numbers it reports can be checked by hand
against the games list.

### 9. Round-level drama

**What it does.** The app notices the things players would call out
themselves, and calls them out: capicúa, a shutout (*zapato* / *blanqueado*),
the biggest round of the night, a comeback from more than N points down, a
game decided by one round, a player's win streak. Each is a short banner with
a small animation and, when voice is on, a spoken line.

**How.** A pure type (`GameDrama` in `iScore/Model/`) that takes a `Game` and
a newly added `Round` and returns zero or one highlight — zero most of the
time. Highlights are ranked so only the best one for a round is shown, and
the same highlight does not repeat within a game.

Capicúa cannot be derived from the score alone, so Add Score gains an optional
"capicúa" toggle next to the keypad, and the word is recognized by the voice
parser from feature 3. Everything else is derived from existing data.

Reuses `RoundFeedbackBanner` and `TrophyBurst`; adds no new visual language.
A Settings toggle turns the whole thing off.

**Done looks like:** `GameDrama` has tests for every highlight type including
the "nothing happened" case, highlights never block score entry, and the
Spanish copy uses the real terms.

### 10. Night recap worth sending

**What it does.** When a session ends — several games with the same group —
the app offers one shareable card: final standings for the night, each
pairing's record, the biggest round, the longest streak, the rivalry totals
updated. One tap to Messages or the group chat.

**How.** A "session" is inferred, not stored: finished games on the same
calendar day sharing at least three of the same players (my call — the rule
lives in a pure `NightRecap` type and is easy to change). The card is a
SwiftUI view rendered with `ImageRenderer` at 2x, shared through the standard
share sheet, including an App Store link for the app itself.

The card is built from the Duo system so it looks like the app, and it must be
legible as a small image in a chat thread — large numerals, few words, high
contrast.

**Done looks like:** after three games with the same four players, the recap
offers itself, and the rendered image is readable at thumbnail size in
Messages.

## Sequencing and dependencies

The order is the user's, and it holds up technically with one caution:

1 → 3 share the speech and parsing infrastructure; building 1 first
establishes it, and 1's deterministic `GameCommand` is the model 3's
`ScoreCommand` follows. Features 2 and 5 are now independent (no shared
widget), so the order between them is free. **4 is the riskiest to defer** —
every feature
before it adds English strings that then need extracting, and features 1 and 3
add Spanish-language *behavior* before the Spanish *strings* exist. A builder
has two sane options: pull the String Catalog setup forward to the start as
plumbing (translation can still come later, at position 4), or accept a larger
extraction pass at step 4. **Recommended: pull the catalog setup forward, keep
translation at position 4.** Flag this if the strict order matters more.

## What is left to the builder

- The App Group identifier, widget extension name, and target configuration.
- The exact pending-rounds file format and drain logic for feature 2.
- Whether the Foundation Models call is one `@Generable` struct or a small
  chain, and the prompt text itself.
- The Multipeer service type string and the snapshot `Codable` shape.
- All view composition within the Duo system, and any new colorsets (which
  must be added to `Theme.colorAssetNames`).
- Where each feature's tests live, following the existing `iScoreTests`
  structure.

Every feature above names a pure, testable type in `iScore/Model/` because
that is how this project is built; a builder who finds a better seam should
take it, as long as the logic stays out of the views and stays tested.
