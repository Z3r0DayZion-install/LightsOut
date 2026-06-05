#Requires -Version 5.1
<#
.SYNOPSIS
    Validation gates for Sleep Timer — parse, version sync, build. NO GUI launch (never shuts down PC).
.NOTES
    Smoke tests that launch the app were removed — they caused real shutdowns when dry-run failed.
#>
param(
    [switch]$Build,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0

function Pass([string]$Name) {
    Write-Host "  PASS  $Name" -ForegroundColor Green
    $script:passed++
}

function Fail([string]$Name, [string]$Detail) {
    Write-Host "  FAIL  $Name" -ForegroundColor Red
    if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkRed }
    $script:failures.Add("$Name`: $Detail")
}

Write-Host '=== Sleep Timer validation (safe — no app launch) ===' -ForegroundColor Cyan

$srcPath = Join-Path $root 'SleepTimer-Tonight.ps1'
$srcText = Get-Content $srcPath -Raw

# --- Power-action safety gate (static — no app launch) ---
if ($srcText -notmatch 'function Test-NoPowerAction') {
    Fail 'safety-guard' 'Missing Test-NoPowerAction function'
} elseif ($srcText -notmatch 'if \(Test-NoPowerAction\)') {
    Fail 'safety-guard' 'Do-PowerAction must guard with Test-NoPowerAction'
} elseif ($srcText -notmatch 'function Write-AuditLog') {
    Fail 'safety-guard' 'Missing Write-AuditLog'
} elseif ($srcText -notmatch 'Invoke-EmergencyCancel') {
    Fail 'safety-guard' 'Missing emergency cancel hotkey handler'
} elseif ($srcText -notmatch 'function Apply-StartupArguments') {
    Fail 'cli-args' 'Missing Apply-StartupArguments (CLI automation)'
} elseif ($srcText -notmatch 'function Test-UseForcePower') {
    Fail 'graceful-shutdown' 'Missing Test-UseForcePower'
} elseif ($srcText -notmatch 'GracefulShutdown') {
    Fail 'graceful-shutdown' 'Missing GracefulShutdown setting'
} elseif ($srcText -notmatch 'function Publish-LuxGridEvent') {
    Fail 'luxgrid-bridge' 'Missing Publish-LuxGridEvent'
} elseif ($srcText -notmatch 'function Get-SecondsUntilClock') {
    Fail 'clock-schedule' 'Missing Get-SecondsUntilClock'
} elseif ($srcText -notmatch 'TimerMode') {
    Fail 'clock-schedule' 'Missing TimerMode setting'
} elseif ($srcText -notmatch 'function Resume-Timer') {
    Fail 'pause-resume' 'Missing Resume-Timer'
} elseif ($srcText -notmatch "'Hibernate'") {
    Fail 'power-actions' 'Missing Hibernate action'
} elseif ($srcText -notmatch 'LockWorkStation') {
    Fail 'power-actions' 'Missing Lock action'
} elseif ($srcText -notmatch 'function Get-PowerRequestBlockers') {
    Fail 'power-blockers' 'Missing Get-PowerRequestBlockers'
} elseif ($srcText -notmatch 'function Invoke-StartTimer') {
    Fail 'power-blockers' 'Missing Invoke-StartTimer'
} elseif ($srcText -notmatch 'WarnPowerBlockers') {
    Fail 'power-blockers' 'Missing WarnPowerBlockers setting'
} elseif ($srcText -notmatch 'function Get-RitualCatalog') {
    Fail 'rituals' 'Missing Get-RitualCatalog'
} elseif ($srcText -notmatch 'function Invoke-Ritual') {
    Fail 'rituals' 'Missing Invoke-Ritual'
} elseif ($srcText -notmatch 'function Show-CountdownQuickPanel') {
    Fail 'quick-warn-panel' 'Missing Show-CountdownQuickPanel'
} elseif ($srcText -notmatch 'function Invoke-CountdownWarning') {
    Fail 'quick-warn-panel' 'Missing Invoke-CountdownWarning'
} elseif ($srcText -notmatch 'QuickWarnPanel') {
    Fail 'quick-warn-panel' 'Missing QuickWarnPanel setting'
} elseif ($srcText -notmatch 'function Show-CalendarEventDialog') {
    Fail 'calendar' 'Missing Show-CalendarEventDialog'
} elseif ($srcText -notmatch 'ScheduledAt') {
    Fail 'calendar' 'Missing ScheduledAt setting'
} elseif ($srcText -notmatch 'function Start-LightsDimPhase') {
    Fail 'novel-features' 'Missing Lights Dim Phase'
} elseif ($srcText -notmatch 'function Show-SleepLedgerDialog') {
    Fail 'novel-features' 'Missing Sleep Ledger'
} elseif ($srcText -notmatch 'function Invoke-TimerProfile') {
    Fail 'saved-timers' 'Missing saved timer profiles'
} elseif ($srcText -notmatch 'Show-CalendarFeedDialog') {
    Fail 'calendar-feed' 'Missing live calendar feed'
} elseif ($srcText -notmatch 'function Show-HouseholdHarmonyDialog') {
    Fail 'novel-features' 'Missing Household Harmony'
} elseif ($srcText -notmatch 'function Get-SleepClearanceReport') {
    Fail 'sleep-clearance' 'Missing Get-SleepClearanceReport'
} elseif (-not (Get-Content (Join-Path $root 'modules\LightsOut.Novel.psm1') -Raw) -match 'function Get-MorningProofReport') {
    Fail 'morning-proof' 'Missing Get-MorningProofReport in LightsOut.Novel.psm1'
} elseif ($srcText -notmatch 'function Start-LastLightSequence') {
    Fail 'last-light' 'Missing Start-LastLightSequence'
} elseif ($srcText -notmatch 'LastLightEnabled') {
    Fail 'last-light' 'Missing LastLightEnabled setting'
} elseif (-not (Get-Content (Join-Path $root 'modules\LightsOut.LastLight.psm1') -Raw) -match 'function Get-LastLightSequenceCatalog') {
    Fail 'last-light' 'Missing LightsOut.LastLight.psm1 catalog'
} elseif ((Get-Content (Join-Path $root 'modules\LightsOut.LastLight.psm1') -Raw) -match 'Do-PowerAction') {
    Fail 'last-light' 'LastLight module must not call Do-PowerAction'
} elseif ($srcText -notmatch 'function Select-TonightCard') {
    Fail 'tonight-cards' 'Missing Select-TonightCard'
} elseif (-not (Get-Content (Join-Path $root 'modules\LightsOut.TonightCards.psm1') -Raw) -match 'function Get-TonightCardCatalog') {
    Fail 'tonight-cards' 'Missing LightsOut.TonightCards.psm1'
} elseif ($srcText -notmatch 'TonightCardId') {
    Fail 'tonight-cards' 'Missing TonightCardId setting'
} elseif ($srcText -notmatch '\[switch\]\$Demo') {
    Fail 'demo-mode' 'Missing -Demo CLI switch'
} elseif ($srcText -notmatch '\$script:DemoMode') {
    Fail 'demo-mode' 'Missing DemoMode state'
} elseif ($srcText -notmatch 'if \(\$script:DemoMode\) \{\s*\$script:DryRun = \$true') {
    Fail 'demo-mode' 'Demo Mode must force DryRun'
} elseif ($srcText -notmatch 'if \(\$script:DemoMode\) \{ return \}') {
    Fail 'demo-mode' 'Demo Mode must skip audit/settings writes'
} elseif (-not (Get-Content (Join-Path $root 'modules\LightsOut.Demo.psm1') -Raw) -match 'function Get-DemoMorningProofReport') {
    Fail 'demo-mode' 'Missing LightsOut.Demo.psm1'
} elseif ((Get-Content (Join-Path $root 'modules\LightsOut.Demo.psm1') -Raw) -match 'Do-PowerAction') {
    Fail 'demo-mode' 'Demo module must not call Do-PowerAction'
} elseif ($srcText -notmatch '23, 24, 30') {
    Fail 'simple-timer' 'Missing 23m quick chip in Classic timer row'
} elseif (-not ((Get-Content (Join-Path $root 'scripts\Deploy-SleepTimer-Desktop.ps1') -Raw) -match 'ClassicUi -NoAutoStart')) {
    Fail 'simple-timer' 'Deploy must write ClassicUi -NoAutoStart to Lights Out.bat'
} elseif (-not ((Get-Content (Join-Path $root 'scripts\Deploy-SleepTimer-Desktop.ps1') -Raw) -match 'SteamUi -DryRun -NoAutoStart')) {
    Fail 'simple-timer' 'Deploy must write SteamUi -DryRun -NoAutoStart to Lights Out Premium Preview.bat'
} elseif ($srcText -match 'Select-TonightCard[\s\S]{0,600}Do-PowerAction') {
    Fail 'tonight-cards' 'Select-TonightCard must not call Do-PowerAction'
} elseif ($srcText -notmatch 'Bedtime pact') {
    Fail 'novel-features' 'Missing Bedtime Pact'
} else {
    Pass 'power-action safety guard in source'
    Pass 'luxgrid bridge in source'
    Pass 'cli automation in source'
    Pass 'graceful shutdown in source'
    Pass 'clock schedule in source'
    Pass 'pause resume in source'
    Pass 'hibernate lock in source'
    Pass 'power blocker warn in source'
    Pass 'quick warn panel in source'
    Pass 'calendar schedule in source'
    Pass 'saved timer profiles in source'
    Pass 'calendar live feed in source'
    Pass 'novel features in source'
    Pass 'bedtime rituals in source'
    Pass 'sleep clearance in source'
    Pass 'morning proof in source'
    Pass 'last light in source'
    Pass 'tonight cards in source'
    Pass 'demo mode in source'
    Pass 'simple timer path in source'
}

