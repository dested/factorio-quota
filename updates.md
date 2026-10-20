# Updates

Newest first. One entry per finished task.

## 2026-10-19 — QUOTA 2.0.0 release build
Mod ships as a scenario (New Game > Scenarios > QUOTA) and stays dormant in other games; Space Age supported (offworld raws and recycling don't price); `bun run package` builds dist/quota_2.0.0.zip; changelog, README pitch. Market panel redone as HOT (usual x mult = now) + TOP PRICES; Market tab columns aligned. Autotest 120/0 vanilla and Space Age; release zip verified active in scenario, dormant in freeplay. run-autotest now also fails on on_init errors.
Touched: mod/control.lua, mod/info.json, mod/changelog.txt, mod/scenarios/quota/*, mod/lib/{values,config}.lua, mod/lib/gui/{market_panel,catalog}.lua, install/{setup,play}.ps1, install/quota-dev, play.sh, tools/{package.ts,run-autotest.sh}, README.md, package.json

## 2026-10-19 — v2 from Sal's playtest
Run Setup replaces the difficulty pick: Simple (8 shifts) or Complex (10, Complexity Pays, zoning by plots owned), difficulty, threat presets + 20 switches, fine print; all backed by map settings. Removing the property counter fixes the $1 ammo (Company-issue copies tried, then dropped at Sal's call); no meteor shower/gremlins before shift 4, lighter early meteors, ghosts on death; kit 2 boilers / 2 engines / 100 coal / 20 repair packs; shotgun shells x0.8 and never hot. Compact bottom-right HUD, MARKET side panel, Handbook, recipe tooltips on item icons, drop-pod alerts, terminal holds while open, Tech tab explains it is Factorio's tree bought outright. Autotest 119/0; GUIs not yet screenshot-checked.
Electric Furnaces tech ($3,500 after Chemical Science). Run Setup fits small screens (scrolls), dropdown lock-up fixed. Clock out early once quota is met (HUD button, two clicks, 1% of quota per 10 s left, cap 25%, never on The Audit).
Touched: mod/settings.lua, mod/control.lua, mod/data.lua, mod/lib/{rules,zoning,config,values,market,conditions,events,hazards,delivery,terminals,shop,shift,world,perks}.lua, mod/lib/gui/{common,hud,market_panel,handbook,catalog,screens,main}.lua, mod/prototypes/{issued,entities,styles,fonts}.lua, mod/locale/en/quota.cfg, tools/autotest/control.lua

## 2026-10-17 — play it on a Mac
play.sh: finds factorio.app (Steam, /Applications, Spotlight), builds the same isolated profile, checks 2.1+, starts Steam, creates and opens a fresh run. Dry-run tested with a stubbed app; not yet run on a real Mac.
Touched: play.sh, cliffnotes.md

## 2026-10-16 — launcher failed silently on a second PC
play.ps1 now quotes its paths, checks Factorio >= 2.1, starts Steam if needed, refuses a second copy, logs to .profile/play.log and pauses on errors with Factorio's log tail (play.cmd and the shortcut pass -Pause).
Touched: install/play.ps1, install/setup.ps1, play.cmd, cliffnotes.md

## 2026-10-16 — desktop shortcut + private GitHub repo
Desktop QUOTA.lnk with the mod icon; setup.ps1 -Shortcut makes one on any machine. First commit, pushed to private github.com/dested/factorio-quota.
Touched: install/setup.ps1, install/quota.ico, cliffnotes.md

## 2026-10-15 — time to get your bearings before shift 1
Run now opens with a 30 s briefing (HUD countdown, shift 1 preview, clock in early) instead of starting the shift on the spot. Orientation button is TAKE THE JOB. Autotest 102/0.
Touched: mod/lib/shift.lua, mod/lib/config.lua, mod/lib/gui/{main,hud,catalog,screens}.lua, mod/control.lua, tools/autotest/control.lua, tools/shots/control.lua

## 2026-10-15 — build QUOTA, an hour-long single-player Factorio roguelite
Built the `quota` mod: 8 timed shifts against rising quotas, Balatro-style Catalog between shifts (30 contracts, R&D, drop-pod crates, rising land), 14 conditions, 8 events, Audit boss, endless, fired/reapply. Headless autotest + real-client screenshot harness, isolated play profile with `play.cmd`. Per plans/2026-10-15-quota-design.md.
Review fixes: gremlin-jammed machines now restart, whacks need the real character (not the map camera), J reopens the end screen, Retire has New run, Hype/Insider count from the next shift. Autotest 99/0.
Touched: mod/**, install/setup.ps1, install/play.ps1, play.cmd, tools/**, package.json, tsconfig.json, cliffnotes.md, ui.md, decisions.md, verify.md
