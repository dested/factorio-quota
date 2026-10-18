# Updates

Newest first. One entry per finished task.

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
