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
$script:AutoStartOnOpen = $false
$script:EmitLuxGridEvents = $false
$script:CalendarEventTitle = ''
$script:ScheduledAt = ''
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

# Sleep Clearance
$script:TimerMode = 'duration'
$script:DefaultSec = 1700
$script:Action = 'Shutdown'
$r = Get-SleepClearanceReport
if ($r.Status -in @('Clear', 'Warning')) { Pass 'Get-SleepClearanceReport status' }
else { Fail 'Get-SleepClearanceReport status' $r.Status }
if ($r.Checks.Name -contains 'Power action' -and $r.Checks.Name -contains 'LuxGrid') { Pass 'Get-SleepClearanceReport checks' }
else { Fail 'Get-SleepClearanceReport checks' ($r.Checks.Name -join ',') }
if ($r.Headline) { Pass 'Get-SleepClearanceReport headline' }
else { Fail 'Get-SleepClearanceReport headline' 'empty' }
$script:TimerMode = 'calendar'
$script:CalendarEventTitle = ''
$script:ScheduledAt = ''
$rCal = Get-SleepClearanceReport
if ($rCal.Status -eq 'Warning' -and ($rCal.Issues -contains 'Pick a calendar event')) { Pass 'Get-SleepClearanceReport calendar warning' }
else { Fail 'Get-SleepClearanceReport calendar warning' ($rCal.Issues -join ',') }

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

    $mpTempLogs = [System.Collections.Generic.List[string]]::new()
    function New-MorningProofLog {
        param([string[]]$Lines)
        $p = Join-Path $env:TEMP "morning-proof-$([guid]::NewGuid().ToString('N')).log"
        $Lines | Set-Content $p -Encoding UTF8
        [void]$mpTempLogs.Add($p)
        return $p
    }
    $tStart = (Get-Date).AddHours(-10).ToString('o')
    $tEnd = (Get-Date).AddHours(-9).AddMinutes(32).ToString('o')
    $logDone = New-MorningProofLog @(
        "$tStart timer_started action=Shutdown seconds=1700 mode=duration clock=23:30"
        "$tStart snooze +300"
        "$tEnd power_action action=Shutdown force=False"
    )
    $done = Get-MorningProofReport -AuditLogPath $logDone -LastSeen ''
    if ($done.State -eq 'completed' -and $done.ShowProof -and $done.SnoozeCount -eq 1) { Pass 'Get-MorningProofReport completed' }
    else { Fail 'Get-MorningProofReport completed' "$($done.State) snoozes=$($done.SnoozeCount)" }
    $seen = Get-MorningProofReport -AuditLogPath $logDone -LastSeen $tEnd
    if (-not $seen.ShowProof) { Pass 'Get-MorningProofReport last seen' }
    else { Fail 'Get-MorningProofReport last seen' 'expected hidden' }

    $logDry = New-MorningProofLog @(
        "$tStart timer_started action=Shutdown seconds=60 mode=duration clock=23:30"
        "$tEnd power_blocked safe_mode action=Shutdown"
    )
    $dry = Get-MorningProofReport -AuditLogPath $logDry
    if ($dry.State -eq 'dry-run' -and $dry.ShowProof) { Pass 'Get-MorningProofReport dry-run' }
    else { Fail 'Get-MorningProofReport dry-run' $dry.State }

    $logCancel = New-MorningProofLog @(
        "$tStart timer_started action=Shutdown seconds=1700 mode=duration clock=23:30"
        "$tEnd emergency_cancel action=Shutdown left=1200"
    )
    $cancel = Get-MorningProofReport -AuditLogPath $logCancel
    if ($cancel.State -eq 'cancelled' -and $cancel.ShowProof) { Pass 'Get-MorningProofReport cancelled' }
    else { Fail 'Get-MorningProofReport cancelled' $cancel.State }

    $logSnooze = New-MorningProofLog @(
        "$tStart timer_started action=Shutdown seconds=1700 mode=duration clock=23:30"
        "$tStart snooze +300"
        "$tStart snooze +600"
        "$tEnd power_action action=Shutdown force=False"
    )
    if ((Get-MorningProofReport -AuditLogPath $logSnooze).SnoozeCount -eq 2) { Pass 'Get-MorningProofReport snooze count' }
    else { Fail 'Get-MorningProofReport snooze count' }

    $logEmpty = New-MorningProofLog @('2026-01-01T00:00:00.0000000-05:00 calendar_event test')
    $unk = Get-MorningProofReport -AuditLogPath $logEmpty
    if ($unk.State -eq 'unknown' -and -not $unk.ShowProof) { Pass 'Get-MorningProofReport unknown' }
    else { Fail 'Get-MorningProofReport unknown' $unk.State }

    foreach ($p in $mpTempLogs) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
} catch {
    Fail 'novel module' $_.Exception.Message
}

