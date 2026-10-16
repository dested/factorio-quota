#!/usr/bin/env bash
# Screenshot run in a real (windowed) Factorio client: creates a fresh save
# with quota + quota-shots, opens it, waits for the driver to finish, then
# closes that client. PNGs land in
# .factorio-test/factorio-user/script-output/quota-shots/.
# The plan (full or quick) is the PLAN constant in tools/shots/control.lua.
# Keep the window visible while it runs: a hidden window can stall it.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE="${FACTORIO_EXE:-C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe}"
CFG="$ROOT/.factorio-test/factorio-user/config/config.ini"
MODS="$ROOT/.factorio-test/shot-mods"
OUT="$ROOT/.factorio-test/factorio-user/script-output/quota-shots"
LOG="$ROOT/.factorio-test/factorio-user/factorio-current.log"
SAVE="$ROOT/.factorio-test/saves/shots.zip"
WAIT="${1:-240}"

# Our client is the one whose command line points at .factorio-test.
kill_client() {
  powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='factorio.exe'\" | Where-Object { \$_.CommandLine -like '*factorio-test*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" > /dev/null 2>&1
}

kill_client
rm -rf "$OUT"
mkdir -p "$ROOT/.factorio-test/saves"
"$EXE" --config "$CFG" --mod-directory "$MODS" --create "$SAVE" > /dev/null 2>&1 || { echo "create failed"; tail -20 "$LOG"; exit 1; }
# Start-Process with Windows paths, not a bash "&": the Steam build
# re-launches itself through Steam, and that only worked this way.
w() { cygpath -w "$1"; }
powershell -NoProfile -Command "Start-Process -FilePath '$(w "$EXE")' -ArgumentList '--config','$(w "$CFG")','--mod-directory','$(w "$MODS")','--load-game','$(w "$SAVE")'" || { echo "launch failed"; exit 1; }

for _ in $(seq 1 "$WAIT"); do
  [ -f "$OUT/done.txt" ] && break
  sleep 1
done
kill_client

ls "$OUT" 2>/dev/null | grep -c "\.png$" | sed 's/^/pngs=/'
grep "ERROR" "$OUT/log.txt" 2>/dev/null
grep "\[quota\]" "$LOG" | head -20
if [ -f "$OUT/done.txt" ]; then echo "done"; else echo "timed out; last steps:"; tail -5 "$OUT/log.txt" 2>/dev/null; exit 1; fi
