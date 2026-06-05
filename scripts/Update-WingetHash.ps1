#Requires -Version 5.1
param(
    [string]$ExePath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'dist\Release\SleepTimer.exe'),
    [string]$Manifest = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'packaging\winget\KickA.SleepTimer.yaml')
)
if (-not (Test-Path $ExePath)) { throw "Build release first: $ExePath" }
$hash = (Get-FileHash $ExePath -Algorithm SHA256).Hash
$content = Get-Content $Manifest -Raw
$content = $content -replace '(?m)^(\s*InstallerSha256:\s*).*$', "`${1}$hash"
$content | Set-Content $Manifest -Encoding UTF8
Write-Host "SHA256: $hash"