# Last Light module
try {
    Import-Module (Join-Path $root 'modules\LightsOut.LastLight.psm1') -Force
    $cat = Get-LastLightSequenceCatalog
    if ($cat.Count -eq 4 -and ($cat.Id -contains 'ClassicFade') -and ($cat.Id -contains 'ExitTheGrid')) {
        Pass 'Get-LastLightSequenceCatalog v1'
    } else { Fail 'Get-LastLightSequenceCatalog v1' ($cat.Id -join ',') }

    if ((Normalize-LastLightSequenceId 'AntiAlgorithmProtocol') -eq 'AntiAlgorithm') { Pass 'Normalize-LastLightSequenceId alias' }
    else { Fail 'Normalize-LastLightSequenceId alias' }

    if ((Normalize-LastLightSequenceId 'bogus') -eq 'ClassicFade') { Pass 'Normalize-LastLightSequenceId fallback' }
    else { Fail 'Normalize-LastLightSequenceId fallback' }

    $steps = Get-LastLightSequenceSteps -SequenceId 'ClassicFade' -DryRun:$false
    if ($steps.Count -ge 2 -and $steps[0].Headline -eq 'LAST LIGHT') { Pass 'Get-LastLightSequenceSteps ClassicFade' }
    else { Fail 'Get-LastLightSequenceSteps ClassicFade' }

    $drySteps = Get-LastLightSequenceSteps -SequenceId 'ExitTheGrid' -DryRun:$true
    $dryMeta = Get-LastLightSequenceMeta -SequenceId 'ClassicFade' -DryRun:$true
    if ($dryMeta.FinalLine -match 'No power action') { Pass 'Get-LastLightSequenceMeta dry-run' }
    else { Fail 'Get-LastLightSequenceMeta dry-run' $dryMeta.FinalLine }

    if ($drySteps[0].DwellMs -lt (Get-LastLightSequenceSteps -SequenceId 'ExitTheGrid' -DryRun:$false)[0].DwellMs) {
        Pass 'Get-LastLightSequenceSteps dry-run shorter'
    } else { Fail 'Get-LastLightSequenceSteps dry-run shorter' }

    $anti = Get-LastLightSequenceMeta -SequenceId 'AntiAlgorithm'
    if ($anti.ProceedLabel -eq 'UNPLUG') { Pass 'Get-LastLightSequenceMeta AntiAlgorithm UNPLUG' }
    else { Fail 'Get-LastLightSequenceMeta AntiAlgorithm UNPLUG' }

    $llJson = @{
        LastLightEnabled = $false
        LastLightSequence = 'SignalSeverance'
        LastLightUseCinema = $true
    } | ConvertTo-Json
    $llBack = $llJson | ConvertFrom-Json
    if ($llBack.LastLightSequence -eq 'SignalSeverance' -and $llBack.LastLightEnabled -eq $false) {
        Pass 'LastLight settings json roundtrip'
    } else { Fail 'LastLight settings json roundtrip' }

    $llMod = Get-Content (Join-Path $root 'modules\LightsOut.LastLight.psm1') -Raw
    if ($llMod -notmatch 'Do-PowerAction') { Pass 'LastLight module no Do-PowerAction' }
    else { Fail 'LastLight module no Do-PowerAction' }
} catch {
    Fail 'LastLight module' $_.Exception.Message
}

