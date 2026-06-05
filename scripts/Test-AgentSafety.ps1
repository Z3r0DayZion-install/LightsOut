#Requires -Version 5.1
<#
.SYNOPSIS
    Static lint: docs/scripts must not introduce unsafe SleepTimer.exe launches without -DryRun.
.NOTES
    Does NOT launch SleepTimer.exe. USER_LAUNCHER marks approved end-user .bat / explicit -Launch paths.
#>
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0
$contextWindow = 12

function Write-Pass([string]$Name) {
    if (-not $Quiet) { Write-Host "  PASS  $Name" -ForegroundColor Green }
    $script:passed++
}

function Write-Fail([string]$Name, [string]$Detail) {
    if (-not $Quiet) {
        Write-Host "  FAIL  $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkRed }
    }
    $script:failures.Add("$Name`: $Detail")
}

function Test-IsReferenceOnlyLine {
    param([string]$Line)
    return ($Line -match '(?i)(Copy-Item|Join-Path|Test-Path|Get-ChildItem|Get-Content|Select-String|Write-Host|Out-File|Set-Content|`\`|^\s*\||InstallerUrl|DestDir|\.iss|SHA256|dist[/\\]Release|not found|Missing|Forbidden patterns|wildcard|\*\SleepTimer\.exe\*|Never run|Do not run|without -DryRun|without `-DryRun|without safe args|must not|must consult|grep|Pattern\s*=|Did any script call|^-\s|Select-String\s+-Path)')
}

function Test-IsSleepTimerLaunchLine {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $false }
    if (Test-IsReferenceOnlyLine $Line) { return $false }

    if ($Line -match '(?i)Start-Process') {
        if ($Line -match '(?i)SleepTimer|FilePath\s+\$exe|\$outExe') { return $true }
    }
    if ($Line -match '(?i)start\s+""\s*[^`n]*SleepTimer\.exe') { return $true }
    if ($Line -match '(?i)^\s*&\s+[^`n]*SleepTimer\.exe') { return $true }
    if ($Line -match '(?i)^\s*\.\\SleepTimer\.exe\b') { return $true }
    return $false
}

function Test-IsSafeLaunchContext {
    param(
        [string]$Line,
        [string[]]$PriorLines
    )
    if ($Line -match '(?i)(-DryRun|/DryRun|-Demo|/Demo|ArgumentList[^\n]*(DryRun|Demo)|SLEEPTIMER_DRY_RUN|SLEEPTIMER_DEMO|SLEEPTIMER_CI\s*=\s*[''""]?1)') {
        return $true
    }
    $ctx = ($PriorLines + $Line) -join "`n"
    if ($ctx -match 'USER_LAUNCHER') { return $true }
    return $false
}

function Test-ScanFile {
    param(
        [string]$FilePath,
        [switch]$AgentDoc
    )
    $rel = $FilePath.Substring($root.Length).TrimStart('\', '/')
    $lines = Get-Content -LiteralPath $FilePath -ErrorAction Stop
    $inForbiddenDocSection = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($AgentDoc -and $line -match '(?i)^##\s+Forbidden patterns') {
            $inForbiddenDocSection = $true
            continue
        }
        if ($AgentDoc -and $inForbiddenDocSection -and $line -match '^##\s+') {
            $inForbiddenDocSection = $false
        }
        if ($inForbiddenDocSection) { continue }

        if (-not (Test-IsSleepTimerLaunchLine $line)) { continue }

        $start = [math]::Max(0, $i - $contextWindow)
        $prior = @($lines[$start..([math]::Max($start, $i - 1))])
        if (Test-IsSafeLaunchContext $line $prior) { continue }

        Write-Fail $rel "line $($i + 1): unsafe SleepTimer.exe launch without -DryRun or USER_LAUNCHER"
    }
}

if (-not $Quiet) {
    Write-Host '=== Agent safety lint (static — no app launch) ===' -ForegroundColor Cyan
}

$scriptFiles = Get-ChildItem -Path (Join-Path $root 'scripts') -Filter '*.ps1' -File |
    Where-Object { $_.Name -ne 'Test-AgentSafety.ps1' }

foreach ($file in $scriptFiles) {
    Test-ScanFile -FilePath $file.FullName
}

$agentDocFiles = @(
    (Join-Path $root 'AGENTS.md')
) + @(Get-ChildItem -Path (Join-Path $root 'docs\agent-handbook') -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })

foreach ($file in $agentDocFiles) {
    if (-not (Test-Path $file)) { continue }
    Test-ScanFile -FilePath $file -AgentDoc
}

if ($failures.Count -eq 0) {
    Write-Pass "agent-safety-lint ($($scriptFiles.Count) scripts, $($agentDocFiles.Count) agent docs)"
    if (-not $Quiet) {
        Write-Host ''
        Write-Host "Passed: $passed | Failed: 0" -ForegroundColor Green
    }
    exit 0
}

if (-not $Quiet) {
    Write-Host ''
    Write-Host "Passed: $passed | Failed: $($failures.Count)" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor DarkRed }
}
exit 1
