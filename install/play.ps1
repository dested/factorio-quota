# Launches QUOTA in its isolated profile (see setup.ps1).
#   play.ps1             a fresh run, straight onto the island
#   play.ps1 -Continue   load the most recent save or autosave
param([switch]$Continue)
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$profileDir = Join-Path $repo '.profile'
if (-not (Test-Path (Join-Path $profileDir 'exe.txt'))) {
  & (Join-Path $PSScriptRoot 'setup.ps1')
}
$exe = (Get-Content (Join-Path $profileDir 'exe.txt') -Raw).Trim()
$cfg = Join-Path $profileDir 'config\config.ini'
$mods = Join-Path $profileDir 'mods'
$saves = Join-Path $profileDir 'saves'

if ($Continue) {
  $latest = Get-ChildItem -Path $saves -Filter '*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { throw "No saves yet in $saves. Run play.ps1 without -Continue to start a run." }
  $save = $latest.FullName
} else {
  # A new map with QUOTA loaded: the mod takes over from the first tick.
  $save = Join-Path $saves ("quota-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.zip')
  & $exe --config $cfg --mod-directory $mods --create $save | Out-Null
  if (-not (Test-Path $save)) { throw "Factorio could not create $save. See $profileDir\factorio-current.log" }
}

# Start-Process (detached): the Steam build re-launches itself through Steam
# and keeps these arguments.
Start-Process -FilePath $exe -ArgumentList @('--config', $cfg, '--mod-directory', $mods, '--load-game', $save)
Write-Host "Loading $save"
