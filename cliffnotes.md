# QUOTA — CliffNotes

> Living map of the project. Read this before any coding session.
> Last updated: 2026-10-15. Design → `plans/2026-10-15-quota-design.md` · visuals → `ui.md` · checks → `verify.md`

## What this is

**QUOTA: The Factory Must Grow (Or Else)**: a single-player Factorio 2.1 mod that turns any new game
into a ~1 hour roguelite. Lethal Company's quota loop, Balatro's shop, Factorio's factory: you ship
products into a Shipping Terminal against a timer and a rising quota, and between shifts you buy
contracts (jokers), instant tech, drop-pod supplies and new land that rises out of the sea. Pure Lua
mod (no scenario); it hijacks freeplay from `on_init`.

## Quick Reference

- **Play:** double-click `play.cmd` (fresh run) or `play.cmd -Continue`. First run calls
  `install/setup.ps1`, which builds the isolated profile in `.profile/`. **Mac:** `./play.sh`
  (`--continue`, `--setup`) does setup and launch in one script.
- **Repo:** public https://github.com/dested/factorio-quota (branch main). New machine: clone, then
  `install/setup.ps1 -Shortcut` (needs only Factorio 2.1).
- **Lint Lua:** `bun run lint` (syntax, undefined globals, unused locals, missing module members)
- **Typecheck tools:** `bun run typecheck` (only the TS in `tools/`)
- **Release zip:** `bun run package` → `dist/quota_<version>.zip` (checks info.json, changelog entry, thumbnail).
  Upload to the mod portal by hand (name `quota` was free on 2026-10-19).
- **Scenario + dormancy:** the released mod only runs in its scenario (`mod/scenarios/quota/`, New Game →
  Scenarios → QUOTA): `wanted()` in control.lua checks `script.level.mod_name == "quota"`. Anywhere else
  `storage.q` stays nil and every handler no-ops. The launchers and test harnesses enable a marker mod
  (`install/quota-dev`, `quota-autotest`, `quota-shots`) so a plain `--create` map runs QUOTA.
- **Headless full-run test:** `bash tools/run-autotest.sh` → `passes=N fails=0 script_errors=0 done=1`
- **Screenshots in a real client:** `bash tools/run-shots.sh` (plan = `PLAN` in `tools/shots/control.lua`)
- **Sounds:** `bun run sounds` regenerates `mod/sound/*.wav` (deterministic)
- **Factorio:** 2.1.22 Steam, `C:\Program Files (x86)\Steam\steamapps\common\Factorio`. Space Age is
  installed and supported (autotest with `QUOTA_MODS=.factorio-test/sa-mods`); the play profile keeps
  it off. Offworld raws (`C.OFFWORLD_RAWS`) and recycling recipes never set prices.
- **Units:** money is plain numbers (`U.money` formats); time is ticks (60/s), config durations
  are written `N * 60`; a plot is 64×64 tiles, grid is −4..4 on both axes, HQ plot at 0,0.

## Stack

| Layer | Choice | Notes |
| --- | --- | --- |
| Game | Factorio 2.1 Lua mod `quota` | `mod/`, info.json `factorio_version 2.1` |
| State | `storage.q` (one table) | built by `SF.fresh_state`; only data + LuaObject refs |
| GUI | Factorio GUI elements, custom styles | `mod/prototypes/styles.lua`, `ui.md` |
| Tooling | Bun + strict TypeScript | `tools/*.ts`, `package.json`, `tsconfig.json` |
| Tests | Remote-interface driven mods | `tools/autotest/` headless, `tools/shots/` real client |

## Directory structure

