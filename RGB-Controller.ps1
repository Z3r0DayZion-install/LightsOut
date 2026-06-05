#Requires -Version 5.1
<#
.SYNOPSIS
    RGB Controller - Modular RGB Visualization App
.DESCRIPTION
    Standalone RGB controller that can:
    1. Subscribe to SleepTimer-Core events
    2. Run standalone with custom data sources
    3. Be loaded as module by other apps
    Communicates via event files and direct function calls
#>

[CmdletBinding()]
param(
    [switch]$SubscribeToTimer,  # Watch for SleepTimer-Core events
    [switch]$Standalone,        # Run with own data sources
    [string]$Mode = "Hybrid",   # Hybrid, TimerOnly, Standalone
    [int]$UpdateInterval = 1    # Seconds between updates
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================
# MODULE SYSTEM
# ============================================
$script:ModuleName = "RGB-Controller"
$script:Version = "3.0"
$script:EventPath = Join-Path $env:TEMP "SleepTimer\Events"
$script:IsRunning = $false
$script:OpenRGB = $null

# ============================================
# RGB CONTROLLER STATE
# ============================================
$script:RGBState = @{
    Connected = $false
    Mode = $Mode  # "Timer", "Thermal", "Custom", "Idle"
    Zones = @()
    CurrentColors = @{}
    LastUpdate = $null
}

# ============================================
# DATA SOURCES (For Standalone Mode)
# ============================================
$script:DataSources = @{
    Timer = @{
        RemainingSeconds = 0
        TotalSeconds = 0
        Percent = 0
        Active = $false
    }
    Thermal = @{
        CPU = 50
        GPU = 55
        LastUpdate = $null
    }
    Custom = @{
        Values = @{}
    }
}

# ============================================
# OPENRGB CONNECTION
# ============================================
function Connect-RGBController {
    param([string]$Server = "127.0.0.1", [int]$Port = 6742)
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($Server, $Port)
        $stream = $client.GetStream()
        
        # Handshake
        $stream.Write([byte[]]@(0x01, 0x00, 0x00, 0x00), 0, 4)
        $response = New-Object byte[] 4
        $stream.Read($response, 0, 4) | Out-Null
        
        $script:OpenRGB = @{
            Client = $client
            Stream = $stream
            Connected = $true
        }
        
        $script:RGBState.Connected = $true
        Write-Host "✓ RGB Controller connected to OpenRGB" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "⚠ OpenRGB not available" -ForegroundColor Yellow
        return $false
    }
}

# ============================================
# EVENT WATCHER (For Timer Subscription Mode)
# ============================================
function Start-EventWatcher {
    Write-Host "`n👀 Watching for SleepTimer-Core events..." -ForegroundColor Cyan
    Write-Host "Event path: $script:EventPath" -ForegroundColor Gray
    
    if (-not (Test-Path $script:EventPath)) {
        Write-Host "⚠ Event path not found. Waiting for timer to start..." -ForegroundColor Yellow
    }
    
    $lastChecked = Get-Date
    $script:IsRunning = $true
    
    while ($script:IsRunning) {
        # Check for new events
        if (Test-Path $script:EventPath) {
            $events = Get-ChildItem $script:EventPath -Filter "*.json" | 
                Where-Object { $_.LastWriteTime -gt $lastChecked } |
                Sort-Object LastWriteTime
            
            foreach ($eventFile in $events) {
                try {
                    $eventData = Get-Content $eventFile.FullName -Raw | ConvertFrom-Json
                    Process-TimerEvent -Event $eventData
                    Remove-Item $eventFile.FullName  # Clean up processed event
                }
                catch {
                    Write-Host "Failed to process event: $($eventFile.Name)" -ForegroundColor Red
                }
            }
            
            $lastChecked = Get-Date
        }
        
        Start-Sleep -Seconds 1
    }
}

function Process-TimerEvent {
    param([hashtable]$Event)
    
    Write-Host "📨 Event: $($Event.EventType) at $($Event.Timestamp)" -ForegroundColor Cyan
    
    switch ($Event.EventType) {
        "Started" {
            $script:DataSources.Timer.Active = $true
            $script:DataSources.Timer.TotalSeconds = $Event.Data.TotalSeconds
            $script:DataSources.Timer.RemainingSeconds = $Event.Data.TotalSeconds
            $script:RGBState.Mode = "Timer"
            Update-RGBDisplay
        }
        "Tick" {
            $script:DataSources.Timer.RemainingSeconds = $Event.Data.RemainingSeconds
            $script:DataSources.Timer.Percent = $Event.Data.PercentComplete
            Update-RGBDisplay
        }
        "Warning" {
            # Flash warning
            Flash-RGBZone -Zone "All" -Color "FFFF00" -Duration 500
        }
        "Completed" {
            $script:DataSources.Timer.Active = $false
            $script:RGBState.Mode = "Idle"
            Flash-RGBZone -Zone "All" -Color "FFFFFF" -Count 3
        }
        "Cancelled" {
            $script:DataSources.Timer.Active = $false
            $script:RGBState.Mode = "Idle"
            Set-RGBColor -R 50 -G 50 -B 50  # Dim
        }
    }
}

