#!/usr/bin/env bash
# Headless full-run test: creates a fresh save with quota + quota-autotest,
# runs it in benchmark mode, and prints the autotest verdict.
# Needs .factorio-test/ set up (see verify.md). QUOTA_MODS=<dir> picks another
# mod directory (e.g. .factorio-test/sa-mods for Space Age + Quality).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE="${FACTORIO_EXE:-C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe}"
CFG="$ROOT/.factorio-test/factorio-user/config/config.ini"
MODS="${QUOTA_MODS:-$ROOT/.factorio-test/test-mods}"
OUT="$ROOT/.factorio-test/factorio-user/script-output/quota-autotest.log"
LOG="$ROOT/.factorio-test/factorio-user/factorio-current.log"
TICKS="${1:-30000}"

mkdir -p "$ROOT/.factorio-test/saves"
rm -f "$OUT"
"$EXE" --config "$CFG" --mod-directory "$MODS" --create "$ROOT/.factorio-test/saves/autotest.zip" > /dev/null 2>&1 || { echo "create failed"; tail -20 "$LOG"; exit 1; }
# on_init runs during --create: its errors are in this log, which the benchmark overwrites.
init_errors=$(grep -c "\[quota\]" "$LOG")
grep "\[quota\]" "$LOG" | head -5
"$EXE" --config "$CFG" --mod-directory "$MODS" --benchmark "$ROOT/.factorio-test/saves/autotest.zip" --benchmark-ticks "$TICKS" --disable-audio > /dev/null 2>&1 || { echo "benchmark failed"; tail -30 "$LOG"; exit 1; }

errors=$(( $(grep -c "\[quota\]" "$LOG") + init_errors ))
fails=$(grep -c "^FAIL" "$OUT")
passes=$(grep -c "^PASS" "$OUT")
grep "^FAIL" "$OUT" | head -20
grep "\[quota\]" "$LOG" | head -20
echo "passes=$passes fails=$fails script_errors=$errors done=$(grep -c '^DONE' "$OUT")"
[ "$fails" -eq 0 ] && [ "$errors" -eq 0 ] && grep -q "^DONE" "$OUT"