```
play.cmd                     Double-click launcher → install/play.ps1
play.sh                      macOS launcher: builds .profile/ (quota symlink) on first run, --create, then `open -n factorio.app --args --load-game`
install/
  setup.ps1                  Builds .profile/ (config copy, quota junction, mod-list) + quota_1.0.0.zip; -Shortcut adds a desktop QUOTA.lnk
  quota.ico                  Shortcut icon (mod/thumbnail.png wrapped as an .ico)
  play.ps1                   --create a fresh save, then Start-Process --load-game it (-Continue: latest save)
  quota_1.0.0.zip            Built by setup.ps1 for a normal mods folder (gitignored)
mod/                         THE MOD (junctioned into .profile/mods/quota and .factorio-test/*-mods/quota)
  info.json                  name quota, deps base >= 2.1.0, ! space-age
  control.lua                Events, guard() error wrapper, intro cutscene, GUI router, remote "quota"
  data.lua                   Requires prototypes/*
  settings.lua               Map settings: mode, difficulty, length, knobs, 20 switches; per-user HUD corner
  thumbnail.png              144×144 mod-list art (terminal + QUOTA)
  prototypes/
    entities.lua             quota-terminal, quota-supply-pod, quota-meteor, quota-auditor, pad tiles, pod sprites
    styles.lua               quota_* GUI styles (cards, HUD frame, bars, plot buttons)
    fonts.lua                quota-huge/title/big/mid display fonts
    sounds.lua               Custom + vanilla-backed sound prototypes (celesta notes, whistle, cash, trombone)
    inputs.lua               J = toggle Catalog
  locale/en/quota.cfg        Entity/item names
  sound/*.wav                whistle, cash, trombone (from tools/make-sounds.ts)
  lib/
    config.lua               ALL tuning: shifts, quotas, difficulties, markups, hazards, starter kit, zoning
    rules.lua                R: run rules (mode, difficulty, length, knobs, threat switches) <-> runtime-global mod settings
    zoning.lua               Z: Complex-mode tech tiers by science pack, plots needed, disables locked vanilla techs
    util.lua                 RNG (seeded, in storage), formatting (money/time/pct), colors, fly-text, chat
    values.lua               Item values from the recipe graph (waves), depth + pricing recipe, Complex premium
    market.lua               Prices: value × hot × flood × hooks; hot rolls; flood integration; price list
    ledger.lua               Wallet: ship (counts to quota), bonus (wallet only), spend, catalog_mult
    perks.lua                30 contracts + 5 R&D upgrades; apply() diffs force modifiers idempotently
    shop.lua                 Catalog backend: R&D, upgrades, crates, mystery, terminals, land, contracts, corporate offers
    shift.lua                Run lifecycle: new_world, start_run, start_shift, end_shift, start_break, endless, reapply
    conditions.lua           Shift conditions (eclipse, gremlins, quakes, strike, raids, rush, audit…)
    events.lua               Mid-shift random events (flash sale, bounty, supply, rally, meteor, gremlin, crash, raid)
    hazards.lua              Hazard machinery: disable ledger, gremlins, strikes, quakes, meteors, raids
    auditor.lua              Final-shift boss: spawn, walk terminal to terminal, freeze, bounty
    terminals.lua            Terminal registry, 30-tick sales sweep, labels, launch anim, hold-while-open
    delivery.lua             Drop pods: falling anim, landing spot, landing alert + gps pin
    world.lua                Island grid, plot types, terrain paint, rising land, FOR SALE signs, surface
    anim.lua                 storage.q.jobs dispatcher (rise, pod, launch)
    sfx.lua                  Sounds + scheduled celesta jingles
    gui/
      common.lua             G.ui state, label/button/icon/window helpers, G.item_icon (recipe hover), checkbox, dropdown
      hud.lua                Compact HUD, bottom-right by default (per-player setting quota-hud-position)
      market_panel.lua       MP: collapsible MARKET side panel (gui.left), top 14 prices, next-shift preview in breaks
      handbook.lua           HB: Company Handbook, every contract/condition/event/tech/crate/plot/offer + switches
      catalog.lua            Catalog / Break Room window (tabs: Contracts, Tech, Supplies, Land, Market)
      screens.lua            Run Setup (mode, difficulty, threats, fine print), Corporate Offer, end screen
      main.lua               Which windows each phase shows (refresh / refresh_all / update_all)
tools/
  lualint.ts                 Lua linter (luaparse)
  make-sounds.ts             Synthesises mod/sound/*.wav
  run-autotest.sh            Headless: --create + --benchmark with quota-autotest, prints verdict
  run-shots.sh               Real client: --create + Start-Process --load-game, waits for done.txt, kills it
  autotest/                  quota-autotest mod: drives a whole run via remote calls, PASS/FAIL log
  shots/                     quota-shots mod: screenshot plans "full" / "quick" / "thumb"
plans/                       Dated working docs (design doc lives here)
.profile/                    Isolated play profile (gitignored): config, mods, saves, logs
.factorio-test/              Test profile (gitignored): config, test-mods/, shot-mods/, saves, script-output
```

