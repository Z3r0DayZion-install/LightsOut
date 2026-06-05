#Requires -Version 5.1
<#
    Build targets. Dev = CoolTimer.ps1 experiment (NOT canonical Lights Out).
    Release = SleepTimer-Tonight.ps1 via Build-Release.ps1 (canonical).
#>
param(
    [ValidateSet('Dev', 'Release', 'All')]
    [string]$Target = 'All'
)
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($Target -in 'Dev', 'All') {
    Write-Host '--- Dev build ---' -ForegroundColor Cyan
    & (Join-Path $root 'scripts\Build-CoolTimer.ps1')
}
if ($Target -in 'Release', 'All') {
    Write-Host '--- Release build ---' -ForegroundColor Cyan
    & (Join-Path $root 'scripts\Build-Release.ps1')
}
