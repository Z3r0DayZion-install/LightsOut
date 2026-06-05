#Requires -Version 5.1
<#
.SYNOPSIS
    Build Desktop-style SleepTimer.exe from CoolTimer.ps1 (PS2EXE).
.NOTES
    NOT CANONICAL — CoolTimer.ps1 is an experiment. Agents: use Build-Release.ps1 +
    Deploy-SleepTimer-Desktop.ps1 for Lights Out. See docs/agent-handbook/AGENT-QUICKSTART.md
#>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$source = Join-Path $root 'CoolTimer.ps1'
$outDir = Join-Path $root 'dist'
$outExe = Join-Path $outDir 'SleepTimer.exe'
$desktopExe = Join-Path $env:USERPROFILE 'Desktop\SleepTimer.exe'
$desktopBackup = Join-Path $env:USERPROFILE 'Desktop\SleepTimer.exe.bak'

if (-not (Test-Path $source)) {
    Write-Error "Missing source: $source"
}

$ps2exeRoot = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\ps2exe'
$ps2exeManifest = Get-ChildItem -Path $ps2exeRoot -Recurse -Filter 'ps2exe.psd1' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $ps2exeManifest) {
    Write-Error "PS2EXE not found under $ps2exeRoot. Run: Install-Module ps2exe -Scope CurrentUser"
}
Import-Module $ps2exeManifest.FullName -Force -ErrorAction Stop

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Write-Host "Building $outExe ..."
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$icon = Join-Path $root 'assets\Nightfall.ico'
$iconArg = @{}
if (Test-Path $icon) { $iconArg['iconFile'] = $icon }
Invoke-ps2exe -inputFile $source -outputFile $outExe -noConsole -title 'Nightfall' -description 'Bedtime countdown' -company 'Nightfall' -product 'Nightfall' -version "$version.0" @iconArg
'Dev' | Set-Content (Join-Path $outDir 'channel.txt') -Encoding ASCII -NoNewline

if (-not (Test-Path $outExe)) {
    Write-Error 'Build failed — exe not created'
}

$built = Get-Item $outExe
Write-Host "OK: $($built.FullName) ($([math]::Round($built.Length/1KB)) KB)"

if (Test-Path $desktopExe) {
    Copy-Item $desktopExe $desktopBackup -Force
    Write-Host "Backed up desktop exe -> $desktopBackup"
}

Copy-Item $outExe $desktopExe -Force
Write-Host "Updated desktop: $desktopExe"
