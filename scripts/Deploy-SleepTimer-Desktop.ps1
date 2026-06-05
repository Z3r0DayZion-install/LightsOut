#Requires -Version 5.1
<#
.SYNOPSIS
    Build + deploy Lights Out to Desktop\Lights Out\ (organized app folder).
#>
param([switch]$Launch)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$desktop = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desktop 'Lights Out'
$src = Join-Path $root 'SleepTimer-Tonight.ps1'
$outExe = Join-Path $appDir 'SleepTimer.exe'
$outPs1 = Join-Path $appDir 'source\SleepTimer-Tonight.ps1'
$bak = Join-Path $appDir 'archive\SleepTimer.exe.bak'
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()

Write-Host '=== Deploy Lights Out ===' -ForegroundColor Cyan
Write-Host "Folder: $appDir" -ForegroundColor DarkGray

New-Item -ItemType Directory -Path $appDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $appDir 'archive') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $appDir 'source') -Force | Out-Null

Get-Process SleepTimer,Nightfall -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# Migrate loose Desktop files from older deploys
foreach ($name in @(
    'SleepTimer.exe', 'SleepTimer.exe.bak', 'SleepTimer.ico', 'LightsOut-Logo.png'
    'Lights Out.bat', 'SleepTimer-Tonight.ps1', 'START TIMER.bat', 'channel.txt', 'README.txt'
)) {
    $loose = Join-Path $desktop $name
    if (-not (Test-Path $loose)) { continue }
    $dest = switch -Regex ($name) {
        'SleepTimer.exe.bak' { Join-Path $appDir 'archive\SleepTimer.exe.bak' }
        'SleepTimer-Tonight.ps1' { Join-Path $appDir 'source\SleepTimer-Tonight.ps1' }
        default { Join-Path $appDir $name }
    }
    if ($loose -ne $dest) { Move-Item $loose $dest -Force -ErrorAction SilentlyContinue }
}
# Flatten leftovers already inside app folder root
foreach ($name in @('SleepTimer.exe.bak', 'SleepTimer-Tonight.ps1')) {
    $flat = Join-Path $appDir $name
    if (-not (Test-Path $flat)) { continue }
    $dest = if ($name -like '*.bak') { Join-Path $appDir 'archive\SleepTimer.exe.bak' } else { Join-Path $appDir 'source\SleepTimer-Tonight.ps1' }
    Move-Item $flat $dest -Force -ErrorAction SilentlyContinue
}

$settingsDir = Join-Path $env:LOCALAPPDATA 'CoolTimer'
$settingsPath = Join-Path $settingsDir 'settings.json'
New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
if (-not (Test-Path $settingsPath)) {
    @{
        DefaultSeconds = 1700
        Action         = 'Shutdown'
        ConfirmAtEnd   = $true
        AutoStart      = $false
        TopMost        = $true
        WarnAt5Min     = $true
        DryRun         = $false
    } | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8
}

& (Join-Path $root 'scripts\Create-NightfallIcon.ps1') -ErrorAction SilentlyContinue
Copy-Item $src $outPs1 -Force

$ps2exeRoot = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\ps2exe'
$manifest = Get-ChildItem $ps2exeRoot -Recurse -Filter 'ps2exe.psd1' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $manifest) { throw 'ps2exe module not found' }
Import-Module $manifest.FullName -Force

$icon = Join-Path $root 'assets\SleepTimer.ico'
if (-not (Test-Path $icon)) { $icon = Join-Path $root 'assets\Nightfall.ico' }
if (Test-Path $outExe) { Copy-Item $outExe $bak -Force }
$params = @{
    inputFile   = $src
    outputFile  = $outExe
    noConsole   = $true
    STA         = $true
    title       = 'Lights Out'
    description = 'Bedtime countdown'
    product     = 'Lights Out'
    version     = "$version.0"
}
if (Test-Path $icon) { $params['iconFile'] = $icon }
Invoke-ps2exe @params

if (Test-Path $icon) { Copy-Item $icon (Join-Path $appDir 'SleepTimer.ico') -Force }
$logo = Join-Path $root 'assets\LightsOut-Logo.png'
if (Test-Path $logo) { Copy-Item $logo (Join-Path $appDir 'LightsOut-Logo.png') -Force }

$modDest = Join-Path $appDir 'modules'
New-Item -ItemType Directory -Path $modDest -Force | Out-Null
foreach ($modFile in @('LightsOut.Calendar.psm1', 'LightsOut.Novel.psm1', 'LightsOut.Profiles.psm1', 'LightsOut.SteamTheme.psm1', 'LightsOut.LastLight.psm1', 'LightsOut.TonightCards.psm1', 'LightsOut.Demo.psm1')) {
    $p = Join-Path $root "modules\$modFile"
    if (Test-Path $p) { Copy-Item $p $modDest -Force }
}