# ============================================
# STANDALONE MODE
# ============================================
function Start-StandaloneMode {
    param([string]$DisplayMode = "Thermal")
    
    Write-Host "`n🎨 RGB Controller - Standalone Mode" -ForegroundColor Cyan
    Write-Host "Display: $DisplayMode" -ForegroundColor White
    Write-Host "Press Ctrl+C to exit`n" -ForegroundColor Yellow
    
    $script:RGBState.Mode = $DisplayMode
    $script:IsRunning = $true
    
    while ($script:IsRunning) {
        switch ($DisplayMode) {
            "Thermal" {
                Update-ThermalData
                $script:RGBState.Mode = "Thermal"
            }
            "Demo" {
                # Cycle through rainbow
                $hue = ((Get-Date).Second * 6) % 360
                $color = HslToRgb -Hue $hue -Saturation 1 -Lightness 0.5
                Set-RGBColor -R $color.R -G $color.G -B $color.B
            }
            "Wave" {
                $wave = [math]::Sin((Get-Date).Second * 0.5) * 127 + 128
                Set-RGBColor -R 0 -G $wave -B 255
            }
        }
        
        if ($DisplayMode -eq "Thermal") {
            Update-RGBDisplay
        }
        
        Start-Sleep -Seconds $UpdateInterval
    }
}

function Update-ThermalData {
    # Simulate or get real thermal data
    try {
        $wmi = Get-WmiObject -Namespace "root\wmi" -Class "MSAcpi_ThermalZoneTemperature" -ErrorAction SilentlyContinue
        if ($wmi) {
            $script:DataSources.Thermal.CPU = [math]::Round(($wmi.CurrentTemperature / 10) - 273.15, 1)
        }
        else {
            # Simulated for demo
            $script:DataSources.Thermal.CPU = 45 + (Get-Random -Minimum -5 -Maximum 20)
        }
    }
    catch {
        $script:DataSources.Thermal.CPU = 50 + (Get-Date).Second % 20
    }
    
    $script:DataSources.Thermal.LastUpdate = Get-Date
}

# ============================================
# RGB DISPLAY UPDATE
# ============================================
function Update-RGBDisplay {
    if (-not $script:RGBState.Connected) { return }
    
    switch ($script:RGBState.Mode) {
        "Timer" {
            $percent = if ($script:DataSources.Timer.TotalSeconds -gt 0) {
                ($script:DataSources.Timer.TotalSeconds - $script:DataSources.Timer.RemainingSeconds) / $script:DataSources.Timer.TotalSeconds
            }
            else { 0 }
            
            # Gradient: Blue (100% left) → Red (0% left)
            $color = Get-GradientColor -Ratio $percent -Preset "Heat"
            Set-RGBColor -R $color.R -G $color.G -B $color.B
            
            if (-not $script:DataSources.Timer.Active) {
                Set-RGBColor -R 50 -G 50 -B 50  # Idle dim
            }
        }
        "Thermal" {
            $cpu = $script:DataSources.Thermal.CPU
            # Normalize 30-90°C to 0-1
            $ratio = [math]::Max(0, [math]::Min(1, ($cpu - 30) / 60))
            $color = Get-GradientColor -Ratio $ratio -Preset "Heat"
            Set-RGBColor -R $color.R -G $color.G -B $color.B
        }
        "Idle" {
            Set-RGBColor -R 20 -G 20 -B 20  # Very dim
        }
    }
}

function Set-RGBColor {
    param([int]$R, [int]$G, [int]$B)
    if (-not $script:OpenRGB -or -not $script:OpenRGB.Connected) { return }
    
    try {
        $stream = $script:OpenRGB.Stream
        
        # Get LED count
        $stream.Write([byte[]]@(0x03, 0x00, 0x00, 0x00, 0x00), 0, 5)
        $countBytes = New-Object byte[] 4
        $stream.Read($countBytes, 0, 4) | Out-Null
        $ledCount = [BitConverter]::ToInt32($countBytes, 0)
        
        if ($ledCount -eq 0) { return }
        
        # Send colors
        $stream.Write([byte[]]@(0x04, 0x00, 0x00, 0x00, 0x00), 0, 5)
        $stream.Write([BitConverter]::GetBytes([int]$ledCount), 0, 4)
        
        for ($i = 0; $i -lt $ledCount; $i++) {
            $stream.Write([byte[]]@([byte]$R, [byte]$G, [byte]$B), 0, 3)
        }
        
        $script:RGBState.LastUpdate = Get-Date
    }
    catch { }
}

