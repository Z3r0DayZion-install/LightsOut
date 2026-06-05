#Requires -Version 5.1
<#
.SYNOPSIS
    Static lint: README and docs/lights-out must link correctly and not imply unsafe launches or hard deps.
.NOTES
    Does NOT launch SleepTimer.exe.
#>
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0

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

if (-not $Quiet) {
    Write-Host '=== Documentation lint (static — no app launch) ===' -ForegroundColor Cyan
}

# --- Required files ---
$required = @(
    'README.md'
    'docs\lights-out\UI-REFERENCE.md'
    'docs\lights-out\INTEGRATION-CONTRACT.md'
    'docs\lights-out\SAFETY-MODEL.md'
    'docs\lights-out\GETTING-STARTED.md'
    'docs\lights-out\CLI.md'
    'docs\lights-out\RELEASE-CHECKLIST.md'
    'docs\lights-out\CI.md'
)
foreach ($rel in $required) {
    $p = Join-Path $root $rel
    if (Test-Path $p) { Write-Pass "exists:$rel" }
    else { Write-Fail "exists:$rel" 'missing required doc' }
}

# --- README links ---
$readme = Get-Content (Join-Path $root 'README.md') -Raw -ErrorAction SilentlyContinue
if ($readme) {
    $linkChecks = @{
        'README->GETTING-STARTED' = 'docs/lights-out/GETTING-STARTED.md'
        'README->SAFETY-MODEL'    = 'docs/lights-out/SAFETY-MODEL.md'
        'README->CLI'             = 'docs/lights-out/CLI.md'
        'README->UI-REFERENCE'    = 'docs/lights-out/UI-REFERENCE.md'
        'README->INTEGRATION'     = 'docs/lights-out/INTEGRATION-CONTRACT.md'
        'README->RELEASE'         = 'docs/lights-out/RELEASE-CHECKLIST.md'
        'README->CI'              = 'docs/lights-out/CI.md'
    }
    foreach ($kv in $linkChecks.GetEnumerator()) {
        if ($readme -match [regex]::Escape($kv.Value)) { Write-Pass $kv.Key }
        else { Write-Fail $kv.Key "README must link to $($kv.Value)" }
    }
    if ($readme -match 'Classic UI.*default|default live|Normal.*Classic') { Write-Pass 'README-classic-default' }
    else { Write-Fail 'README-classic-default' 'README must state Classic is default live path' }
    if ($readme -match 'Premium Preview|Lights Out Premium Preview') { Write-Pass 'README-premium-preview' }
    else { Write-Fail 'README-premium-preview' 'README must document Premium Preview launcher' }
}

# --- Doc content rules ---
$docFiles = @(
    (Join-Path $root 'README.md')
) + @(Get-ChildItem -Path (Join-Path $root 'docs\lights-out') -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })

function Test-ImpliesHardDependency {
    param([string]$Text)
    $lines = $Text -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $ctxStart = [math]::Max(0, $i - 4)
        $ctx = ($lines[$ctxStart..$i] -join "`n")
        if ($line -match '(?i)(no cloud|not required|optional|without LuxGrid|without NeuralOS|never required|hard dependency never|off by default|not a cloud|out of scope|do not claim|\|\s*\*\*No\*\*|required\s*\|\s*\*\*No\*\*)') { continue }
        if ($ctx -match '(?i)out of scope') { continue }
        if ($line -match '(?i)(LuxGrid\s+(is\s+)?required|NeuralOS\s+(is\s+)?required|must\s+install\s+LuxGrid|requires\s+LuxGrid|requires\s+NeuralOS)') { return $true }
        if ($line -match '(?i)cloud\s+sync' -and $line -notmatch '(?i)(no cloud|not claim|without|do not claim)') { return $true }
    }
    return $false
}

$steamLivePatterns = @(
    '(?i)normal\s+(shortcut|launcher).*-SteamUi(?!.*DryRun)'
    '(?i)default\s+launcher.*-SteamUi(?!.*DryRun)'
    '(?i)live.*-SteamUi(?!.*DryRun)'
)

# Skip research/idea briefs — not public-facing install docs
$skipHardDepScan = @(
    'docs\lights-out\UI-RESEARCH-REPORT.md'
    'docs\lights-out\AGENT-IDEA-BRIEF.md'
)

foreach ($file in $docFiles) {
    $rel = $file.Substring($root.Length).TrimStart('\', '/')
    $text = Get-Content -LiteralPath $file -Raw
    if ($skipHardDepScan -notcontains $rel -and (Test-ImpliesHardDependency $text)) {
        Write-Fail $rel 'implies hard dependency on LuxGrid/NeuralOS/cloud'
    }
    foreach ($pat in $steamLivePatterns) {
        if ($text -match $pat) {
            Write-Fail $rel "implies Steam is normal live launcher: $pat"
        }
    }
}
if ($failures.Count -eq 0 -or ($failures | Where-Object { $_ -match 'hard dependency|Steam is normal' }).Count -eq 0) {
    Write-Pass 'no-hard-deps-in-docs'
    Write-Pass 'no-steam-as-live-launcher-in-docs'
}

# --- Unsafe automated launch lines in docs ---
$contextWindow = 10
function Test-IsReferenceOnlyLine {
    param([string]$Line)
    return ($Line -match '(?i)(Copy-Item|Join-Path|Test-Path|Get-Content|Write-Host|Out-File|Set-Content|`\`|^\s*#|^\s*//|must not|Do not|Never in CI|Human|live use|USER_LAUNCHER|safe preview|DryRun|without -DryRun|grep|Pattern)')
}

foreach ($file in $docFiles) {
    $rel = $file.Substring($root.Length).TrimStart('\', '/')
    $isUserDoc = ($rel -eq 'README.md') -or ($rel -like 'docs/lights-out/*') -or ($rel -like 'docs\lights-out\*')
    $lines = Get-Content -LiteralPath $file
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if (Test-IsReferenceOnlyLine $line) { continue }
        if ($line -notmatch '(?i)Start-Process.*SleepTimer') { continue }
        if ($line -match '(?i)(-DryRun|/DryRun|-Demo|/Demo|ArgumentList[^\n]*(DryRun|Demo)|SLEEPTIMER_DRY_RUN|SLEEPTIMER_DEMO)') { continue }
        $start = [math]::Max(0, $i - $contextWindow)
        $ctx = ($lines[$start..$i] -join "`n")
        if ($ctx -match 'USER_LAUNCHER|Human-requested|live use|Tonight|bedtime use only|never in CI|Safe vs live|safe preview|DryRun only') { continue }
        if ($isUserDoc) { continue }
        Write-Fail $rel "line $($i+1): doc shows Start-Process SleepTimer without DryRun"
    }
}
if (-not ($failures | Where-Object { $_ -match 'doc shows SleepTimer' })) {
    Write-Pass 'doc-launch-safety'
}

if ($failures.Count -eq 0) {
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
