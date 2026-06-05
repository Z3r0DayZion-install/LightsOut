#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Install Sleep Timer to Program Files with shortcuts.
#>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$src = Join-Path $root 'dist\Release'
$exe = Join-Path $src 'SleepTimer.exe'
if (-not (Test-Path $exe)) {
    Write-Host 'Run scripts\Build-Release.ps1 first.' -ForegroundColor Red
    exit 1
}

$installDir = Join-Path ${env:ProgramFiles} 'Sleep Timer'
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

Copy-Item $exe (Join-Path $installDir 'SleepTimer.exe') -Force
foreach ($f in @('SleepTimer.ico', 'LICENSE', 'README.txt')) {
    $p = Join-Path $src $f
    if (Test-Path $p) { Copy-Item $p $installDir -Force }
}
$iconSrc = Join-Path $root 'assets\Nightfall.ico'
if (Test-Path $iconSrc) { Copy-Item $iconSrc (Join-Path $installDir 'SleepTimer.ico') -Force }

$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Sleep Timer'
New-Item -ItemType Directory -Path $startMenu -Force | Out-Null

foreach ($pair in @(
    @{ Name = 'Sleep Timer.lnk'; Dir = $desktop }
    @{ Name = 'Sleep Timer.lnk'; Dir = $startMenu }
)) {
    $s = $wsh.CreateShortcut((Join-Path $pair.Dir $pair.Name))
    $s.TargetPath = Join-Path $installDir 'SleepTimer.exe'
    $s.WorkingDirectory = $installDir
    $s.Description = "Sleep Timer $version - bedtime countdown"
    $ico = Join-Path $installDir 'SleepTimer.ico'
    if (Test-Path $ico) { $s.IconLocation = "$ico,0" }
    $s.Save()
}
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh)

$startup = [Environment]::GetFolderPath('Startup')
$runLink = Join-Path $startup 'Sleep Timer.lnk'
if (-not (Test-Path $runLink)) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($runLink)
    $s.TargetPath = Join-Path $installDir 'SleepTimer.exe'
    $s.WorkingDirectory = $installDir
    $s.Save()
    Write-Host 'Startup shortcut created (run at login).' -ForegroundColor DarkGray
}

Write-Host "Installed Sleep Timer $version to $installDir" -ForegroundColor Green
