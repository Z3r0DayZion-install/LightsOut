#Requires -Version 5.1
<#
.SYNOPSIS
    Install Sleep Ritual LuxGrid pack metadata for Lights Out pairing.
.EXAMPLE
    .\scripts\Export-LuxGrid-SleepRitualPack.ps1
#>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$src = Join-Path $root 'packaging\luxgrid\Sleep-Ritual-Pack.json'
if (-not (Test-Path $src)) { throw "Missing $src" }

$luxRoot = Join-Path $env:LOCALAPPDATA 'LuxGrid'
$profiles = Join-Path $luxRoot 'profiles'
$inbox = Join-Path $luxRoot 'events\inbox'
foreach ($d in @($luxRoot, $profiles, $inbox)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

$dest = Join-Path $profiles 'Sleep-Ritual-Pack.json'
Copy-Item $src $dest -Force

$dist = Join-Path $root 'dist\LuxGrid-Pack'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
Copy-Item $src (Join-Path $dist 'Sleep-Ritual-Pack.json') -Force

$readme = Join-Path $luxRoot 'SLEEP-RITUAL-PACK.txt'
@"
Sleep Ritual pack (Lights Out v5.0)
=================================

Installed: $dest

1. LuxGrid Studio -> Sleep Ritual profile
2. Event Monitor -> Start Watching
3. Lights Out -> LuxGrid RGB ON -> tap a ritual (Weeknight / Movie / Bedtime)

Events: timer.start, timer.tick, timer.warning, lights.out, timer.completed
Inbox: $inbox
"@ | Set-Content $readme -Encoding UTF8

Write-Host 'Sleep Ritual pack installed' -ForegroundColor Green
Write-Host "  Profile pack: $dest" -ForegroundColor DarkGray
Write-Host "  Bundle:     $dist" -ForegroundColor DarkGray
Write-Host "  Guide:      $readme" -ForegroundColor DarkGray
