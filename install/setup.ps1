# Sets up an isolated Factorio profile for QUOTA in <repo>\.profile and builds
# install\quota_1.0.0.zip. Your normal Factorio install, saves and mods (Space
# Age included) are never touched: the profile has its own config, mods and
# saves, and only borrows your graphics and keybind settings.
#
#   powershell -ExecutionPolicy Bypass -File install\setup.ps1 [-FactorioExe <path>] [-Shortcut]
#
# -Shortcut also puts a QUOTA shortcut on the desktop (fresh run on double-click).
param([string]$FactorioExe, [switch]$Shortcut)
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$modDir = Join-Path $repo 'mod'
$profileDir = Join-Path $repo '.profile'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Find-Factorio {
  $candidates = @()
  if ($FactorioExe) { $candidates += $FactorioExe }
  if ($env:FACTORIO_EXE) { $candidates += $env:FACTORIO_EXE }
  foreach ($key in @(
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 427520',
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Factorio_is1')) {
    $loc = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).InstallLocation
    if ($loc) { $candidates += (Join-Path $loc 'bin\x64\factorio.exe') }
  }
  $candidates += 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
  $candidates += 'C:\Program Files\Factorio\bin\x64\factorio.exe'
  foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path } }
  throw 'Could not find factorio.exe. Re-run with -FactorioExe "<path to factorio.exe>".'
}

$exe = Find-Factorio
$dataDir = (Resolve-Path (Join-Path (Split-Path -Parent $exe) '..\..\data')).Path
Write-Host "Factorio: $exe"

foreach ($d in @('config', 'mods', 'saves')) {
  New-Item -ItemType Directory -Force -Path (Join-Path $profileDir $d) | Out-Null
}
[IO.File]::WriteAllText((Join-Path $profileDir 'exe.txt'), $exe, $utf8)

# config.ini: a copy of yours (graphics, sound, keybinds) with the data paths
# pointed at this profile.
$userCfg = Join-Path $env:APPDATA 'Factorio\config\config.ini'
$lines = if (Test-Path $userCfg) { Get-Content $userCfg } else { @() }
$out = New-Object System.Collections.Generic.List[string]
$version = $lines | Where-Object { $_ -match '^\s*;\s*version=' } | Select-Object -First 1
if ($version) { $out.Add($version) }
$out.Add('[path]')
$out.Add("read-data=$dataDir")
$out.Add("write-data=$profileDir")
$skip = $false
foreach ($l in $lines) {
  if ($l -match '^\s*;\s*version=') { continue }
  if ($l -match '^\[(.+)\]\s*$') { $skip = ($Matches[1] -eq 'path') }
  if (-not $skip) { $out.Add($l) }
}
[IO.File]::WriteAllText((Join-Path $profileDir 'config\config.ini'), ($out -join "`r`n") + "`r`n", $utf8)

# mods: QUOTA (a junction to the repo, so edits are live) and plain vanilla.
$link = Join-Path $profileDir 'mods\quota'
if (-not (Test-Path $link)) {
  New-Item -ItemType Junction -Path $link -Target $modDir | Out-Null
}
$modList = @'
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
'@
[IO.File]::WriteAllText((Join-Path $profileDir 'mods\mod-list.json'), $modList, $utf8)
Write-Host "Profile ready: $profileDir"

# Zip for dropping into a normal Factorio mods folder.
$info = Get-Content (Join-Path $modDir 'info.json') -Raw | ConvertFrom-Json
$folder = "quota_$($info.version)"
$stage = Join-Path $profileDir 'build'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Recurse -Path $modDir -Destination (Join-Path $stage $folder)
$zip = Join-Path $PSScriptRoot "$folder.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
& "$env:SystemRoot\System32\tar.exe" -a -c -f $zip -C $stage $folder
Remove-Item -Recurse -Force $stage
Write-Host "Mod zip: $zip"

if ($Shortcut) {
  $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'QUOTA.lnk'
  $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
  $sc.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
  $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'play.ps1')`" -Pause"
  $sc.WorkingDirectory = $repo
  $sc.IconLocation = "$(Join-Path $PSScriptRoot 'quota.ico'),0"
  $sc.Description = 'QUOTA: The Factory Must Grow (Or Else). Starts a fresh run.'
  $sc.Save()
  Write-Host "Shortcut: $lnk"
}
