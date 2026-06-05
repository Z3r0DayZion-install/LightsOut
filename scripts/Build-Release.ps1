#Requires -Version 5.1
<#
.SYNOPSIS
    Release build from SleepTimer-Tonight.ps1 — dist/Release + Desktop + optional installer.
#>
param(
    [switch]$SkipDesktop,
    [switch]$SkipInstaller
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$dist = Join-Path $root 'dist\Release'
$src = Join-Path $root 'SleepTimer-Tonight.ps1'
$outExe = Join-Path $dist 'SleepTimer.exe'

Write-Host "=== Sleep Timer Release $version ===" -ForegroundColor Cyan

if (-not (Test-Path $src)) { throw "Missing source: $src" }

& (Join-Path $root 'scripts\Create-NightfallIcon.ps1')

$ps2exeRoot = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\ps2exe'
$manifest = Get-ChildItem $ps2exeRoot -Recurse -Filter 'ps2exe.psd1' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $manifest) { throw 'ps2exe module not found' }
Import-Module $manifest.FullName -Force

New-Item -ItemType Directory -Path $dist -Force | Out-Null

$icon = Join-Path $root 'assets\SleepTimer.ico'
if (-not (Test-Path $icon)) { $icon = Join-Path $root 'assets\Nightfall.ico' }
$params = @{
    inputFile   = $src
    outputFile  = $outExe
    noConsole   = $true
    STA         = $true
    title       = 'Lights Out'
    description = 'Bedtime countdown for Windows'
    company     = 'KickA'
    product     = 'Lights Out'
    version     = "$version.0"
}
if (Test-Path $icon) { $params['iconFile'] = $icon }

Invoke-ps2exe @params

Copy-Item (Join-Path $root 'README.md') (Join-Path $dist 'README.txt') -Force
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $dist 'LICENSE') -Force
$modDir = Join-Path $dist 'modules'
New-Item -ItemType Directory -Path $modDir -Force | Out-Null
foreach ($modFile in @('LightsOut.Calendar.psm1', 'LightsOut.Novel.psm1', 'LightsOut.Profiles.psm1', 'LightsOut.LastLight.psm1', 'LightsOut.TonightCards.psm1', 'LightsOut.SteamTheme.psm1', 'LightsOut.Demo.psm1')) {
    $p = Join-Path $root "modules\$modFile"
    if (Test-Path $p) { Copy-Item $p $modDir -Force }
}
if (Test-Path $icon) { Copy-Item $icon (Join-Path $dist 'SleepTimer.ico') -Force }
$logo = Join-Path $root 'assets\LightsOut-Logo.png'
if (Test-Path $logo) { Copy-Item $logo (Join-Path $dist 'LightsOut-Logo.png') -Force }
"Sleep Timer $version`nBuild: $(Get-Date -Format o)" | Set-Content (Join-Path $dist 'BUILD_INFO.txt')

if (-not $SkipDesktop) {
    & (Join-Path $root 'scripts\Deploy-SleepTimer-Desktop.ps1')
}

if (-not $SkipInstaller) {
    $iscc = @(
        (Get-Command ISCC.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
        "$env:ProgramData\chocolatey\bin\ISCC.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if ($iscc) {
        $iss = Join-Path $root 'installer\lights-out.iss'
        if (-not (Test-Path $iss)) { $iss = Join-Path $root 'installer\nightfall.iss' }
        & $iscc $iss
        Write-Host 'Installer built.' -ForegroundColor Green
    } else {
        Write-Host 'Inno Setup not found — skip installer.' -ForegroundColor Yellow
    }
}

Write-Host "Release: $outExe" -ForegroundColor Green

if ($env:SLEEPTIMER_SIGN_PFX -or (Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue)) {
    & (Join-Path $root 'scripts\Sign-Release.ps1') -ErrorAction SilentlyContinue
}
