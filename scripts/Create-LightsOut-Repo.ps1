#Requires -Version 5.1
<#
.SYNOPSIS
    Prepare bundle and create public Lights Out GitHub repo.
.EXAMPLE
    .\scripts\Create-LightsOut-Repo.ps1
    .\scripts\Create-LightsOut-Repo.ps1 -SkipPush
#>
param([switch]$SkipPush)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$commitMsg = "Lights Out v$version - bedtime shutdown timer for Windows"

& (Join-Path $root 'scripts\Prepare-LightsOut-GitHub.ps1')
$bundle = Join-Path $root 'dist\LightsOut-GitHub'

Push-Location $bundle
try {
    if (-not (Test-Path '.git')) { git init | Out-Null }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    git add .
    git config user.email "lightsout@users.noreply.github.com"
    git config user.name "Lights Out Release"
    git commit -m $commitMsg 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Nothing new to commit or commit failed - continuing' -ForegroundColor DarkGray
    }
    $ErrorActionPreference = $prevEap

    if ($SkipPush) {
        Write-Host "SkipPush - bundle ready at $bundle" -ForegroundColor Yellow
        return
    }

    $repoExists = $false
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    gh repo view Z3r0DayZion-install/LightsOut 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $repoExists = $true }
    $ErrorActionPreference = $prevEap

    if ($repoExists) {
        Write-Host 'Repo exists - pushing...' -ForegroundColor Cyan
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        git remote remove origin 2>$null | Out-Null
        $ErrorActionPreference = $prevEap
        git remote add origin https://github.com/Z3r0DayZion-install/LightsOut.git
        git branch -M main
        git push -u origin main --force
    } else {
        gh repo create Z3r0DayZion-install/LightsOut --public --source=. --remote=origin --push `
            --description "The bedtime shutdown timer for Windows - open, countdown, lights out."
    }

    gh repo edit Z3r0DayZion-install/LightsOut `
        --add-topic windows --add-topic sleep --add-topic shutdown --add-topic timer --add-topic bedtime `
        --homepage "https://github.com/Z3r0DayZion-install/ForgeCore_OS/releases/tag/v$version"

    Write-Host "https://github.com/Z3r0DayZion-install/LightsOut" -ForegroundColor Green
} finally {
    Pop-Location
}