## File map (concept → path)

| Concept / task | Location |
| --- | --- |
| Tune quotas, shift lengths, break, difficulties | `mod/lib/config.lua` (`C.SHIFTS`, `C.DIFFICULTIES`, `C.BREAK_SECONDS`) |
| Modes, threat switches, presets, Run Setup knobs | `mod/lib/rules.lua` + `mod/settings.lua` (setting `quota-s-<key>` per switch) |
| Complex zoning tiers | `mod/lib/zoning.lua`, `C.ZONING`, `C.PACK_TIERS` |
| Starter kit / character kit / starting techs | `mod/lib/config.lua` (`C.STARTER_KIT`, `C.CHARACTER_KIT`, `C.STARTING_TECHS`) |
| Item values / raw prices | `mod/lib/values.lua`, `C.RAW_VALUES`, `C.VALUE_OVERRIDES`, `C.VALUE_SCALE`, `C.NOT_HOT` |
| Sale price formula, flooding, hot items | `mod/lib/market.lua` |
| Add / change a contract | `mod/lib/perks.lua` (`P.DEFS` + effect in `price_mult`/`apply`/callers) |
| R&D catalog, crates, land prices, corporate offers | `mod/lib/shop.lua` |
| Shift flow, payday, warnings, fired/promoted | `mod/lib/shift.lua` |
| Conditions | `mod/lib/conditions.lua` (defs, roll, price hook) + `mod/lib/hazards.lua` |
| Mid-shift events | `mod/lib/events.lua` |
| Plot types, terrain, rising land | `mod/lib/world.lua` (`W.TYPES`, features) |
| HUD | `mod/lib/gui/hud.lua` |
| Catalog / Break Room tabs | `mod/lib/gui/catalog.lua` |
| GUI click handling | `mod/control.lua` (router on `tags.qa`) |
| Remote/debug API | `mod/control.lua` `remote.add_interface("quota", …)` |

## Systems

### Phases (`storage.q.phase`)

`orientation` (intro cutscene → difficulty pick → TAKE THE JOB) → briefing (a 30 s `break` with
`q.briefing` set: no report, no contracts, no window; clock in early or let it run out) → `shift` → `break` → `shift` … →
after shift 8: `promoted` (Keep working = endless, Retire = `retired`, New run) or at any miss with
no warnings left: `fired` (Reapply = new surface + fresh state; J reopens the end screen after
"Look around"; the retired HUD carries a New run button). Missing the final shift while a
warning/Golden Parachute saves you re-runs shift 8 (re-audit). `GM.refresh(player, opening)` in
`gui/main.lua` decides which windows a phase shows; `opening` = the phase just began. Every break
opens the Break Room on the Contracts tab.

### Money

`L.ship` (terminal sales) adds to wallet **and** quota progress; `L.bonus` (overtime, interest,
bounties, auditor kill) adds to wallet only; `L.spend` checks and deducts. Catalog prices
× `L.catalog_mult` (rush fee 1.25 mid-shift, Black Market discount). Supply crates are priced at
item value × 0.8 (machines) or × 1.25 (products); everything a pod delivers is "company property":
that many units of each product later sell for scrap, decaying ×0.5 per shift.

### Shifts at Associate (×0.6 Intern, ×1.4 Crunch)

