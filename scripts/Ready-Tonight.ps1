#Requires -Version 5.1
<#
.NOT CANONICAL
    Legacy Nightfall desktop deploy. Copies Nightfall.exe to Desktop root — not the canonical
    Lights Out layout (Desktop\Lights Out\). Agents: use Deploy-SleepTimer-Desktop.ps1 instead.
    See docs/agent-handbook/AGENT-QUICKSTART.md
#>
param(
    [switch]$Launch
)
# One-shot: build + bedtime settings + Desktop deploy for TONIGHT
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$desktop = [Environment]::GetFolderPath('Desktop')

Write-Warning 'NOT CANONICAL — use scripts\Deploy-SleepTimer-Desktop.ps1 for Lights Out. This script deploys legacy Nightfall to Desktop root.'
Write-Host 'Building Release...' -ForegroundColor Cyan
& (Join-Path $root 'scripts\Build-Release.ps1')

$settingsDir = Join-Path $env:LOCALAPPDATA 'CoolTimer'
New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
@{
    DefaultSeconds    = 1700
    Action            = 'Shutdown'
    ConfirmAtEnd      = $true
    AutoStart         = $true
    TopMost           = $true
    WarnAt5Min        = $true
    DryRun            = $false
    EmitLuxGridEvents = $false
    RunAtLogin        = $false
} | ConvertTo-Json | Set-Content (Join-Path $settingsDir 'settings.json') -Encoding UTF8

'Release' | Set-Content (Join-Path $desktop 'channel.txt') -Encoding ASCII -NoNewline
Copy-Item (Join-Path $root 'dist\Release\Nightfall.exe') (Join-Path $desktop 'SleepTimer.exe') -Force
if (Test-Path (Join-Path $root 'dist\Release\Nightfall.ico')) {
    Copy-Item (Join-Path $root 'dist\Release\Nightfall.ico') (Join-Path $desktop 'Nightfall.ico') -Force
}

$proj = $root
# USER_LAUNCHER: legacy end-user .bat on Desktop root (not canonical Lights Out path)
@'
@echo off
cd /d "%~dp0"
start "" "%~dp0SleepTimer.exe"
'@ | Set-Content (Join-Path $desktop 'Start Sleep Timer.bat') -Encoding ASCII

@"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "$proj\CoolTimer.ps1"
"@ | Set-Content (Join-Path $desktop 'Start Sleep Timer (script).bat') -Encoding ASCII

Write-Host ''
Write-Host 'READY FOR TONIGHT (legacy Nightfall deploy)' -ForegroundColor Yellow
Write-Host "  Desktop: $desktop\SleepTimer.exe"
Write-Host '  Timer: 28:20 then Shutdown (with 5s confirm)'
Write-Host '  Dry run: OFF'
Write-Host ''
Write-Host 'Double-click SleepTimer.exe or Start Sleep Timer.bat' -ForegroundColor Yellow
Write-Host 'Canonical deploy: .\scripts\Deploy-SleepTimer-Desktop.ps1' -ForegroundColor DarkGray

if ($Launch) {
    # USER_LAUNCHER: explicit user-requested legacy deploy launch only
    Start-Process (Join-Path $desktop 'SleepTimer.exe')
} else {
    Write-Host 'Not launching (pass -Launch to start after deploy)' -ForegroundColor DarkGray
}
