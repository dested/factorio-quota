#!/bin/bash
# QUOTA on macOS. The first run builds an isolated profile in <repo>/.profile
# (its own config, mods and saves; your normal Factorio saves and mods are
# never touched), then every run starts a fresh QUOTA run.
#   ./play.sh              a fresh run
#   ./play.sh --continue   load the most recent save
#   ./play.sh --setup      rebuild the profile (after moving or updating Factorio)
# If it cannot find the game: FACTORIO_APP="/path/to/factorio.app" ./play.sh --setup
set -u

repo="$(cd "$(dirname "$0")" && pwd)"
profile="$repo/.profile"
mkdir -p "$profile"
log="$profile/play.log"
echo "QUOTA launch $(date '+%Y-%m-%dT%H:%M:%S')" > "$log"

say() { echo "$*"; echo "$*" >> "$log"; }

fail() {
  say ""
  say "QUOTA could not start: $*"
  if [ -f "$profile/factorio-current.log" ]; then
    say ""
    say "End of $profile/factorio-current.log :"
    tail -n 25 "$profile/factorio-current.log" | sed 's/^/  /' | tee -a "$log"
  fi
  say ""
  say "This is saved in $log"
  exit 1
}

# Waits up to $1 seconds for the command in the rest of the args to succeed.
wait_for() {
  local n=$1; shift
  while [ "$n" -gt 0 ]; do
    if "$@"; then return 0; fi
    sleep 1; n=$((n - 1))
  done
  "$@"
}

find_app() {
  local c
  for c in "${FACTORIO_APP:-}" \
    "$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app" \
    "/Applications/factorio.app" "/Applications/Factorio.app" "$HOME/Applications/factorio.app"; do
    if [ -n "$c" ] && [ -x "$c/Contents/MacOS/factorio" ]; then echo "$c"; return; fi
  done
  # Steam libraries on other drives, or any other install location.
  mdfind "kMDItemFSName == 'factorio.app'c" 2>/dev/null | while IFS= read -r c; do
    if [ -x "$c/Contents/MacOS/factorio" ]; then echo "$c"; break; fi
  done
}

setup() {
  local app data user_cfg
  app="$(find_app)"
  [ -n "$app" ] || fail "Could not find factorio.app. Run: FACTORIO_APP=\"/path/to/factorio.app\" ./play.sh --setup"
  data="$app/Contents/data"
  [ -d "$data" ] || fail "factorio.app has no data folder at $data"
  mkdir -p "$profile/config" "$profile/mods" "$profile/saves"
  printf '%s\n' "$app" > "$profile/app.txt"

  # config.ini: a copy of yours (graphics, sound, keybinds) with the data
  # paths pointed at this profile.
  user_cfg="$HOME/Library/Application Support/factorio/config/config.ini"
  {
    if [ -f "$user_cfg" ]; then grep -m1 -E '^[[:space:]]*;[[:space:]]*version=' "$user_cfg"; fi
    echo '[path]'
    echo "read-data=$data"
    echo "write-data=$profile"
    if [ -f "$user_cfg" ]; then
      awk '/^[[:space:]]*;[[:space:]]*version=/ { next }
           /^\[.*\][[:space:]]*$/ { skip = ($0 ~ /^\[path\]/) }
           !skip' "$user_cfg"
    fi
  } > "$profile/config/config.ini"

  # mods: QUOTA (a symlink to the repo) and plain vanilla.
  ln -sfn "$repo/mod" "$profile/mods/quota"
  cat > "$profile/mods/mod-list.json" <<'EOF'
{
  "mods": [
    { "name": "base", "enabled": true },
    { "name": "elevated-rails", "enabled": false },
    { "name": "quality", "enabled": false },
    { "name": "recycler", "enabled": false },
    { "name": "space-age", "enabled": false },
    { "name": "quota", "enabled": true }
  ]
}
EOF
  say "Profile ready: $profile"
}

continue_run=0
force_setup=0
for arg in "$@"; do
  case "$arg" in
    --continue|-Continue) continue_run=1 ;;
    --setup) force_setup=1 ;;
    *) fail "Unknown option $arg (use --continue or --setup)" ;;
  esac
done

if [ "$force_setup" = 1 ] || [ ! -f "$profile/app.txt" ]; then
  say 'Setting up the QUOTA profile...'
  setup
fi
app="$(cat "$profile/app.txt")"
exe="$app/Contents/MacOS/factorio"
[ -x "$exe" ] || fail "Factorio is no longer at $app. Run ./play.sh --setup"
cfg="$profile/config/config.ini"
mods="$profile/mods"
saves="$profile/saves"

ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null)"
if [ -n "$ver" ]; then
  say "Factorio $ver ($app)"
  major="${ver%%.*}"; rest="${ver#*.}"; minor="${rest%%.*}"
  case "$major$minor" in
    *[!0-9]*|'') ;;
    *) if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 1 ]; }; then
         fail "QUOTA needs Factorio 2.1 or newer and this is $ver. Update the game (Steam: Factorio > Properties > Betas if 2.1 is not the default yet)."
       fi ;;
  esac
else
  say "Factorio at $app (version unknown)"
fi

# Lines of `ps` that are this profile's Factorio (awk's own line starts with "awk").
ours() { ps -axwwo command= | awk -v p="$exe" -v q="$profile" -v r="${1:-}" 'index($0, p) == 1 && index($0, q) && (r == "" || index($0, r))'; }
[ -z "$(ours)" ] || fail 'QUOTA is already open. Quit that Factorio first.'

# The Steam build can hand itself to Steam when Steam is not running, which
# drops the arguments. Start Steam first.
steam_up() { pgrep -x steam_osx >/dev/null; }
case "$app" in
  */steamapps/*)
    if ! steam_up; then
      say 'Steam is not running. Starting it...'
      open -a Steam || fail 'Could not start Steam. Start it, sign in, then try again.'
      wait_for 60 steam_up || fail 'Steam did not start. Start it, sign in, then try again.'
      sleep 10
    fi ;;
esac

if [ "$continue_run" = 1 ]; then
  save="$(ls -t "$saves"/*.zip 2>/dev/null | head -n 1)"
  [ -n "$save" ] || fail "No saves yet in $saves. Run ./play.sh without --continue to start one."
else
  # A new map with QUOTA loaded: the mod takes over from the first tick.
  save="$saves/quota-$(date '+%Y%m%d-%H%M%S').zip"
  say 'Creating a new run (Factorio loads its data first, give it a moment)...'
  "$exe" --config "$cfg" --mod-directory "$mods" --create "$save" >> "$log" 2>&1
  # If Steam relaunched it, the first process exits early: wait for the save.
  wait_for 60 test -f "$save" || fail "Factorio did not create $save."
  creating() { [ -z "$(ours --create)" ]; }
  wait_for 120 creating || fail 'Factorio is still writing the new save.'
fi

say "Starting Factorio with $save"
open -n "$app" --args --config "$cfg" --mod-directory "$mods" --load-game "$save" \
  || fail "macOS would not open $app."
say 'Factorio is starting. This window can close.'
