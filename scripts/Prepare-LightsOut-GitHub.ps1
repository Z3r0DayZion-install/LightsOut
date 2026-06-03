#Requires -Version 5.1
<#
.SYNOPSIS
    Build a standalone Lights Out folder ready for GitHub (new repo or release bundle).
.EXAMPLE
    .\scripts\Prepare-LightsOut-GitHub.ps1
    .\scripts\Prepare-LightsOut-GitHub.ps1 -Open
#>
param([switch]$Open)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$out = Join-Path $root 'dist\LightsOut-GitHub'

Write-Host '=== Prepare Lights Out GitHub bundle ===' -ForegroundColor Cyan

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out -Force | Out-Null

# Core product files
$copyFiles = @(
    'LICENSE', 'CHANGELOG.md', 'VERSION', 'PRODUCT.md',
    'PRODUCT_ROADMAP.md', 'LUXGRID-LIGHTSOUT.md', 'SECURITY.md', 'SleepTimer-Tonight.ps1'
)
foreach ($f in $copyFiles) {
    $src = Join-Path $root $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $out $f) -Force }
}

# Standalone sales README (paths adjusted for dedicated repo root)
$readme = Get-Content (Join-Path $root 'README.md') -Raw
$readme = $readme -replace 'docs/lights-out/', 'docs/'
$readme = $readme -replace 'ForgeCore_OS/windsurf-project', 'LightsOut'
$readme = $readme -replace 'cd windsurf-project\s*\r?\n', ''
$readme = $readme -replace 'windsurf-project/', ''
$readme = $readme -replace '\(\.\./luxgrid/\)', '(https://github.com/Z3r0DayZion-install/LuxGrid)'
$readme | Set-Content (Join-Path $out 'README.md') -Encoding UTF8

# Docs + assets
New-Item -ItemType Directory -Path (Join-Path $out 'docs') -Force | Out-Null
Copy-Item (Join-Path $root 'docs\lights-out\*') (Join-Path $out 'docs\') -Force
Copy-Item (Join-Path $root 'assets') (Join-Path $out 'assets') -Recurse -Force

# Packaging + GitHub meta
Copy-Item (Join-Path $root 'packaging\winget') (Join-Path $out 'packaging\winget') -Recurse -Force
$lgPack = Join-Path $root 'packaging\luxgrid'
if (Test-Path $lgPack) {
    New-Item -ItemType Directory -Path (Join-Path $out 'packaging\luxgrid') -Force | Out-Null
    Copy-Item (Join-Path $lgPack '*') (Join-Path $out 'packaging\luxgrid') -Force
}
Copy-Item (Join-Path $root '.github') (Join-Path $out '.github') -Recurse -Force -ErrorAction SilentlyContinue

# Essential scripts (subset)
$scriptOut = Join-Path $out 'scripts'
New-Item -ItemType Directory -Path $scriptOut -Force | Out-Null
foreach ($s in @(
    'Build-Release.ps1', 'Deploy-SleepTimer-Desktop.ps1', 'CI-Local.ps1',
    'Test-SleepTimer.ps1', 'Test-SleepTimer-Logic.ps1', 'Test-Daytime.ps1',
    'Publish-GitHubRelease.ps1', 'Create-LightsOut-Repo.ps1', 'Prepare-LightsOut-GitHub.ps1',
    'Create-NightfallIcon.ps1', 'Install-LuxGrid-LightsOut.ps1',
    'Export-LuxGrid-SleepRitualPack.ps1',
    'Update-WingetHash.ps1', 'Submit-Winget.ps1'
)) {
    $src = Join-Path $root "scripts\$s"
    if (Test-Path $src) { Copy-Item $src $scriptOut -Force }
}

# Installer
$installerOut = Join-Path $out 'installer'
New-Item -ItemType Directory -Path $installerOut -Force | Out-Null
Copy-Item (Join-Path $root 'installer\lights-out.iss') (Join-Path $installerOut 'lights-out.iss') -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $root 'installer\nightfall.iss') (Join-Path $installerOut 'nightfall.iss') -Force -ErrorAction SilentlyContinue

# Modules (required at runtime for portable exe)
$modOut = Join-Path $out 'modules'
New-Item -ItemType Directory -Path $modOut -Force | Out-Null
foreach ($m in @('LightsOut.Calendar.psm1', 'LightsOut.Novel.psm1')) {
    $src = Join-Path $root "modules\$m"
    if (Test-Path $src) { Copy-Item $src $modOut -Force }
}

# Release exe if built
$releaseExe = Join-Path $root 'dist\Release\SleepTimer.exe'
if (Test-Path $releaseExe) {
    New-Item -ItemType Directory -Path (Join-Path $out 'dist\Release') -Force | Out-Null
    Copy-Item $releaseExe (Join-Path $out 'dist\Release\SleepTimer.exe') -Force
    $sha = Join-Path $root 'dist\Release\SHA256.txt'
    if (Test-Path $sha) { Copy-Item $sha (Join-Path $out 'dist\Release\') -Force }
    $relMod = Join-Path $root 'dist\Release\modules'
    if (Test-Path $relMod) {
        Copy-Item $relMod (Join-Path $out 'dist\Release\modules') -Recurse -Force
    }
}

@"
Lights Out GitHub bundle v$version
Generated: $(Get-Date -Format o)

Next steps:
  cd dist\LightsOut-GitHub
  git init
  git add .
  git commit -m "Lights Out v$version"
  gh repo create Z3r0DayZion-install/LightsOut --public --source=. --push
"@ | Set-Content (Join-Path $out 'PUBLISH.txt') -Encoding UTF8

Write-Host "Bundle: $out" -ForegroundColor Green
Write-Host (Get-Content (Join-Path $out 'PUBLISH.txt') -Raw)

if ($Open) { explorer $out }
