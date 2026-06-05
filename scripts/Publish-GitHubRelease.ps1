#Requires -Version 5.1
<#
.SYNOPSIS
    Build, sign, and publish Lights Out to GitHub Releases via gh CLI.
.EXAMPLE
    .\scripts\Publish-GitHubRelease.ps1
    .\scripts\Publish-GitHubRelease.ps1 -SkipBuild -Draft
#>
param(
    [switch]$SkipBuild,
    [switch]$Draft,
    [string]$Repo = 'Z3r0DayZion-install/ForgeCore_OS'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$tag = "v$version"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) not found. Install: winget install GitHub.cli'
}

if (-not $SkipBuild) {
    & (Join-Path $root 'scripts\CI-Local.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'CI-Local failed' }
    & (Join-Path $root 'scripts\Build-Release.ps1') -SkipDesktop
    if ($LASTEXITCODE -ne 0) { throw 'Build-Release failed' }
}

$exe = Join-Path $root 'dist\Release\SleepTimer.exe'
$setup = Get-ChildItem (Join-Path $root 'installer\output\LightsOut-Setup-*.exe') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $setup) {
    $setup = Get-ChildItem (Join-Path $root 'installer\output\SleepTimer-Setup-*.exe') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
$sha = Join-Path $root 'dist\Release\SHA256.txt'
$readme = Join-Path $root 'docs\lights-out\RELEASE-NOTES.md'
$portableZip = Join-Path $root "dist\Release\LightsOut-portable-$version.zip"

if (-not (Test-Path $exe)) { throw "Missing $exe" }

# Portable zip: exe + modules (required for calendar / novel features)
$modSrc = Join-Path $root 'dist\Release\modules'
if (-not (Test-Path $modSrc)) {
    $modSrc = Join-Path $root 'modules'
    New-Item -ItemType Directory -Path (Join-Path $root 'dist\Release\modules') -Force | Out-Null
    Copy-Item (Join-Path $modSrc '*.psm1') (Join-Path $root 'dist\Release\modules') -Force
    $modSrc = Join-Path $root 'dist\Release\modules'
}
if (Test-Path $modSrc) {
    if (Test-Path $portableZip) { Remove-Item $portableZip -Force }
    $stage = Join-Path $env:TEMP "lo-portable-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Copy-Item $exe (Join-Path $stage 'SleepTimer.exe') -Force
    Copy-Item $modSrc (Join-Path $stage 'modules') -Recurse -Force
    $ico = Join-Path $root 'dist\Release\SleepTimer.ico'
    if (Test-Path $ico) { Copy-Item $ico $stage -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $portableZip -Force
    Remove-Item $stage -Recurse -Force
    Write-Host "Portable: $portableZip" -ForegroundColor DarkGray
}

# Update winget hashes
& (Join-Path $root 'scripts\Update-WingetHash.ps1') -ExePath $exe -Manifest (Join-Path $root 'packaging\winget\KickA.LightsOut.yaml')
& (Join-Path $root 'scripts\Update-WingetHash.ps1') -ExePath $exe -Manifest (Join-Path $root 'packaging\winget\KickA.SleepTimer.yaml')

$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw
$section = if ($changelog -match "(?s)## \[$version\][^\#]+") { $Matches[0].Trim() } else { "See CHANGELOG.md" }

$notes = @"
# Lights Out $tag

**The bedtime shutdown timer for Windows.**

## Install

``````powershell
winget install KickA.LightsOut
``````

Or download **LightsOut-portable.zip** or **SleepTimer.exe** below.

## What's new

$section

## Files

| File | Description |
|------|-------------|
| SleepTimer.exe | Portable app (Lights Out) |
| LightsOut-portable-$version.zip | Exe + modules folder |
| LightsOut-Setup-$version.exe | Inno installer (if attached) |
| SHA256.txt | Checksums |

## Safety

- 60-second minimum timer in production builds
- **Ctrl+Shift+S** emergency cancel
- No telemetry — local audit log only

Full readme: [windsurf-project/README.md](https://github.com/$Repo/blob/main/windsurf-project/README.md)
"@

Set-Content $readme $notes -Encoding UTF8

$ghArgs = @(
    'release', 'create', $tag, $exe,
    '--title', "Lights Out $tag",
    '--notes-file', $readme
)
if ($setup) { $ghArgs += $setup.FullName }
if (Test-Path $portableZip) { $ghArgs += $portableZip }
$license = Join-Path $root 'LICENSE'
if (Test-Path $license) { $ghArgs += $license }
if (Test-Path $sha) { $ghArgs += $sha }
$logo = Join-Path $root 'docs\lights-out\logo.png'
if (Test-Path $logo) { $ghArgs += $logo }
if ($Draft) { $ghArgs += '--draft' }
if ($Repo) { $ghArgs += @('--repo', $Repo) }

Write-Host "Publishing Lights Out $tag ..." -ForegroundColor Cyan
& gh @ghArgs
Write-Host "Done: https://github.com/$Repo/releases/tag/$tag" -ForegroundColor Green
