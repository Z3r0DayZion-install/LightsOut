#Requires -Version 5.1

<#

.NOT CANONICAL

    Legacy Nightfall desktop deploy to Desktop root. Agents: use Deploy-SleepTimer-Desktop.ps1 instead.

    See docs/agent-handbook/AGENT-QUICKSTART.md

#>

param(

    [switch]$Launch

)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$desktop = [Environment]::GetFolderPath('Desktop')

$release = Join-Path $root 'dist\Release'



Write-Warning 'NOT CANONICAL — use scripts\Deploy-SleepTimer-Desktop.ps1 for Lights Out.'



Get-Process SleepTimer,Nightfall -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Milliseconds 500



& (Join-Path $PSScriptRoot 'Build-Release.ps1')

& (Join-Path $PSScriptRoot 'Fix-Settings-Tonight.ps1')



Copy-Item (Join-Path $release 'Nightfall.exe') (Join-Path $desktop 'Nightfall.exe') -Force

Copy-Item (Join-Path $release 'Nightfall.exe') (Join-Path $desktop 'SleepTimer.exe') -Force

Copy-Item (Join-Path $release 'channel.txt') $desktop -Force

if (Test-Path (Join-Path $release 'Nightfall.ico')) {

    Copy-Item (Join-Path $release 'Nightfall.ico') $desktop -Force

}



# USER_LAUNCHER: legacy end-user .bat on Desktop root
@'

@echo off

cd /d "%~dp0"

start "" "%~dp0SleepTimer.exe"

'@ | Set-Content (Join-Path $desktop 'START TIMER.bat') -Encoding ASCII



@'

@echo off

cd /d "%~dp0"

start "" "%~dp0Nightfall.exe"

'@ | Set-Content (Join-Path $desktop 'START NIGHTFALL.bat') -Encoding ASCII



Write-Host 'Desktop: SleepTimer.exe + Nightfall.exe (legacy Nightfall deploy)' -ForegroundColor Yellow

Write-Host 'Canonical: .\scripts\Deploy-SleepTimer-Desktop.ps1' -ForegroundColor DarkGray



if ($Launch) {

    Start-Process (Join-Path $desktop 'Nightfall.exe')

} else {

    Write-Host 'Not launching (pass -Launch to start after deploy)' -ForegroundColor DarkGray

}