Quotas 400 / 1100 / 2400 / 4200 / 6800 / 10500 / 15500 / 22000, lengths 300–480 s, 90 s breaks,
~61 min total. Conditions from shift 2 (Intern: shift 3), two per shift from shift 7 (Crunch: 5) and in endless. Shift 8
is The Audit. Endless: ×1.45 quota per shift, Audit every 3rd endless shift. Corporate Offer after
shifts 3 and 6.

### Day and night

The run surface is `always_day`. Only the Eclipse condition turns night on (freezes daytime at
0.5) and restores day when the shift ends. Night Owl pays in the last 90 s of a shift and during
an Eclipse.

### Remote interface `quota` (tests and debugging)

`state, dump, start(diff | rules table), set_rules(fields), values(names), zoning(), skip, advance(s), money(n), ship(n), clock_in, fire_event(id), buy(kind,a,b)→{ok,msg},
terminal_insert(item,n), grant_perk(id), set_conditions(ids), hazard(kind), price(item), value(item),
reapply, endless, skip_intro, jump(n) (break only), set(key,value), gui(tab|"orientation"|"handbook"|"close"|"refresh"), select_plot(px,py)`.
`advance` moves the shift timer, not game ticks, so anything with a tick TTL (raid warning text) can
outlive a debug jump.

## Gotchas

- `require` only at file top level (runtime require errors).
- `LuaEntity.active` is read-only in 2.x: disable with `disabled_by_script` + `custom_status`.
- `utility/*_modifier_icon` sprites like `ammo_damage_modifier_icon` are the generic red "+"
  placeholder. Use `technology/<name>` sprites for upgrade icons.
- Factorio 2.1 ships a built-in `recycler` mod besides quality/elevated-rails/space-age; disable it
  in any mod-list you write.
- The Steam build re-launches itself through Steam. Start the client with PowerShell `Start-Process`
  and Windows paths (`cygpath -w`); a bash `&` launch silently never starts. `--create` and
  `--benchmark` are headless and can be run directly.
- Windows PowerShell `Start-Process -ArgumentList` does not quote: wrap every path in quotes yourself
  (`Quote` in play.ps1) or a clone path with a space breaks the launch.
- play.ps1 starts Steam first when the exe lives under steamapps and Steam is not running, and
  writes `.profile/play.log`; on failure it prints the end of `.profile/factorio-current.log`.
- Kill only our test client: match `factorio.exe` whose command line contains `factorio-test`.
- A real-client screenshot run stalled once when its window was buried behind others. Keep it visible.
- In tools TS, never name a function `declare`: bun strips `declare(...)` statements.
- `LuaPlayer.position`/`.surface` follow the map camera in 2.x. Anything about where the player
  physically is (gremlin whacks, pod drops) reads `player.character`.
- Hot multipliers are stored raw; Hype Machine is added when read (`M.boosted`) and Insider
  Trading's slot is synced on sign/sell (`M.sync_insider`), so contracts count from the next shift.
- Calling the remote `start` during the intro cutscene skips the character kit (no `player.character`
  in cutscene). Real play can't reach it; test plans should wait for the intro (~7 s) or `skip_intro`.

## Status

v2 (2026-10-19, plan `plans/2026-10-19-v2.md`): Run Setup (Simple 8 shifts / Complex 10 with Complexity Pays
+ zoning), 20 threat switches as map settings, Handbook, compact HUD, MARKET side panel, Company-issue items,
terminal hold-while-open, Tech tab explainer. Autotest 119/0 across a Simple and a Complex run. The v2 GUIs
have not been through a real-client screenshot pass yet. Sal has played v1 end to end several times.
- A Handbook opened from the Catalog takes `player.opened`; the Catalog's on_gui_closed is ignored while the
  Handbook is open, and closing the Handbook hands `opened` back to the Catalog.
- Our own `settings.global` writes raise `on_runtime_mod_setting_changed`; control.lua's `writing_rules` flag
  skips them.
