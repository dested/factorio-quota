# Launches QUOTA in its isolated profile (see setup.ps1).
#   play.ps1             a fresh run, straight onto the island
#   play.ps1 -Continue   load the most recent save or autosave
#   play.ps1 -Pause      keep the window open if anything fails (the desktop shortcut passes it)
# Every launch writes .profile\play.log; on failure it also shows the end of
# Factorio's own log.
param([switch]$Continue, [switch]$Pause)
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$profileDir = Join-Path $repo '.profile'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
$playLog = Join-Path $profileDir 'play.log'
Set-Content -Path $playLog -Value "QUOTA launch $(Get-Date -Format s)"

function Say([string]$text) {
  Write-Host $text
  Add-Content -Path $playLog -Value $text
}

# Windows PowerShell joins Start-Process arguments with bare spaces, so any
# path with a space in it has to carry its own quotes.
function Quote([string]$s) { '"' + $s + '"' }

function Wait-For([scriptblock]$done, [int]$seconds) {
  for ($i = 0; $i -lt $seconds; $i++) {
    if (& $done) { return $true }
    Start-Sleep -Seconds 1
  }
  return (& $done)
}

try {
  if (-not (Test-Path (Join-Path $profileDir 'exe.txt'))) {
    Say 'First launch: setting up the QUOTA profile...'
    & (Join-Path $PSScriptRoot 'setup.ps1')
  }
  $exe = (Get-Content (Join-Path $profileDir 'exe.txt') -Raw).Trim()
  if (-not (Test-Path $exe)) { throw "Factorio is no longer at $exe. Run install\setup.ps1 again." }
  $cfg = Join-Path $profileDir 'config\config.ini'
  $mods = Join-Path $profileDir 'mods'
  $saves = Join-Path $profileDir 'saves'

  $ver = [version]'0.0'
  $pv = (Get-Item $exe).VersionInfo.ProductVersion
  if ($pv -and [version]::TryParse($pv, [ref]$ver)) {
    Say "Factorio $ver ($exe)"
    if ($ver -lt [version]'2.1') {
      throw "QUOTA needs Factorio 2.1 or newer and this is $ver. Update the game (Steam: Factorio > Properties > Betas if 2.1 is not the default yet)."
    }
  } else {
    Say "Factorio at $exe (version unknown)"
  }

  $running = Get-CimInstance Win32_Process -Filter "Name='factorio.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profileDir) }
  if ($running) { throw 'QUOTA is already open. Close that Factorio window first.' }

  # The Steam build hands itself to Steam when Steam is not running, which
  # can drop the arguments. Start Steam first.
  if ($exe -match '\\steamapps\\' -and -not (Get-Process -Name steam -ErrorAction SilentlyContinue)) {
    Say 'Steam is not running. Starting it...'
    Start-Process 'steam://open/main'
    if (-not (Wait-For { Get-Process -Name steam -ErrorAction SilentlyContinue } 60)) {
      throw 'Steam did not start. Start Steam, sign in, then try again.'
    }
    Start-Sleep -Seconds 10
  }

  if ($Continue) {
    $latest = Get-ChildItem -Path $saves -Filter '*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { throw "No saves yet in $saves. Launch without -Continue to start a run." }
    $save = $latest.FullName
  } else {
    # A new map with QUOTA loaded: the mod takes over from the first tick.
    $save = Join-Path $saves ('quota-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.zip')
    Say 'Creating a new run (Factorio loads its data first, give it a moment)...'
    $create = Start-Process -FilePath $exe -PassThru -WindowStyle Hidden `
      -ArgumentList @('--config', (Quote $cfg), '--mod-directory', (Quote $mods), '--create', (Quote $save))
    if (-not $create.WaitForExit(300000)) {
      $create.Kill()
      throw 'Creating the run took more than 5 minutes.'
    }
    # If Steam relaunched it, the first process exits early: wait for the save.
    if (-not (Wait-For { Test-Path $save } 60)) {
      throw "Factorio did not create $save."
    }
    $creating = { Get-CimInstance Win32_Process -Filter "Name='factorio.exe'" |
      Where-Object { $_.CommandLine -and $_.CommandLine.Contains('--create') -and $_.CommandLine.Contains($profileDir) } }
    if (-not (Wait-For { -not (& $creating) } 120)) { throw 'Factorio is still writing the new save.' }
  }

  Say "Starting Factorio with $save"
  Start-Process -FilePath $exe `
    -ArgumentList @('--config', (Quote $cfg), '--mod-directory', (Quote $mods), '--load-game', (Quote $save))
  Say 'Factorio is starting. This window can close.'
} catch {
  Say ''
  Say "QUOTA could not start: $($_.Exception.Message)"
  $factorioLog = Join-Path $profileDir 'factorio-current.log'
  if (Test-Path $factorioLog) {
    Say ''
    Say "End of $factorioLog :"
    Get-Content $factorioLog -Tail 25 | ForEach-Object { Say "  $_" }
  }
  Say ''
  Say "This is saved in $playLog"
  if ($Pause) { Read-Host 'Press Enter to close' | Out-Null }
  exit 1
}