# --- Classic UI bedtime lock (static — no app launch) ---
Write-Host '--- Classic UI bedtime lock ---' -ForegroundColor DarkCyan
if ($srcText -notmatch "Timer amount") {
    Fail 'classic-ui-lock' 'Classic timer panel must label "Timer amount"'
} else {
    Pass 'classic timer amount label'
}
if ($srcText -notmatch 'function Apply-ClassicSimpleLayout') {
    Fail 'classic-ui-lock' 'Missing Apply-ClassicSimpleLayout'
} else {
    Pass 'classic simple layout function'
}
if ($srcText -notmatch 'if \(\$SteamUi -or \$script:CliSteamUi\) \{ \$cfg\.UiTheme = ''steam'' \}') {
    Fail 'classic-ui-lock' 'SteamUi must set theme to steam (CLI wins over settings)'
} else {
    Pass 'SteamUi wins over saved settings'
}
if ($srcText -notmatch 'else \{ \$cfg\.UiTheme = ''classic'' \}') {
    Fail 'classic-ui-lock' 'Classic must be default theme unless -SteamUi'
} else {
    Pass 'classic default theme unless SteamUi'
}
if ($srcText -notmatch 'if \(-not \$script:UseSteamUi -and -not \$ScheduleAt') {
    Fail 'classic-ui-lock' 'Classic must force duration when no schedule CLI'
} else {
    Pass 'classic forces duration mode'
}
if ($srcText -notmatch 'START · \$\{startMin\} min') {
    Fail 'classic-ui-lock' 'START button must show current minutes in Classic duration mode'
} else {
    Pass 'classic START shows amount'
}
if ($srcText -notmatch '@\(10, 15, 23, 24, 30, 45, 60\)') {
    Fail 'classic-ui-lock' 'Classic quick chips must include 23m'
} else {
    Pass 'classic 23m quick chip'
}