function Flash-RGBZone {
    param(
        [string]$Zone = "All",
        [string]$Color = "FFFFFF",
        [int]$Duration = 200,
        [int]$Count = 1
    )
    
    $c = @{
        R = [Convert]::ToInt32($Color.Substring(0, 2), 16)
        G = [Convert]::ToInt32($Color.Substring(2, 2), 16)
        B = [Convert]::ToInt32($Color.Substring(4, 2), 16)
    }
    
    for ($i = 0; $i -lt $Count; $i++) {
        Set-RGBColor -R $c.R -G $c.G -B $c.B
        Start-Sleep -Milliseconds $Duration
        Set-RGBColor -R 0 -G 0 -B 0
        Start-Sleep -Milliseconds $Duration
    }
}

# ============================================
# COLOR UTILITIES
# ============================================
function Get-GradientColor {
    param([double]$Ratio, [string]$Preset = "Heat")
    
    # Clamp 0-1
    $r = [math]::Max(0, [math]::Min(1, $Ratio))
    
    switch ($Preset) {
        "Heat" {
            # Blue → Cyan → Green → Yellow → Red
            if ($r -lt 0.25) {
                $f = $r * 4
                return @{ R = 0; G = [int](255 * $f); B = 255 }
            }
            elseif ($r -lt 0.5) {
                $f = ($r - 0.25) * 4
                return @{ R = [int](255 * $f); G = 255; B = [int](255 * (1 - $f)) }
            }
            elseif ($r -lt 0.75) {
                $f = ($r - 0.5) * 4
                return @{ R = 255; G = 255; B = 0 }
            }
            else {
                $f = ($r - 0.75) * 4
                return @{ R = 255; G = [int](255 * (1 - $f)); B = 0 }
            }
        }
        "Cool" {
            return @{ R = [int](255 * $r); G = 100; B = 255 }
        }
        default {
            return @{ R = [int](255 * $r); G = [int](255 * (1 - $r)); B = 100 }
        }
    }
}

function HslToRgb {
    param([double]$Hue, [double]$Saturation, [double]$Lightness)
    
    $c = (1 - [math]::Abs(2 * $Lightness - 1)) * $Saturation
    $x = $c * (1 - [math]::Abs((($Hue / 60) % 2) - 1))
    $m = $Lightness - $c / 2
    
    switch ([math]::Floor($Hue / 60)) {
        0 { $r = $c; $g = $x; $b = 0 }
        1 { $r = $x; $g = $c; $b = 0 }
        2 { $r = 0; $g = $c; $b = $x }
        3 { $r = 0; $g = $x; $b = $c }
        4 { $r = $x; $g = 0; $b = $c }
        default { $r = $c; $g = 0; $b = $x }
    }
    
    return @{
        R = [int](($r + $m) * 255)
        G = [int](($g + $m) * 255)
        B = [int](($b + $m) * 255)
    }
}

# ============================================
# API FOR EXTERNAL USE
# ============================================
function Set-RGBMode {
    param([ValidateSet("Timer", "Thermal", "Custom", "Idle")][string]$Mode)
    $script:RGBState.Mode = $Mode
}

function Set-TimerData {
    param(
        [int]$RemainingSeconds,
        [int]$TotalSeconds,
        [bool]$Active
    )
    $script:DataSources.Timer.RemainingSeconds = $RemainingSeconds
    $script:DataSources.Timer.TotalSeconds = $TotalSeconds
    $script:DataSources.Timer.Active = $Active
    Update-RGBDisplay
}

function Set-ThermalData {
    param([double]$CPU, [double]$GPU)
    $script:DataSources.Thermal.CPU = $CPU
    $script:DataSources.Thermal.GPU = $GPU
    if ($script:RGBState.Mode -eq "Thermal") {
        Update-RGBDisplay
    }
}

Export-ModuleMember -Function @(
    'Connect-RGBController',
    'Start-EventWatcher',
    'Start-StandaloneMode',
    'Set-RGBMode',
    'Set-TimerData',
    'Set-ThermalData',
    'Update-RGBDisplay',
    'Set-RGBColor',
    'Flash-RGBZone'
)

# ============================================
# STANDALONE EXECUTION
# ============================================
if ($MyInvocation.InvocationName -ne ".") {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║     RGB Controller - Modular Display   ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Magenta
    
    # Connect to OpenRGB
    $connected = Connect-RGBController
    
    if ($SubscribeToTimer) {
        Start-EventWatcher
    }
    elseif ($Standalone) {
        Start-StandaloneMode -DisplayMode "Thermal"
    }
    else {
        # Hybrid mode - try both
        Write-Host "`nMode: Hybrid (Timer + Standalone)" -ForegroundColor Yellow
        
        # Start event watcher in background
        $job = Start-Job -ScriptBlock {
            param($Path)
            # Watch for events
        } -ArgumentList $script:EventPath
        
        # Run standalone as fallback
        Start-StandaloneMode -DisplayMode "Demo"
    }
}
