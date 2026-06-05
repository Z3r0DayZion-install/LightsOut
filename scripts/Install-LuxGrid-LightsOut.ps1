#Requires -Version 5.1
<#
.SYNOPSIS
    Prepare LuxGrid for Lights Out nightly ritual — inbox dirs + Sleep Ritual profile hint.
#>
$ErrorActionPreference = 'Stop'

$luxRoot = Join-Path $env:LOCALAPPDATA 'LuxGrid'
$inbox = Join-Path $luxRoot 'events\inbox'
$processed = Join-Path $luxRoot 'events\processed'
$profiles = Join-Path $luxRoot 'profiles'
$logs = Join-Path $luxRoot 'logs'

foreach ($d in @($luxRoot, $inbox, $processed, $profiles, $logs)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

$packSrc = Join-Path (Split-Path $PSScriptRoot -Parent) 'packaging\luxgrid\Sleep-Ritual-Pack.json'
if (Test-Path $packSrc) {
    Copy-Item $packSrc (Join-Path $profiles 'Sleep-Ritual-Pack.json') -Force
}

$readme = Join-Path $luxRoot 'LIGHTS-OUT-SETUP.txt'
@"
LuxGrid + Lights Out v5 — quick setup
=====================================

1. Open LuxGrid Studio
2. Load profile: Sleep Ritual
3. Event Monitor -> Start Watching
4. Lights Out -> LuxGrid RGB ON -> tap a ritual (Weeknight / Movie / Bedtime)

Pack metadata:
  $(Join-Path $profiles 'Sleep-Ritual-Pack.json')

Events inbox:
  $inbox

Source: LightsOut | Channel: sleep
Events: timer.start, timer.tick, timer.warning, lights.out, timer.completed
"@ | Set-Content $readme -Encoding UTF8

Write-Host "LuxGrid ready for Lights Out" -ForegroundColor Green
Write-Host "  Inbox:    $inbox" -ForegroundColor DarkGray
Write-Host "  Setup:    $readme" -ForegroundColor DarkGray