# --- Parse PowerShell sources ---
$parseTargets = @(
    'SleepTimer-Tonight.ps1'
    'scripts\Build-Release.ps1'
    'scripts\Deploy-SleepTimer-Desktop.ps1'
    'scripts\Install-Nightfall.ps1'
    'scripts\Create-NightfallIcon.ps1'
    'modules\Nightfall.Core.psm1'
    'modules\LightsOut.Calendar.psm1'
    'modules\LightsOut.Novel.psm1'
    'modules\LightsOut.LastLight.psm1'
    'modules\LightsOut.TonightCards.psm1'
    'modules\LightsOut.Demo.psm1'
    'modules\LightsOut.Profiles.psm1'
)
foreach ($rel in $parseTargets) {
    $f = Join-Path $root $rel
    if (-not (Test-Path $f)) {
        if ($rel -like 'modules*') { continue }
        Fail "parse:$rel" 'file missing'
        continue
    }
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errs)
    if ($errs) { Fail "parse:$rel" ($errs[0].Message) } else { Pass "parse:$rel" }
}

# --- VERSION sync ---
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw
if ($changelog -match "\[${version}\]") { Pass "version:$version in CHANGELOG" }
else { Fail 'version-sync' "VERSION $version not found in CHANGELOG.md" }

$iss = Get-Content (Join-Path $root 'installer\nightfall.iss') -Raw
if ($iss -match "#define MyAppVersion `"$version`"") { Pass 'version in installer.iss' }
else { Fail 'iss-version' "installer.iss MyAppVersion should be $version" }

# --- Settings schema (no GUI) ---
try {
    $sample = @{ DefaultSeconds = 1440; Action = 'Shutdown'; DryRun = $false } | ConvertTo-Json
    $loaded = $sample | ConvertFrom-Json
    if ($loaded.DefaultSeconds -eq 1440) { Pass 'settings-json roundtrip' }
    else { Fail 'settings-json' 'unexpected values' }
} catch {
    Fail 'settings-json' $_.Exception.Message
}

# --- Optional: build (never launches app) ---
if ($Build -and -not $SkipBuild) {
    Write-Host '--- Build release (no launch) ---' -ForegroundColor Cyan
    & (Join-Path $root 'scripts\Build-Release.ps1') -SkipDesktop -SkipInstaller
}

$exe = Join-Path $root 'dist\Release\SleepTimer.exe'
if (Test-Path $exe) {
    $info = Get-Item $exe
    if ($info.Length -gt 4096) { Pass "release exe ($([math]::Round($info.Length / 1KB)) KB)" }
    else { Fail 'release-exe' "suspicious size: $($info.Length) bytes" }
    $hash = (Get-FileHash $exe -Algorithm SHA256).Hash
    Pass "sha256 $hash"
    $hash | Set-Content (Join-Path $root 'dist\Release\SHA256.txt') -Encoding ASCII -NoNewline
} elseif ($Build) {
    Fail 'release-exe' 'dist/Release/SleepTimer.exe not found after build'
}

# --- Logic tests (no GUI / no shutdown) ---
Write-Host '--- Logic tests ---' -ForegroundColor Cyan
& (Join-Path $root 'scripts\Test-SleepTimer-Logic.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host "Passed: $passed | Failed: $($failures.Count)" -ForegroundColor $(if ($failures.Count) { 'Red' } else { 'Green' })
if ($failures.Count) {
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
exit 0