@'
Lights Out v{VERSION}

START HERE
  Double-click "Lights Out.bat"                    (Classic UI — live bedtime)
  Double-click "Lights Out Premium Preview.bat"    (Night Lobby — safe DryRun preview)

IN THIS FOLDER
  SleepTimer.exe      - the app
  modules\            - calendar + novel features (required)
  SleepTimer.ico      - tray icon
  LightsOut-Logo.png  - title logo
  source\             - PowerShell source (for dev)
  archive\            - previous exe backup

Settings:  %LOCALAPPDATA%\CoolTimer\settings.json
Emergency cancel: Ctrl+Shift+S

NEW IN 5.1
  Calendar - import .ics from Google/Outlook/Apple
  Dim phase - 90s wind-down before power action
  Sleep ledger - streak tracker (top-right link)
  Bedtime pact + Household sync (card buttons)

LUXGRID RGB (optional)
  Check "LuxGrid RGB" in app settings
  Pair with LuxGrid Studio - Sleep Ritual profile
'@.Replace('{VERSION}', $version) | Set-Content (Join-Path $appDir 'README.txt') -Encoding UTF8

# USER_LAUNCHER: end-user double-click .bat in Desktop\Lights Out (not agent/test path)
@'
@echo off
cd /d "%~dp0"
set SLEEPTIMER_DRY_RUN=
set SLEEPTIMER_CI=
start "" "%~dp0SleepTimer.exe" -ClassicUi -NoAutoStart
'@ | Set-Content (Join-Path $appDir 'Lights Out.bat') -Encoding ASCII

# USER_LAUNCHER: safe Night Lobby / Steam UI preview (not live bedtime path)
@'
@echo off
cd /d "%~dp0"
set SLEEPTIMER_DRY_RUN=1
set SLEEPTIMER_CI=
start "" "%~dp0SleepTimer.exe" -SteamUi -DryRun -NoAutoStart
'@ | Set-Content (Join-Path $appDir 'Lights Out Premium Preview.bat') -Encoding ASCII

# Desktop launchers (double-click from Desktop root)
$shortcutBat = Join-Path $desktop 'Lights Out.bat'
# USER_LAUNCHER: end-user Desktop shortcut .bat (not agent/test path)
@'
@echo off
set SLEEPTIMER_DRY_RUN=
set SLEEPTIMER_CI=
cd /d "%USERPROFILE%\Desktop\Lights Out"
start "" "%USERPROFILE%\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -NoAutoStart
'@ | Set-Content $shortcutBat -Encoding ASCII

$previewBat = Join-Path $desktop 'Lights Out Premium Preview.bat'
@'
@echo off
set SLEEPTIMER_DRY_RUN=1
set SLEEPTIMER_CI=
cd /d "%USERPROFILE%\Desktop\Lights Out"
start "" "%USERPROFILE%\Desktop\Lights Out\SleepTimer.exe" -SteamUi -DryRun -NoAutoStart
'@ | Set-Content $previewBat -Encoding ASCII

$shortcutLnk = Join-Path $desktop 'Lights Out.lnk'
$wsh = New-Object -ComObject WScript.Shell
$s = $wsh.CreateShortcut($shortcutLnk)
$s.TargetPath = $outExe
$s.Arguments = '-ClassicUi -NoAutoStart'
$s.WorkingDirectory = $appDir
$s.Description = 'Lights Out - bedtime countdown timer'
$iconPath = Join-Path $appDir 'SleepTimer.ico'
if (Test-Path $iconPath) { $s.IconLocation = "$iconPath,0" }
$s.Save()
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh)

Write-Host "App:     $outExe" -ForegroundColor Green
Write-Host "Backup:  $bak" -ForegroundColor DarkGray
Write-Host 'Open:    Desktop\Lights Out\Lights Out.bat' -ForegroundColor Yellow
Write-Host 'Preview: Desktop\Lights Out Premium Preview.bat  (-SteamUi -DryRun)' -ForegroundColor Yellow

& (Join-Path $root 'scripts\Install-LuxGrid-LightsOut.ps1')

if ($Launch) {
    # USER_LAUNCHER: explicit user-requested post-deploy launch only
    Start-Process $outExe
} else {
    Write-Host 'Not launching (pass -Launch to start after deploy)' -ForegroundColor DarkGray
}
