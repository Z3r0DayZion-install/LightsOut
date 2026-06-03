#Requires -Version 5.1
<#
.SYNOPSIS
    Runtime logic tests — no GUI, no power actions, no shutdown.
#>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$passed = 0
$failures = [System.Collections.Generic.List[string]]::new()

function Pass([string]$Name) {
    Write-Host "  PASS  $Name" -ForegroundColor Green
    $script:passed++
}
function Fail([string]$Name, [string]$Detail) {
    Write-Host "  FAIL  $Name" -ForegroundColor Red
    if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkRed }
    $script:failures.Add("${Name}: $Detail")
}

Write-Host '=== Logic tests (no shutdown) ===' -ForegroundColor Cyan

# Load pure functions from source (no WinForms UI / Start-Timer)
$srcLines = Get-Content (Join-Path $root 'SleepTimer-Tonight.ps1')
$stub = @'
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
$script:MinTimerSec = 60
$script:Action = 'Shutdown'
$script:TimerMode = 'duration'
$script:ClockTime = '23:30'
$script:DefaultSec = 1700
$script:UiReady = $false
$script:DryRun = $true
$script:WarnPowerBlockers = $true
$script:GracefulShutdown = $true
$script:C = @{
    Bg = [System.Drawing.Color]::Black
    Card = [System.Drawing.Color]::Gray
    Ink = [System.Drawing.Color]::White
    Muted = [System.Drawing.Color]::Gray
    Amber = [System.Drawing.Color]::Orange
    Mint = [System.Drawing.Color]::Green
    Blue = [System.Drawing.Color]::Blue
    Violet = [System.Drawing.Color]::Purple
    Slate = [System.Drawing.Color]::Silver
    Track = [System.Drawing.Color]::DarkGray
}
'@
$fnStart = ($srcLines | Select-String -Pattern '^function Parse-ClockTime' | Select-Object -First 1).LineNumber - 1
$fnEnd = ($srcLines | Select-String -Pattern '^function Write-AuditLog' | Select-Object -First 1).LineNumber - 2
$graceStart = ($srcLines | Select-String -Pattern '^function Test-GracefulApplies' | Select-Object -First 1).LineNumber - 1
$graceEnd = ($srcLines | Select-String -Pattern '^function New-ProgressTrayIcon' | Select-Object -First 1).LineNumber - 2
$body = (($srcLines[$fnStart..$fnEnd] + $srcLines[$graceStart..$graceEnd]) -join "`n")
$temp = Join-Path $env:TEMP "lightsout-logic-$([guid]::NewGuid().ToString('N')).ps1"
($stub + "`n" + $body) | Set-Content $temp -Encoding UTF8
. $temp
Remove-Item $temp -Force -ErrorAction SilentlyContinue

# Parse-ClockTime
if ((Parse-ClockTime '23:30') -eq '23:30') { Pass 'Parse-ClockTime 24h' }
else { Fail 'Parse-ClockTime 24h' (Parse-ClockTime '23:30') }
if ((Parse-ClockTime '11:30 PM') -eq '23:30') { Pass 'Parse-ClockTime 12h' }
else { Fail 'Parse-ClockTime 12h' (Parse-ClockTime '11:30 PM') }
if ($null -eq (Parse-ClockTime 'not-a-time')) { Pass 'Parse-ClockTime invalid' }
else { Fail 'Parse-ClockTime invalid' 'expected null' }

# Normalize via ritual catalog actions
$rituals = Get-RitualCatalog
if ($rituals.Count -eq 4) { Pass 'Get-RitualCatalog count' }
else { Fail 'Get-RitualCatalog count' "got $($rituals.Count)" }
if ($rituals.Id -contains 'movie' -and $rituals.Id -contains 'bedtime') { Pass 'Get-RitualCatalog ids' }
else { Fail 'Get-RitualCatalog ids' ($rituals.Id -join ',') }

# Clock seconds (future time today)
$script:TimerMode = 'clock'
$sec = Get-SecondsUntilClock '23:59'
if ($sec -ge 60) { Pass "Get-SecondsUntilClock future ($sec s)" }
else { Fail 'Get-SecondsUntilClock future' "$sec" }

# Power blockers (read-only powercfg)
$script:Action = 'Sleep'
$blockers = @(Get-PowerRequestBlockers)
if ($blockers.Count -ge 0) { Pass "Get-PowerRequestBlockers ($($blockers.Count) active)" }
else { Fail 'Get-PowerRequestBlockers' 'error' }

$script:DryRun = $true
if (-not (Test-ShouldWarnPowerBlockers)) { Pass 'Test-ShouldWarnPowerBlockers dry-run off' }
else { Fail 'Test-ShouldWarnPowerBlockers dry-run' 'should be false in dry-run' }
$script:DryRun = $false
$env:SLEEPTIMER_CI = '1'
if (-not (Test-ShouldWarnPowerBlockers)) { Pass 'Test-ShouldWarnPowerBlockers CI off' }
else { Fail 'Test-ShouldWarnPowerBlockers CI' }
Remove-Item Env:SLEEPTIMER_CI -ErrorAction SilentlyContinue

