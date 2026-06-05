#Requires -Version 5.1
# Produces a single self-contained .ps1 for PS2EXE (module inlined, correct order)
param(
    [ValidateSet('Dev', 'Release')]
    [string]$Channel = 'Dev'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$module = Join-Path $root 'modules\Nightfall.Core.psm1'
$app = Join-Path $root 'CoolTimer.ps1'
$out = Join-Path $root 'dist\Nightfall.bundle.ps1'

$core = Get-Content $module -Raw
$core = $core -replace '(?ms)Export-ModuleMember.*$', ''

$appLines = Get-Content $app
$requires = ($appLines | Where-Object { $_ -match '^#Requires' }) -join "`n"
$paramLines = New-Object System.Collections.Generic.List[string]
$bodyLines = New-Object System.Collections.Generic.List[string]
$inParam = $false
$skipRoot = $false
foreach ($line in $appLines) {
    if ($line -match '^#Requires') { continue }
    if ($line -match '^\[CmdletBinding') { $inParam = $true; [void]$paramLines.Add($line); continue }
    if ($inParam) {
        [void]$paramLines.Add($line)
        if ($line -match '^\)') { $inParam = $false }
        continue
    }
    if ($line -match '^\$script:Root\s*=') { $skipRoot = $true; continue }
    if ($skipRoot) {
        if ($line -match '^\$script:IsRelease\s*=') { $skipRoot = $false }
        continue
    }
    if ($line -match 'Import-Module.*Nightfall\.Core') { continue }
    [void]$bodyLines.Add($line)
}

$hostInit = @"
function Initialize-NightfallHost {
    `$script:Root = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    `$channelFile = Join-Path `$script:Root 'channel.txt'
    if (Test-Path `$channelFile) {
        Set-NightfallChannel -Name ((Get-Content `$channelFile -Raw).Trim())
    } else {
        Set-NightfallChannel -Name '$Channel'
    }
    `$script:Version = Get-NightfallVersion
    `$script:IsRelease = (`$script:Channel -eq 'Release')
}
"@

$injectAfter = '[System.Windows.Forms.Application]::EnableVisualStyles()'
$mergedBody = New-Object System.Collections.Generic.List[string]
foreach ($line in $bodyLines) {
    [void]$mergedBody.Add($line)
    if ($line.Trim() -eq $injectAfter) {
        [void]$mergedBody.Add('')
        [void]$mergedBody.Add('Initialize-NightfallHost')
    }
}

$header = "# Nightfall bundled $Channel $(Get-Date -Format 'yyyy-MM-dd')"
$parts = @($header)
if ($requires) { $parts += $requires }
$parts += ($paramLines -join "`n")
$parts += $core
$parts += $hostInit
$parts += ($mergedBody -join "`n")

$body = $parts -join "`n`n"
$body = [regex]::Replace($body, '[^\x09\x0A\x0D\x20-\x7E]', '-')
$utf8Bom = New-Object System.Text.UTF8Encoding $true
New-Item -ItemType Directory -Path (Split-Path $out) -Force | Out-Null
[System.IO.File]::WriteAllText($out, $body, $utf8Bom)
Write-Host "Bundled ($Channel): $out ($((Get-Item $out).Length) bytes)"