# Tonight Cards module
try {
    Import-Module (Join-Path $root 'modules\LightsOut.TonightCards.psm1') -Force
    $tc = Get-TonightCardCatalog
    if ($tc.Count -eq 5 -and ($tc.Id -contains 'weeknight') -and ($tc.Id -contains 'hard_stop')) {
        Pass 'Get-TonightCardCatalog v1'
    } else { Fail 'Get-TonightCardCatalog v1' ($tc.Id -join ',') }

    $wk = Get-TonightCardById 'weeknight'
    if ($wk.DurationSeconds -eq 1440 -and $wk.Action -eq 'Shutdown' -and $wk.DefaultLastLightSequence -eq 'ClassicFade') {
        Pass 'Get-TonightCardById weeknight'
    } else { Fail 'Get-TonightCardById weeknight' }

    $bd = Get-TonightCardById 'bedtime'
    if ($bd.TimerMode -eq 'clock' -and $bd.ClockTime -eq '23:30') { Pass 'Get-TonightCardById bedtime' }
    else { Fail 'Get-TonightCardById bedtime' }

    $hs = Get-TonightCardById 'hard_stop'
    if ($hs.SnoozePolicy -eq 'limited' -and $hs.DefaultLastLightSequence -eq 'AntiAlgorithm') { Pass 'Get-TonightCardById hard_stop' }
    else { Fail 'Get-TonightCardById hard_stop' }

    if ((Normalize-TonightCardId 'hardstop') -eq 'hard_stop') { Pass 'Normalize-TonightCardId' }
    else { Fail 'Normalize-TonightCardId' }

    $hero = Get-TonightCardHeroPreview -CardId 'weeknight'
    if ($hero.Title -eq "TONIGHT'S RUN" -and $hero.Tagline -match 'Weeknight' -and $hero.DetailLine -match 'Classic Fade') {
        Pass 'Get-TonightCardHeroPreview weeknight'
    } else { Fail 'Get-TonightCardHeroPreview weeknight' ($hero.Tagline + ' | ' + $hero.DetailLine) }

    $customHero = Get-TonightCardHeroPreview -CardId 'custom' -DefaultSec 1700 -Action 'Sleep' -LastLightSequence 'ClassicFade'
    if ($customHero.Title -eq "TONIGHT'S RUN" -and $customHero.DetailLine -match 'Proof') { Pass 'Get-TonightCardHeroPreview custom' }
    else { Fail 'Get-TonightCardHeroPreview custom' }

    if ((Get-LastLightSoundCatalog).Count -ge 2 -and (Normalize-LastLightSoundId 'soft') -eq 'Soft') {
        Pass 'Get-LastLightSoundCatalog'
    } else { Fail 'Get-LastLightSoundCatalog' }

    $tcJson = @{ TonightCardId = 'movie' } | ConvertTo-Json
    if (($tcJson | ConvertFrom-Json).TonightCardId -eq 'movie') { Pass 'TonightCard settings json roundtrip' }
    else { Fail 'TonightCard settings json roundtrip' }

    $tcMod = Get-Content (Join-Path $root 'modules\LightsOut.TonightCards.psm1') -Raw
    if ($tcMod -notmatch 'Do-PowerAction') { Pass 'TonightCards module no Do-PowerAction' }
    else { Fail 'TonightCards module no Do-PowerAction' }
} catch {
    Fail 'TonightCards module' $_.Exception.Message
}

# Demo Mode
try {
    Import-Module (Join-Path $root 'modules\LightsOut.Demo.psm1') -Force
    $demoProof = Get-DemoMorningProofReport
    if ($demoProof.ShowProof -and $demoProof.EventKey -eq 'demo-morning-proof' -and $demoProof.HeroTitle -match 'Mission complete') {
        Pass 'Get-DemoMorningProofReport'
    } else { Fail 'Get-DemoMorningProofReport' }
    if ((Get-DemoClearanceStatus) -eq 'Clear') { Pass 'Get-DemoClearanceStatus' }
    else { Fail 'Get-DemoClearanceStatus' }
    $demoSrc = Get-Content (Join-Path $root 'SleepTimer-Tonight.ps1') -Raw
    if ($demoSrc -match '\$script:DemoMode' -and $demoSrc -match 'if \(\$script:DemoMode\) \{\s*\$script:DryRun = \$true') {
        Pass 'Demo Mode implies DryRun in source'
    } else { Fail 'Demo Mode implies DryRun in source' }
    $demoMod = Get-Content (Join-Path $root 'modules\LightsOut.Demo.psm1') -Raw
    if ($demoMod -notmatch 'Do-PowerAction') { Pass 'Demo module no Do-PowerAction' }
    else { Fail 'Demo module no Do-PowerAction' }
} catch {
    Fail 'Demo module' $_.Exception.Message
}

# Calendar ICS parse
try {
    $sampleIcs = Join-Path $root 'packaging\calendar\sample-bedtime.ics'
    Import-Module (Join-Path $root 'modules\LightsOut.Calendar.psm1') -Force
    $imp = Import-IcsCalendarFile -Path $sampleIcs
    $up = Get-IcsUpcomingEvents -Events $imp.Events -WithinDays 365
    if ($up.Count -ge 1 -and $up[0].Summary) { Pass 'calendar ICS import' }
    else { Fail 'calendar ICS import' "events=$($up.Count)" }
    if ((Test-CalendarFeedUrl 'https://calendar.google.com/calendar/ical/test/basic.ics')) { Pass 'calendar feed URL validate' }
    else { Fail 'calendar feed URL validate' }
} catch {
    Fail 'calendar ICS import' $_.Exception.Message
}

# Saved timer profiles
try {
    Import-Module (Join-Path $root 'modules\LightsOut.Profiles.psm1') -Force
    $p = Normalize-TimerProfile @{ Name = 'Weeknight'; Mode = 'duration'; Seconds = 1440; Action = 'Sleep' }
    if ($p.Name -eq 'Weeknight' -and $p.Mode -eq 'duration') { Pass 'timer profile normalize' }
    else { Fail 'timer profile normalize' }
    $hint = Get-TimerProfileHint $p
    if ($hint -match 'Sleep') { Pass 'timer profile hint' } else { Fail 'timer profile hint' }
} catch {
    Fail 'timer profile module' $_.Exception.Message
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