# Test-NoPowerAction
$script:DryRun = $true
if (Test-NoPowerAction) { Pass 'Test-NoPowerAction dry-run' }
else { Fail 'Test-NoPowerAction dry-run' }
$env:SLEEPTIMER_CI = '1'
if (Test-NoPowerAction) { Pass 'Test-NoPowerAction CI env' }
else { Fail 'Test-NoPowerAction CI env' }
Remove-Item Env:SLEEPTIMER_CI -ErrorAction SilentlyContinue

# Graceful applies
$script:Action = 'Lock'
if (-not (Test-GracefulApplies)) { Pass 'Test-GracefulApplies Lock' }
else { Fail 'Test-GracefulApplies Lock' }
$script:Action = 'Shutdown'
if (Test-GracefulApplies) { Pass 'Test-GracefulApplies Shutdown' }
else { Fail 'Test-GracefulApplies Shutdown' }

# LuxGrid pack JSON
try {
    $pack = Get-Content (Join-Path $root 'packaging\luxgrid\Sleep-Ritual-Pack.json') -Raw | ConvertFrom-Json
    if ($pack.id -eq 'sleep-ritual' -and $pack.events.Count -ge 4) { Pass 'Sleep-Ritual-Pack.json' }
    else { Fail 'Sleep-Ritual-Pack.json' 'schema' }
} catch {
    Fail 'Sleep-Ritual-Pack.json' $_.Exception.Message
}

# Full settings schema
try {
    $full = @{
        DefaultSeconds = 1700; Action = 'Sleep'; TimerMode = 'clock'; ClockTime = '23:30'
        WarnPowerBlockers = $true; LastRitualId = 'weeknight'; GracefulShutdown = $true
        EmitLuxGridEvents = $false; DryRun = $false
    } | ConvertTo-Json
    $back = $full | ConvertFrom-Json
    if ($back.LastRitualId -eq 'weeknight') { Pass 'settings schema v5 fields' }
    else { Fail 'settings schema v5 fields' }
} catch {
    Fail 'settings schema v5 fields' $_.Exception.Message
}

# Novel features module
try {
    Import-Module (Join-Path $root 'modules\LightsOut.Novel.psm1') -Force
    $deadline = Get-PactDeadline '23:00'
    if ($deadline -gt (Get-Date)) { Pass 'pact deadline' } else { Fail 'pact deadline' 'past' }
    $soonHm = (Get-Date).AddMinutes(2).ToString('HH:mm')
    if (Test-SnoozeCrossesPact -SecondsToAdd 600 -RemainingSeconds 300 -PactTimeHm $soonHm) { Pass 'pact snooze detect' }
    else { Fail 'pact snooze detect' 'expected cross before pact' }
    $payload = New-HouseholdSyncPayload -Action 'Sleep' -TargetWhen ((Get-Date).AddHours(2))
    if ($payload.code -and $payload.targetIso) { Pass 'household payload' } else { Fail 'household payload' }
} catch {
    Fail 'novel module' $_.Exception.Message
}

# Calendar ICS parse
try {
    $sampleIcs = Join-Path $root 'packaging\calendar\sample-bedtime.ics'
    Import-Module (Join-Path $root 'modules\LightsOut.Calendar.psm1') -Force
    $imp = Import-IcsCalendarFile -Path $sampleIcs
    $up = Get-IcsUpcomingEvents -Events $imp.Events -WithinDays 365
    if ($up.Count -ge 1 -and $up[0].Summary) { Pass 'calendar ICS import' }
    else { Fail 'calendar ICS import' "events=$($up.Count)" }
} catch {
    Fail 'calendar ICS import' $_.Exception.Message
}

# Winget manifest parse
$winget = Join-Path $root 'packaging\winget\KickA.LightsOut.yaml'
$wy = Get-Content $winget -Raw
$ver = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
if ($wy -match "PackageVersion:\s*$ver") { Pass 'winget version sync' }
else { Fail 'winget version sync' }

if (Get-Command winget -ErrorAction SilentlyContinue) {
    $manifestDir = Join-Path $env:TEMP "lo-winget-test-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
    Copy-Item $winget (Join-Path $manifestDir 'KickA.LightsOut.yaml')
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = winget validate --manifest $manifestDir 2>&1 | Out-String
    $ErrorActionPreference = $prevEap
    if ($LASTEXITCODE -eq 0) { Pass 'winget validate manifest' }
    else {
        $tail = ($out.Trim() -split "`r?`n" | Select-Object -Last 2) -join ' '
        Fail 'winget validate' $tail
    }
    Remove-Item $manifestDir -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host '  SKIP  winget validate (winget not in PATH)' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host "Passed: $passed | Failed: $($failures.Count)" -ForegroundColor $(if ($failures.Count) { 'Red' } else { 'Green' })
if ($failures.Count) {
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
exit 0
