#Requires -Version 5.1
<#
.SYNOPSIS
    Full local CI gate — safe: never launches Sleep Timer (no shutdown risk).
#>
param(
    [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$artifactDir = Join-Path $root "ci-artifacts\local-$stamp"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Sleep Timer — Local CI (safe mode)' -ForegroundColor Cyan
Write-Host "  Artifacts: $artifactDir" -ForegroundColor DarkGray
Write-Host '  No GUI tests — will NOT launch timer' -ForegroundColor DarkGray
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

$sw = [System.Diagnostics.Stopwatch]::StartNew()

& (Join-Path $root 'scripts\Test-AgentSafety.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $root 'scripts\Test-Docs.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $root 'scripts\Test-SleepTimer.ps1') -Build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipInstaller) {
    $iscc = @(
        (Get-Command ISCC.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
        "$env:ProgramData\chocolatey\bin\ISCC.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if ($iscc) {
        Write-Host '--- Inno Setup ---' -ForegroundColor Cyan
        & $iscc (Join-Path $root 'installer\nightfall.iss')
        $setup = Get-ChildItem (Join-Path $root 'installer\output\LightsOut-Setup-*.exe') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $setup) {
            $setup = Get-ChildItem (Join-Path $root 'installer\output\SleepTimer-Setup-*.exe') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        if ($setup) {
            Write-Host "  PASS  installer $($setup.Name)" -ForegroundColor Green
            Copy-Item $setup.FullName $artifactDir
            & (Join-Path $root 'scripts\Sign-Release.ps1') -ErrorAction SilentlyContinue
        } else {
            Write-Host '  FAIL  installer not found' -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host '  SKIP  Inno Setup not installed' -ForegroundColor Yellow
    }
}

$release = Join-Path $root 'dist\Release'
foreach ($f in @('SleepTimer.exe', 'SleepTimer.ico', 'LICENSE', 'README.txt', 'BUILD_INFO.txt', 'SHA256.txt')) {
    $p = Join-Path $release $f
    if (Test-Path $p) { Copy-Item $p $artifactDir }
}
$setupOut = Get-ChildItem (Join-Path $root 'installer\output\LightsOut-Setup-*.exe') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $setupOut) {
    $setupOut = Get-ChildItem (Join-Path $root 'installer\output\SleepTimer-Setup-*.exe') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if ($setupOut) { Copy-Item $setupOut.FullName $artifactDir }

$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
@"
Sleep Timer Local CI (safe)
Version: $version
Time: $(Get-Date -Format o)
Duration: $($sw.Elapsed.ToString('mm\:ss'))
Note: GUI smoke tests disabled — no app launch
"@ | Set-Content (Join-Path $artifactDir 'CI_REPORT.txt')

$latest = Join-Path $root 'ci-artifacts\latest'
if (Test-Path $latest) { Remove-Item $latest -Recurse -Force }
Copy-Item $artifactDir $latest -Recurse

$sw.Stop()
Write-Host ''
Write-Host "CI PASSED in $($sw.Elapsed.ToString('mm\:ss'))" -ForegroundColor Green
