#Requires -Version 5.1
<#
.SYNOPSIS
    Submit Lights Out manifest(s) to microsoft/winget-pkgs.
.EXAMPLE
    .\scripts\Submit-Winget.ps1 -Package LightsOut
    .\scripts\Submit-Winget.ps1 -Package Both -DryRun
#>
param(
    [ValidateSet('LightsOut', 'SleepTimer', 'Both')]
    [string]$Package = 'LightsOut',
    [switch]$DryRun,
    [string]$Fork = 'Z3r0DayZion-install/winget-pkgs'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$exe = Join-Path $root 'dist\Release\SleepTimer.exe'

if (-not (Test-Path $exe)) {
    & (Join-Path $root 'scripts\Build-Release.ps1') -SkipDesktop -SkipInstaller
}

$packages = switch ($Package) {
    'Both' { @('KickA.LightsOut', 'KickA.SleepTimer') }
    'SleepTimer' { @('KickA.SleepTimer') }
    default { @('KickA.LightsOut') }
}

foreach ($id in $packages) {
    $manifestName = "$id.yaml"
    $manifestSrc = Join-Path $root "packaging\winget\$manifestName"
    if (-not (Test-Path $manifestSrc)) { throw "Missing $manifestSrc" }
    & (Join-Path $root 'scripts\Update-WingetHash.ps1') -ExePath $exe -Manifest $manifestSrc
}

if ($DryRun) {
    foreach ($id in $packages) {
        Write-Host "=== $id ===" -ForegroundColor Cyan
        Get-Content (Join-Path $root "packaging\winget\$id.yaml")
    }
    exit 0
}

$work = Join-Path $env:TEMP "winget-pkgs-$([guid]::NewGuid().ToString('N'))"
Write-Host "Cloning $Fork ..." -ForegroundColor Cyan
git clone --depth 1 "https://github.com/$Fork.git" $work
if (-not (Test-Path $work)) { throw "Failed to clone $Fork - fork https://github.com/microsoft/winget-pkgs first" }

Push-Location $work
try {
    $branch = "kicka-lightsout-$version"
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    git checkout -b $branch 2>&1 | Out-Null
    $ErrorActionPreference = $prevEap
    git config user.email "winget@users.noreply.github.com"
    git config user.name "Lights Out Release"

    $added = @()
    foreach ($id in $packages) {
        $short = $id.Split('.')[1]
        $manifestName = "$id.yaml"
        $manifestSrc = Join-Path $root "packaging\winget\$manifestName"
        $manifestDest = "manifests/k/KickA/$short/$version"
        $destDir = Join-Path $work ($manifestDest -replace '/', '\')
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item $manifestSrc (Join-Path $destDir $manifestName) -Force
        git add "$manifestDest/$manifestName"
        $added += "$manifestDest/$manifestName"
    }

    $commitMsg = if ($packages.Count -gt 1) { "KickA Lights Out / SleepTimer $version" } else { "New package: $($packages[0]) $version" }
    git commit -m $commitMsg
    git push -u origin $branch

    $manifestList = ($added | ForEach-Object { "- $_" }) -join [Environment]::NewLine
    $validateList = ($added | ForEach-Object { "winget validate --manifest $_" }) -join [Environment]::NewLine

    $body = @"
## Lights Out $version

The bedtime shutdown timer for Windows.

Publisher: KickA
Release: https://github.com/Z3r0DayZion-install/ForgeCore_OS/releases/tag/v$version
Portable: SleepTimer.exe (~130 KB)

Manifests:
$manifestList

Validation:
``````powershell
$validateList
``````
"@

    gh pr create --repo microsoft/winget-pkgs --head "$($Fork.Split('/')[0]):$branch" `
        --title "KickA.LightsOut $version" `
        --body $body
} finally {
    Pop-Location
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
