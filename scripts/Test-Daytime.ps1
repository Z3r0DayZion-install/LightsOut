#Requires -Version 5.1
<#
.SYNOPSIS
    Daytime dev session — safe dry-run only (PC will NOT shut down).
.EXAMPLE
    .\scripts\Test-Daytime.ps1 -Launch          # 60s dry-run, click around
    .\scripts\Test-Daytime.ps1 -Launch -Seconds 330   # test 5-min warning (~5:30)
    .\scripts\Test-Daytime.ps1 -Build -Launch   # rebuild exe first, then dry-run exe
    .\scripts\Test-Daytime.ps1                  # checklist only, no GUI
#>
param(
    [switch]$Launch,
    [switch]$Build,
    [switch]$UseExe,
    [int]$Seconds = 60
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$src = Join-Path $root 'SleepTimer-Tonight.ps1'
$exe = Join-Path $root 'dist\Release\SleepTimer.exe'
$log = Join-Path $env:LOCALAPPDATA 'CoolTimer\actions.log'

Write-Host ''
Write-Host '=== Sleep Timer — daytime session (DRY RUN) ===' -ForegroundColor Cyan
Write-Host '  PC will NOT shut down, sleep, or restart.' -ForegroundColor Green
Write-Host ''

Write-Host 'Try these while the timer runs:' -ForegroundColor Yellow
Write-Host '  1. Minimize -> tray -> double-click restore'
Write-Host '  2. +5 / +10 snooze buttons'
Write-Host '  3. Ctrl+Shift+S emergency cancel'
Write-Host '  4. Presets (24m, 28:20) while running'
Write-Host '  5. Action pills (Shutdown / Sleep / Restart)'
Write-Host '  6. Close window -> Yes=tray, No=exit, Cancel=stay'
Write-Host '  7. Let timer hit 0 -> punch animation -> confirm (safe in dry-run)' -ForegroundColor DarkGray
Write-Host '  8. Wait for 30s mark — tray flashes + balloon (use -Seconds 45)' -ForegroundColor DarkGray
Write-Host '  9. Right-click tray -> Cancel'
Write-Host ''
Write-Host "  Audit log: $log" -ForegroundColor DarkGray
Write-Host ''

if ($Build) {
    & (Join-Path $root 'scripts\Test-SleepTimer.ps1') -Build
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    & (Join-Path $root 'scripts\Test-SleepTimer.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not $Launch) {
    Write-Host 'No GUI launched. Add -Launch when ready to click around.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  .\scripts\Test-Daytime.ps1 -Launch' -ForegroundColor White
    Write-Host '  .\scripts\Test-Daytime.ps1 -Launch -Seconds 330   # 5-min warn test' -ForegroundColor White
    exit 0
}

# Kill any existing instance so you get a clean window
Get-Process SleepTimer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

$env:SLEEPTIMER_DRY_RUN = '1'
$env:SLEEPTIMER_CI = '1'
if ($Seconds -gt 0) { $env:SLEEPTIMER_SECONDS = "$Seconds" }

try {
    if ($UseExe -and (Test-Path $exe)) {
        Write-Host "Launching EXE dry-run (${Seconds}s) ..." -ForegroundColor Cyan
        Start-Process -FilePath $exe -WindowStyle Normal
    } else {
        Write-Host "Launching script dry-run (${Seconds}s) ..." -ForegroundColor Cyan
        & $src -DryRun -Seconds $Seconds
    }
} finally {
    Remove-Item Env:SLEEPTIMER_DRY_RUN, Env:SLEEPTIMER_CI, Env:SLEEPTIMER_SECONDS -ErrorAction SilentlyContinue
    if (Test-Path $log) {
        Write-Host ''
        Write-Host '--- actions.log (last 8 lines) ---' -ForegroundColor DarkCyan
        Get-Content $log -Tail 8 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    }
}
