#Requires -Version 5.1
<#
.SYNOPSIS
    Sleep Timer Core - Modular Timer Engine
.DESCRIPTION
    Standalone timer application that exposes events/API for other modules.
    Can run alone or with RGB-Controller, Dashboard, or other extensions.
    Communicates via event files in %TEMP%\SleepTimer\Events\
#>

[CmdletBinding()]
param(
    [int]$Minutes = 30,
    [ValidateSet("Shutdown", "Restart", "Sleep", "Hibernate", "Lock", "Logoff")]
    [string]$Action = "Shutdown",
    [switch]$NoGUI,
    [switch]$Silent,
    [switch]$EventMode  # Output events for external apps
)

# ============================================
# MODULE SYSTEM
# ============================================
$script:ModuleName = "SleepTimer-Core"
$script:Version = "3.0"
$script:EventPath = Join-Path $env:TEMP "SleepTimer\Events"
$script:Modules = @()
$script:IsRunning = $false

# Ensure event directory exists
if (-not (Test-Path $script:EventPath)) {
    New-Item -ItemType Directory -Path $script:EventPath -Force | Out-Null
}

# ============================================
# EVENT SYSTEM (For Inter-Module Communication)
# ============================================
function Publish-TimerEvent {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Started", "Tick", "Warning", "Completed", "Cancelled", "Paused", "Resumed")]
        [string]$EventType,
        
        [hashtable]$Data = @{}
    )
    
    $event = @{
        Module = $script:ModuleName
        Version = $script:Version
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        EventType = $EventType
        Data = $Data
    }
    
    $fileName = "$EventType-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').json"
    $event | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $script:EventPath $fileName)
    
    # Also broadcast to console if EventMode
    if ($EventMode) {
        Write-Host "EVENT:$EventType|$(($Data | ConvertTo-Json -Compress))" -ForegroundColor Cyan
    }
}

function Register-TimerModule {
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [scriptblock]$OnTimerStart,
        [scriptblock]$OnTimerTick,
        [scriptblock]$OnTimerComplete,
        [scriptblock]$OnTimerCancel
    )
    
    $module = @{
        Name = $ModuleName
        OnStart = $OnTimerStart
        OnTick = $OnTick
        OnComplete = $OnTimerComplete
        OnCancel = $OnTimerCancel
    }
    
    $script:Modules += $module
    Write-Host "✓ Module registered: $ModuleName" -ForegroundColor Green
}

# ============================================
# TIMER ENGINE
# ============================================
$script:TimerState = @{
    Active = $false
    RemainingSeconds = 0
    TotalSeconds = 0
    StartTime = $null
    Action = ""
}

