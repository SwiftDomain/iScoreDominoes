# Spanish domino terms — for review

The spec asks that the Spanish use real Dominican and Puerto Rican table
vocabulary rather than generic translation, and that **the app's owner reviews
it before it ships**. The rest of the catalog is ordinary Spanish; these are
the choices where a domino player would notice if we got it wrong. Check them
as a set — if one is off, say which and I will change it everywhere.

| English | Spanish chosen | Why |
|---|---|---|
| game (one match) | **partida** | At a table, a "juego" is the game of dominoes in general; a single match you play to 200 is a *partida*. Used throughout: "Partida nueva", "Todas las partidas", "Eliminar partida". |
| round | **ronda** | *Mano* is also heard for a single hand, but *ronda* is unambiguous next to the round numbers the app shows, and does not collide with *mano* meaning the player who leads. |
| We dominoed! | **¡Dominamos!** | The verb players actually use when a team goes out. Not "¡Ganamos!", which is the match, not the hand. |
| Double 6 / Double 9 | **Doble 6 / Doble 9** | Standard for the tile set. |
| First to 200 | **Primero a 200** | How the target is said at the table. |
| to win (points remaining) | **para ganar** | "80 para ganar". |
| Wins the game! | **¡Gana la partida!** | Consistent with *partida* above. |
| Leading | **Va ganando** | What you say watching a scoreboard; "Liderando" is sportscaster Spanish. |
| lead by | **van ganando por** | Plural because a team is two people. |
| All tied up | **Empatados** | Plural, agreeing with the players rather than the score. |
| Let's play! | **¡A jugar!** | |
| Nice round! | **¡Buena ronda!** | |
| score (verb) | **anotar** | "Anotar una ronda", "Desbloquear para anotar". *Marcar* reads like football. |
| score (noun, an entry) | **anotación** | "Deshacer la última anotación". |
| Hall of fame | **Salón de la fama** | |
| wins (count) | **victorias** | Pluralized through the catalog: 1 victoria / 9 victorias. |
| Your stats | **Tus números** | What a player would say; "Tus estadísticas" is correct but stiff. |
| Nobody (no owner set) | **Nadie** | |
| That's me | **Ese soy yo** | |

## Not translated, deliberately

- **Player names** — never translated, and never used as a format string.
- **"dominoes" / "Dominoes"** — the app's own wordmark on Home.
- **"VS"** — used as-is at Spanish-speaking tables.
- **iScore, iScoreDominoes, iScoreWidgets** — product and target names.
- **Numbers and dates** — formatted by the locale, not written by hand.

## Plurals

Four keys carry plural variants rather than Swift branching, because Spanish
does not split singular and plural where English does:

- `%lld games` → 1 partida / 5 partidas
- `%lld rounds` → 1 ronda / 3 rondas
- `%lld wins` → 1 victoria / 9 victorias
- `Add %lld more players to start` → Agrega 1 jugador más / Agrega 4 jugadores más
