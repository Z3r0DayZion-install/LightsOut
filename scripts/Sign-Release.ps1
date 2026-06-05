#Requires -Version 5.1
<#
.SYNOPSIS
    Authenticode-sign release artifacts (optional — skips if no certificate).
.DESCRIPTION
    Set SLEEPTIMER_SIGN_PFX to a .pfx path, or install cert in CurrentUser\My.
    Optional: SLEEPTIMER_SIGN_PASSWORD for PFX password.
.EXAMPLE
    $env:SLEEPTIMER_SIGN_PFX = 'C:\certs\sleeptimer.pfx'
    $env:SLEEPTIMER_SIGN_PASSWORD = 'secret'
    .\scripts\Sign-Release.ps1
#>
param(
    [string]$PfxPath = $env:SLEEPTIMER_SIGN_PFX,
    [string]$Password = $env:SLEEPTIMER_SIGN_PASSWORD,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targets = @(
    (Join-Path $root 'dist\Release\SleepTimer.exe')
    (Get-ChildItem (Join-Path $root 'installer\output\SleepTimer-Setup-*.exe') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName)
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $targets) {
    Write-Host 'Nothing to sign. Run Build-Release.ps1 first.' -ForegroundColor Yellow
    exit 0
}

$signtool = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe"
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x86\signtool.exe"
) | ForEach-Object { Get-ChildItem $_ -ErrorAction SilentlyContinue } | Sort-Object FullName -Descending | Select-Object -First 1

if (-not $signtool) {
    Write-Host 'signtool.exe not found (install Windows SDK). Skipping sign.' -ForegroundColor Yellow
    exit 0
}

function Get-SignArgs {
    if ($PfxPath -and (Test-Path $PfxPath)) {
        $args = @('/f', $PfxPath)
        if ($Password) { $args += @('/p', $Password) }
        return $args
    }
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
        Sort-Object NotAfter -Descending | Select-Object -First 1
    if ($cert) {
        Write-Host "Using cert: $($cert.Subject)" -ForegroundColor DarkGray
        return @('/sha1', $cert.Thumbprint)
    }
    return $null
}

$signArgs = Get-SignArgs
if (-not $signArgs) {
    Write-Host 'No signing certificate (SLEEPTIMER_SIGN_PFX or CodeSigning cert). Skipping.' -ForegroundColor Yellow
    exit 0
}

$ts = 'http://timestamp.digicert.com'
foreach ($file in $targets) {
    Write-Host "Signing $file ..." -ForegroundColor Cyan
    & $signtool.FullName sign @signArgs /tr $ts /td sha256 /fd sha256 $file
    if ($LASTEXITCODE -ne 0) { throw "signtool failed for $file" }
    $sig = Get-AuthenticodeSignature $file
    if ($sig.Status -ne 'Valid' -and $sig.Status -ne 'UnknownError') {
        Write-Host "  Status: $($sig.Status)" -ForegroundColor Yellow
    } else {
        Write-Host "  OK ($($sig.Status))" -ForegroundColor Green
    }
}

Write-Host 'Signing complete.' -ForegroundColor Green
