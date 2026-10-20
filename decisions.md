# QUOTA — Decisions

Settled choices. Append-only; supersede with a new entry instead of editing.

## 2026-10-19 — No Company-issue items: kit and crate consumables sell normally (supersedes the entry below)
**Why:** Sal disliked the padlock-stamped copies ("if you sell everything so be it"). The $1-ammo bug stays fixed because the fungible counter it came from is gone too. Free care packages carry machines only, so nothing free can be flipped; paid crates of products cost 1.25x value.

## 2026-10-19 — Company-issue copies replace the "Company property" counter (supersedes 2026-10-15)
**Why:** the fungible counter charged crafted ammo at scrap once kit ammo was fired ($1 shells shown as hot $40). Handouts meant to be used (ammo, coal, repair packs, modules, grenades) now arrive as `quota-issued-*` items with no value; everything you craft sells in full. Care packages carry machines only.
**Rejected:** per-unit tagging of stacks (no item-level identity in 2.x without spoilage/quality hacks).

## 2026-10-19 — Simple and Complex modes; settings as map settings
**Why:** Sal likes "complexity pays" but fears a hard game gets shelved. Simple = 8 shifts, flat markup, all tech for sale (recommended first run). Complex = 10 shifts, value x (0.6 + 0.2 x recipe depth) up to 2.6x, tech zoned by bought plots (oil 2, blue 4, purple/yellow 6), vanilla techs disabled to match. Rules live in runtime-global mod settings so the main menu sets defaults and Run Setup writes back.
**Rejected:** plot gating in Simple (Sal never needed land, but forcing it on a first run is the shelving risk).

## 2026-10-15 — Pure mod that hijacks freeplay, not a scenario
**Why:** a mod can be launched straight into a run (`--create` + `--load-game`), works from New Game → Freeplay, and builds its own surface in `on_init`, so map settings don't matter.
**Rejected:** a scenario (needs the scenario picker, no clean CLI path; `--load-scenario` isn't a client flag).

## 2026-10-15 — Isolated play profile in `.profile/`
**Why:** the user's Factorio has Space Age on; QUOTA needs vanilla. A separate config/mods/saves dir keeps their saves and mod set untouched while borrowing graphics and keybinds from their config.ini.
**Rejected:** installing into `%APPDATA%\Factorio\mods` and flipping their mod list (`install/quota_1.0.0.zip` stays available for anyone who wants that).

## 2026-10-15 — Item values derived from the recipe graph
**Why:** every item gets a price without a hand table; crafted goods are worth more than inputs via MARKUP and TIME_VALUE.
**Rejected:** a hand-maintained price table (drifts, misses items). Crude oil pinned at 0.15 so oil is worth processing.

## 2026-10-15 — Company property instead of high crate markups
**Why:** anything a pod delivers marks that many units as scrap-only when sold (decays ×0.5/shift), which already blocks buy-and-flip. So crates sell near value: machines ×0.8, products ×1.25.
**Rejected:** ×2.5 product markup (Security Kit cost ~$10k at shift 4, when raids start; double protection).

## 2026-10-15 — 90 second breaks, terminals closed during breaks
**Why:** long enough to shop and re-plan; closing terminals stops stockpile-dumping into the next quota. Early clock-in pays a bonus.
**Rejected:** 75 s (design doc first draft): too tight to read three contracts and the next-shift preview.

## 2026-10-15 — Always day; night only as the Eclipse condition
**Why:** a timer game in vanilla darkness is miserable, and it made the Eclipse condition meaningless. Night Owl reworked to pay in the last 90 s of a shift and through an Eclipse.
**Rejected:** a normal day/night cycle with higher min_brightness (still murky, and solar would never be a choice).

## 2026-10-15 — Vanilla research stays available
**Why:** labs + science packs are a legitimate alternate route; science packs also sell. The Catalog's R&D is the fast route.
**Rejected:** disabling research (fights the base game for no gain).

## 2026-10-15 — 30 second briefing before shift 1
**Why:** first playtest: the shift timer starting the moment you sign left no time to find the starter kit and read the HUD. It is a break with `q.briefing` set, so the countdown, preview and early clock-in come for free.
**Rejected:** a longer first shift (the timer still runs while you are lost); pausing the game (Factorio has no clean pause for a single player mod).
