# QUOTA — Verify

> How to prove the mod works. Scale to the change: [cheap] always, flow recipes when touched,
> [heavy — ask first] only after asking.

## Commands

| What | Command | Cost |
| --- | --- | --- |
| Lua lint | `bun run lint` | [cheap] |
| Typecheck tools | `bun run typecheck` | [cheap] |
| Headless full run (8 shifts, endless, fired, reapply, every shop kind) | `bash tools/run-autotest.sh` | [medium] (~30 s) |
| Profile sanity (mods load, map creates) | `P=.profile; "$(cat $P/exe.txt)" --config $P/config/config.ini --mod-directory $P/mods --create $P/saves/check.zip` then delete it | [medium] |
| Compat run (Quality, Elevated Rails, Recycler on; Space Age off) | same `--create` + `--benchmark` as run-autotest.sh with `--mod-directory .factorio-test/compat-mods` | [medium] |
| Real-client screenshots | `bash tools/run-shots.sh` (opens a Factorio window ~1 min) | [heavy — ask first] |
| Rebuild profile + zip | `powershell -ExecutionPolicy Bypass -File install/setup.ps1` | [cheap] |

## Test setup

`.factorio-test/` (gitignored) holds its own `factorio-user/config/config.ini` (windowed, write-data
inside), `test-mods/` (junctions quota → `mod`, quota-autotest → `tools/autotest`) and `shot-mods/`
(quota + quota-shots). Each mod-list disables elevated-rails, quality, recycler and space-age.
Outputs: `.factorio-test/factorio-user/script-output/quota-autotest.log` and `…/quota-shots/*.png`;
engine log `.factorio-test/factorio-user/factorio-current.log` (script errors appear as `[quota] …`).

## Critical flows

### Full run [medium]
Touchpoints: `lib/shift.lua`, `lib/ledger.lua`, `lib/market.lua`, `lib/shop.lua`, `lib/conditions.lua`, `control.lua`
1. `bash tools/run-autotest.sh` → `passes=N fails=0 script_errors=0 done=1`.

### Every screen renders [heavy — ask first]
Touchpoints: anything in `lib/gui/`, `prototypes/styles.lua`, world rendering
1. Set `PLAN` in `tools/shots/control.lua` (`quick` covers catalog tabs, HUD, break room, end screens; `full` adds hazards, auditor, land rising).
2. `bash tools/run-shots.sh` → `pngs=N`, `done`. Open the PNGs and look at them.

### Fresh launch [medium]
Touchpoints: `install/*.ps1`, `play.cmd`, `mod/info.json`
1. Run the profile sanity command above → log shows only `base` and `quota` loading, then `Goodbye`.
2. Launching the client itself (`play.cmd`) opens the game with the user's own window settings; do it only when asked.