function Start-TimerEngine {
    param(
        [int]$DurationSeconds,
        [string]$TimerAction
    )
    
    $script:TimerState.Active = $true
    $script:TimerState.RemainingSeconds = $DurationSeconds
    $script:TimerState.TotalSeconds = $DurationSeconds
    $script:TimerState.StartTime = Get-Date
    $script:TimerState.Action = $TimerAction
    $script:IsRunning = $true
    
    # Notify modules
    foreach ($mod in $script:Modules) {
        if ($mod.OnStart) {
            & $mod.OnStart -TotalSeconds $DurationSeconds -Action $TimerAction
        }
    }
    
    # Publish event
    Publish-TimerEvent -EventType "Started" -Data @{
        TotalSeconds = $DurationSeconds
        Action = $TimerAction
        Minutes = [math]::Floor($DurationSeconds / 60)
    }
    
    # Main timer loop
    while ($script:TimerState.Active -and $script:TimerState.RemainingSeconds -gt 0) {
        $elapsed = $script:TimerState.TotalSeconds - $script:TimerState.RemainingSeconds
        $percent = [math]::Round(($elapsed / $script:TimerState.TotalSeconds) * 100)
        
        # Check for warning (2 minutes before)
        if ($script:TimerState.RemainingSeconds -eq 120) {
            Publish-TimerEvent -EventType "Warning" -Data @{
                RemainingSeconds = 120
                RemainingMinutes = 2
            }
        }
        
        # Notify modules on tick
        foreach ($mod in $script:Modules) {
            if ($mod.OnTick) {
                & $mod.OnTick `
                    -RemainingSeconds $script:TimerState.RemainingSeconds `
                    -PercentComplete $percent `
                    -TotalSeconds $script:TimerState.TotalSeconds
            }
        }
        
        # Publish tick event every 5 seconds (not every second to reduce I/O)
        if ($script:TimerState.RemainingSeconds % 5 -eq 0) {
            Publish-TimerEvent -EventType "Tick" -Data @{
                RemainingSeconds = $script:TimerState.RemainingSeconds
                PercentComplete = $percent
                ElapsedSeconds = $elapsed
            }
        }
        
        # Console progress
        if (-not $Silent) {
            $status = "$(Format-TimeSpan $script:TimerState.RemainingSeconds) - $TimerAction"
            Write-Progress -Activity "Sleep Timer Core" -Status $status -PercentComplete $percent
        }
        
        Start-Sleep -Seconds 1
        $script:TimerState.RemainingSeconds--
    }
    
    Write-Progress -Activity "Sleep Timer Core" -Completed
    
    # Complete or Cancel
    if ($script:TimerState.Active) {
        # Timer completed naturally
        Complete-TimerEngine
    }
}

function Complete-TimerEngine {
    $script:TimerState.Active = $false
    $script:IsRunning = $false
    
    # Notify modules
    foreach ($mod in $script:Modules) {
        if ($mod.OnComplete) {
            & $mod.OnComplete -Action $script:TimerState.Action
        }
    }
    
    Publish-TimerEvent -EventType "Completed" -Data @{
        Action = $script:TimerState.Action
        TotalSeconds = $script:TimerState.TotalSeconds
    }
    
    # Execute action
    Write-Host "⏱ Timer complete - Executing: $($script:TimerState.Action)" -ForegroundColor Green
    Invoke-TimerAction -ActionName $script:TimerState.Action
}

function Stop-TimerEngine {
    $script:TimerState.Active = $false
    $script:IsRunning = $false
    
    # Notify modules
    foreach ($mod in $script:Modules) {
        if ($mod.OnCancel) {
            & $mod.OnCancel -RemainingSeconds $script:TimerState.RemainingSeconds
        }
    }
    
    Publish-TimerEvent -EventType "Cancelled" -Data @{
        RemainingSeconds = $script:TimerState.RemainingSeconds
        ElapsedSeconds = ($script:TimerState.TotalSeconds - $script:TimerState.RemainingSeconds)
    }
    
    Write-Host "⏱ Timer cancelled" -ForegroundColor Yellow
}

function Invoke-TimerAction {
    param([string]$ActionName)
    
    switch ($ActionName) {
        "Shutdown"  { Stop-Computer -Force }
        "Restart"   { Restart-Computer -Force }
        "Sleep"     { Add-Type '[DllImport("powrprof.dll")]public static extern bool SetSuspendState(bool h, bool f, bool d);' -Name Power -Namespace Sys; [Sys.Power]::SetSuspendState($false, $true, $false) }
        "Hibernate" { Add-Type '[DllImport("powrprof.dll")]public static extern bool SetSuspendState(bool h, bool f, bool d);' -Name Power -Namespace Sys; [Sys.Power]::SetSuspendState($true, $true, $false) }
        "Lock"      { Add-Type '[DllImport("user32.dll")]public static extern bool LockWorkStation();' -Name Win32 -Namespace Sys; [Sys.Win32]::LockWorkStation() }
        "Logoff"    { logoff }
    }
}

function Format-TimeSpan {
    param([int]$TotalSeconds)
    $hrs = [math]::Floor($TotalSeconds / 3600)
    $mins = [math]::Floor(($TotalSeconds % 3600) / 60)
    $secs = $TotalSeconds % 60
    return "{0:D2}:{1:D2}:{2:D2}" -f $hrs, $mins, $secs
}

# ============================================
# API FUNCTIONS (For External Use)
# ============================================
function Get-TimerStatus {
    return $script:TimerState
}

function Get-RemainingTime {
    return $script:TimerState.RemainingSeconds
}

function Get-TimerPercent {
    if ($script:TimerState.TotalSeconds -eq 0) { return 0 }
    $elapsed = $script:TimerState.TotalSeconds - $script:TimerState.RemainingSeconds
    return [math]::Round(($elapsed / $script:TimerState.TotalSeconds) * 100)
}

# Export for module use
Export-ModuleMember -Function @(
    'Start-TimerEngine',
    'Stop-TimerEngine',
    'Register-TimerModule',
    'Get-TimerStatus',
    'Get-RemainingTime',
    'Get-TimerPercent',
    'Publish-TimerEvent'
)

# ============================================
# STANDALONE EXECUTION
# ============================================
if ($MyInvocation.InvocationName -ne ".") {
    # Running as standalone script
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     Sleep Timer Core - Modular Engine  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    
    if ($EventMode) {
        Write-Host "Mode: Event output (for external apps)" -ForegroundColor Yellow
    }
    
    Write-Host "Duration: $Minutes minutes" -ForegroundColor White
    Write-Host "Action: $Action" -ForegroundColor White
    Write-Host "Event path: $script:EventPath" -ForegroundColor Gray
    Write-Host "Press Ctrl+C to cancel`n" -ForegroundColor Yellow
    
    try {
        Start-TimerEngine -DurationSeconds ($Minutes * 60) -TimerAction $Action
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        Stop-TimerEngine
    }
}
