# QUOTA: The Factory Must Grow (Or Else)

A Factorio roguelite that fits in an hour. The Company drops you on a tiny island with a Shipping Terminal, a starter kit and a quota. Every shift the clock runs and the quota climbs. Make the number and you get a break, a paycheck and a shop. Miss it and you get a written warning. Miss it again and you're fired.

It is still Factorio: ore, belts, assemblers, power, the tech tree. It's just Factorio with a boss watching the clock.

## How a run goes

- **Shifts.** A timer and a quota. Anything you drop in the Shipping Terminal sells at market price, live. Crafted goods pay more than their ingredients, so the deeper your production chain, the better the money.
- **The market moves.** Every shift a few items run hot and pay x2 to x3. Sell too much of one thing and its price floods. A panel on the left shows what pays right now, with the maths done for you.
- **Breaks.** Ninety seconds to spend your pay in the Company Catalog:
  - **Contracts:** 30 rule-benders, Balatro style. Five slots, three offers per break. Some are great and some are traps.
  - **Tech:** Factorio's own research, bought outright. Your labs still work if you'd rather make science.
  - **Supplies:** machines by orbital drop pod, landing right next to you.
  - **Land:** neighbouring plots rise out of the sea, each with its own ore, oil, ruins or biter swamp.
- **Conditions.** From shift 2 every shift has a twist: gremlins jamming your machines, earthquakes, union strikes, meteor showers, a solar eclipse, a hostile takeover raid, picky clients. One or two at a time, rolled per shift.
- **The Audit.** The last shift has a boss. It walks from terminal to terminal freezing your sales until you deal with it.
- **Endless.** Survive and get promoted, then keep going for as long as the quotas let you.

## Two ways to play

| | Simple | Complex |
| --- | --- | --- |
| Length | 8 shifts, about an hour | 10 shifts, about 80 minutes |
| Prices | Follow ingredient cost | Deep chains pay up to 2.6x (plates pay less) |
| Tech | Everything for sale | Zoned by land: oil needs 2 plots, blue science 4, purple and yellow 6 |

**First time? Play Simple.**

Everything else is switchable on the setup screen:
- Difficulty: Intern, Associate or Crunch Time.
- Every threat, condition and event, one switch each.
- Presets: Full Company, No Biters, or Race the Clock, which turns off every threat so it's just you, the market and the timer.
- Fine print: run length, written warnings, quota size, shift length and break length.

## Install

1. Download `quota_2.0.0.zip` from the mod portal (search "QUOTA"). You can also build it yourself with `bun run package`, which writes it to `dist/`.
2. Enable it. Leaving it on is fine: the mod does nothing in any game except its own scenario.
3. **New Game → Scenarios → QUOTA.**

Needs Factorio 2.1. Works with or without Space Age, Quality, Elevated Rails and Recycler; the run itself takes place on its own island. Single player.

Keys: **J** opens the Catalog. Hover any item icon for its recipe.

## Yes, an AI built it

Every line of Lua and every number in the balance was written by Claude, working with one human who kept playing it and saying what felt wrong. The playtests were real: the $1 ammo bug, the shift-2 meteor storms and the "why would I ever buy land" problem all came from actual runs and got fixed.

What that means for you: it's been played end to end a lot, there's a headless test that drives a whole run in vanilla and in Space Age every time something changes, and there will still be rough edges. Bug reports and "this felt bad" notes are very welcome.

## For tinkerers

- All the tuning lives in `mod/lib/config.lua`: quotas, shift lengths, prices, hazards, the starter kit.
- Item prices aren't a hand-written table. They come from the real recipe graph, so modded items get prices too.
- Remote interface: `remote.call("quota", "state")` and friends. See `cliffnotes.md`.
- `bash tools/run-autotest.sh` runs a whole game headless. `QUOTA_MODS=.factorio-test/sa-mods` runs the same test with Space Age on.
