#Requires -Version 5.1
<#
.SYNOPSIS
    RGB Keyboard/Mouse Thermal Monitor - Visual CPU/GPU Temperature Display
.DESCRIPTION
    Maps CPU/GPU temperatures to customizable RGB zones on keyboard and mouse.
    Different keyboard areas show different temps with color gradients.
    Cool=blue, Warm=yellow/green, Hot=orange/red, Critical=flashing red.
#>

# ============================================
# TEMPERATURE MONITORING
# ============================================
function Get-CpuTemperature {
    try {
        # Try WMI first (most reliable on modern systems)
        $wmi = Get-WmiObject -Namespace "root\wmi" -Class "MSAcpi_ThermalZoneTemperature" -ErrorAction Stop
        if ($wmi) {
            $temp = ($wmi.CurrentTemperature / 10) - 273.15  # Convert from tenths of Kelvin to Celsius
            return [math]::Round($temp, 1)
        }
    }
    catch {
        # Fallback to performance counters
        try {
            $counter = Get-Counter "\Thermal Zone Information\*\Temperature" -ErrorAction Stop
            if ($counter) {
                return [math]::Round(($counter.CounterSamples[0].CookedValue / 10) - 273.15, 1)
            }
        }
        catch {
            return $null
        }
    }
    return $null
}

function Get-GpuTemperature {
    try {
        # NVIDIA via nvidia-smi (if installed)
        $nvidiaSmi = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue
        if ($nvidiaSmi) {
            $output = & nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>$null
            if ($output -match "^\d+") {
                return [int]$output
            }
        }
        
        # AMD via WMI (if AMD drivers support it)
        $amd = Get-WmiObject -Namespace "root\cimv2" -Class "Win32_VideoController" | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }
        if ($amd) {
            # AMD temperature often not exposed via WMI, return null
            return $null
        }
    }
    catch {
        return $null
    }
    return $null
}

function Get-SystemTemperatures {
    return @{
        CPU = Get-CpuTemperature
        GPU = Get-GpuTemperature
        Timestamp = Get-Date
    }
}

# ============================================
# COLOR CALCULATIONS
# ============================================
function Get-TemperatureColor {
    param(
        [int]$Temp,
        [int]$Min = 30,
        [int]$Max = 90
    )
    
    # Normalize to 0-1 range
    $normalized = [math]::Max(0, [math]::Min(1, ($Temp - $Min) / ($Max - $Min)))
    
    # Color gradient: Blue(30°C) → Cyan → Green → Yellow → Red(90°C)
    $r = 0
    $g = 0
    $b = 0
    
    if ($normalized -lt 0.25) {
        # Blue to Cyan (0-25%)
        $factor = $normalized * 4
        $r = 0
        $g = [int](255 * $factor)
        $b = 255
    }
    elseif ($normalized -lt 0.5) {
        # Cyan to Green (25-50%)
        $factor = ($normalized - 0.25) * 4
        $r = 0
        $g = 255
        $b = [int](255 * (1 - $factor))
    }
    elseif ($normalized -lt 0.75) {
        # Green to Yellow (50-75%)
        $factor = ($normalized - 0.5) * 4
        $r = [int](255 * $factor)
        $g = 255
        $b = 0
    }
    else {
        # Yellow to Red (75-100%)
        $factor = ($normalized - 0.75) * 4
        $r = 255
        $g = [int](255 * (1 - $factor))
        $b = 0
    }
    
    return @{ R = $r; G = $g; B = $b }
}

function Get-CriticalPulseColor {
    # Pulsing red for critical temps (>85°C)
    $pulse = [math]::Sin((Get-Date).Second * 0.5) * 50 + 205
    return @{ R = [int]$pulse; G = 0; B = 0 }
}

# ============================================
# CUSTOMIZABLE RGB ZONES
# ============================================
$script:RGBZones = @{
    # Predefined zones (keyboard areas)
    Zones = @{
        # Left side = CPU temperature
        CPU_Left = @{
            Name = "CPU (Left Side)"
            Keys = @(  # Function keys F1-F4 + number row 1-4 + Q-R + A-F + Z-V
                @(0,0), @(0,1), @(0,2), @(0,3),  # F1-F4
                @(1,0), @(1,1), @(1,2), @(1,3),  # 1-4
                @(2,0), @(2,1), @(2,2), @(2,3),  # Q,W,E,R
                @(3,0), @(3,1), @(3,2), @(3,3), @(3,4), @(3,5),  # A-F
                @(4,0), @(4,1), @(4,2), @(4,3), @(4,4)  # Z-V
            )
            Sensor = "CPU"
            MinTemp = 30
            MaxTemp = 90
            Active = $true
        }
        
        # Right side = GPU temperature
        GPU_Right = @{
            Name = "GPU (Right Side)"
            Keys = @(
                @(0,9), @(0,10), @(0,11), @(0,12),  # F10-F12
                @(1,9), @(1,10), @(1,11), @(1,12), @(1,13),  # 9-0, -, =
                @(2,7), @(2,8), @(2,9), @(2,10), @(2,11), @(2,12),  # U,P,[,]
                @(3,7), @(3,8), @(3,9), @(3,10), @(3,11), @(3,12),  # H,L,;,'
                @(4,6), @(4,7), @(4,8), @(4,9), @(4,10), @(4,11)  # B,M,.,/
            )
            Sensor = "GPU"
            MinTemp = 30
            MaxTemp = 85
            Active = $true
        }
        
        # Middle = Average/Overall (optional)
        Center_Status = @{
            Name = "System Status (Center)"
            Keys = @(
                @(0,4), @(0,5), @(0,6), @(0,7), @(0,8),  # F5-F9
                @(2,4), @(2,5), @(2,6),  # T,Y
                @(3,6),  # G
                @(4,5)   # B
            )
            Sensor = "Average"
            MinTemp = 30
            MaxTemp = 85
            Active = $true
        }
        
        # Mouse = Highest temperature
        Mouse = @{
            Name = "Mouse (Highest Temp)"
            Keys = @("MOUSE")
            Sensor = "Max"
            MinTemp = 30
            MaxTemp = 90
            Active = $true
        }
    }
}

# ============================================
# OPENRGB THERMAL IMPLEMENTATION
# ============================================
$script:OpenRGBConnection = $null
$script:RGBDevices = @()

function Connect-OpenRGBThermal {
    param([string]$Server = "127.0.0.1", [int]$Port = 6742)
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($Server, $Port)
        $stream = $client.GetStream()
        
        # Handshake
        $stream.Write([byte[]]@(0x01, 0x00, 0x00, 0x00), 0, 4)
        $response = New-Object byte[] 4
        $stream.Read($response, 0, 4) | Out-Null
        
        $script:OpenRGBConnection = @{
            Client = $client
            Stream = $stream
            Connected = $true
        }
        
        # Get device count
        $stream.Write([byte[]]@(0x02), 0, 1)
        $countBytes = New-Object byte[] 4
        $stream.Read($countBytes, 0, 4) | Out-Null
        $deviceCount = [BitConverter]::ToInt32($countBytes, 0)
        
        Write-Host "✓ OpenRGB Connected: $deviceCount device(s)" -ForegroundColor Green
        return $deviceCount
    }
    catch {
        Write-Host "⚠ OpenRGB not available (Install from openrgb.org)" -ForegroundColor Yellow
        return 0
    }
}

function Set-ThermalRGBKeyboard {
    param([hashtable]$Temperatures)
    if (-not $script:OpenRGBConnection -or -not $script:OpenRGBConnection.Connected) { return }
    
    try {
        $stream = $script:OpenRGBConnection.Stream
        
        # Get device info
        $stream.Write([byte[]]@(0x03, 0x00, 0x00, 0x00, 0x00), 0, 5)
        $ledCountBytes = New-Object byte[] 4
        $stream.Read($ledCountBytes, 0, 4) | Out-Null
        $ledCount = [BitConverter]::ToInt32($ledCountBytes, 0)
        
        if ($ledCount -eq 0) { return }
        
        # Calculate colors for each zone
        $zoneColors = @{}
        
        foreach ($zoneName in $script:RGBZones.Zones.Keys) {
            $zone = $script:RGBZones.Zones[$zoneName]
            if (-not $zone.Active) { continue }
            
            # Get temperature for this zone
            $temp = switch ($zone.Sensor) {
                "CPU" { $Temperatures.CPU }
                "GPU" { $Temperatures.GPU }
                "Average" { if ($Temperatures.CPU -and $Temperatures.GPU) { ($Temperatures.CPU + $Temperatures.GPU) / 2 } else { $Temperatures.CPU } }
                "Max" { [math]::Max($Temperatures.CPU, $Temperatures.GPU) }
                default { $Temperatures.CPU }
            }
            
            if ($temp) {
                # Critical temp pulsing
                if ($temp -gt 85) {
                    $color = Get-CriticalPulseColor
                }
                else {
                    $color = Get-TemperatureColor -Temp $temp -Min $zone.MinTemp -Max $zone.MaxTemp
                }
                $zoneColors[$zoneName] = $color
            }
        }
        
        # Build LED data
        $stream.Write([byte[]]@(0x04, 0x00, 0x00, 0x00, 0x00), 0, 5)
        $stream.Write([BitConverter]::GetBytes([int]$ledCount), 0, 4)
        
        # Map keys to colors (simplified - assumes sequential LED mapping)
        for ($i = 0; $i -lt $ledCount; $i++) {
            $assigned = $false
            
            # Find which zone this LED belongs to
            foreach ($zoneName in $zoneColors.Keys) {
                $zone = $script:RGBZones.Zones[$zoneName]
                # Check if this LED index maps to a key in this zone
                # (Simplified - real implementation needs proper key-to-LED mapping)
                if (($i % 6) -lt 3) {
                    # Left side = CPU
                    $c = $zoneColors["CPU_Left"]
                    $stream.Write([byte[]]@([byte]$c.R, [byte]$c.G, [byte]$c.B), 0, 3)
                    $assigned = $true
                    break
                }
                elseif (($i % 6) -ge 3) {
                    # Right side = GPU
                    $c = $zoneColors["GPU_Right"]
                    $stream.Write([byte[]]@([byte]$c.R, [byte]$c.G, [byte]$c.B), 0, 3)
                    $assigned = $true
                    break
                }
            }
            
            if (-not $assigned) {
                $stream.Write([byte[]]@(20, 20, 20), 0, 3)  # Dim default
            }
        }
    }
    catch {
        # Silent fail
    }
}

# ============================================
# CONSOLE THERMAL DISPLAY (No RGB fallback)
# ============================================
function Show-ThermalConsole {
    param([hashtable]$Temperatures)
    
    $cpuTemp = $Temperatures.CPU
    $gpuTemp = $Temperatures.GPU
    
    Write-Host "`n🌡 THERMAL MONITOR" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    if ($cpuTemp) {
        $cpuColor = if ($cpuTemp -gt 80) { "Red" } elseif ($cpuTemp -gt 65) { "Yellow" } else { "Green" }
        $cpuBar = "█" * [math]::Min(20, [math]::Floor($cpuTemp / 5))
        Write-Host "CPU: $cpuTemp°C " -NoNewline -ForegroundColor White
        Write-Host $cpuBar -NoNewline -ForegroundColor $cpuColor
        Write-Host " (Zone: Left Side)" -ForegroundColor Gray
    }
    
    if ($gpuTemp) {
        $gpuColor = if ($gpuTemp -gt 80) { "Red" } elseif ($gpuTemp -gt 65) { "Yellow" } else { "Green" }
        $gpuBar = "█" * [math]::Min(20, [math]::Floor($gpuTemp / 5))
        Write-Host "GPU: $gpuTemp°C " -NoNewline -ForegroundColor White
        Write-Host $gpuBar -NoNewline -ForegroundColor $gpuColor
        Write-Host " (Zone: Right Side)" -ForegroundColor Gray
    }
    
    Write-Host "━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

# ============================================
# THERMAL MONITOR CONTROLLER
# ============================================
function Start-ThermalMonitor {
    param(
        [int]$UpdateIntervalSeconds = 2,
        [int]$DurationMinutes = 0  # 0 = run until stopped
    )
    
    Write-Host "`n🌡 RGB THERMAL MONITOR" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host "Left Side:  CPU Temperature" -ForegroundColor White
    Write-Host "Right Side: GPU Temperature" -ForegroundColor White
    Write-Host "Center:     System Status" -ForegroundColor White
    Write-Host "Mouse:      Highest Temp" -ForegroundColor White
    Write-Host ""
    Write-Host "Colors: Blue(30°C) → Green → Yellow → Red(90°C+)" -ForegroundColor Gray
    Write-Host "Critical: Pulsing Red >85°C" -ForegroundColor Gray
    Write-Host ""
    
    # Connect to RGB
    $deviceCount = Connect-OpenRGBThermal
    $useRGB = $deviceCount -gt 0
    
    if (-not $useRGB) {
        Write-Host "⚠ Running in console-only mode (no RGB keyboard detected)" -ForegroundColor Yellow
    }
    
    $startTime = Get-Date
    $running = $true
    
    Write-Host "Press Ctrl+C to stop monitoring`n" -ForegroundColor Yellow
    
    while ($running) {
        # Get temperatures
        $temps = Get-SystemTemperatures
        
        # Display in console
        Show-ThermalConsole -Temperatures $temps
        
        # Update RGB
        if ($useRGB) {
            Set-ThermalRGBKeyboard -Temperatures $temps
        }
        
        # Check duration
        if ($DurationMinutes -gt 0) {
            $elapsed = (Get-Date) - $startTime
            if ($elapsed.TotalMinutes -ge $DurationMinutes) {
                $running = $false
            }
        }
        
        if ($running) {
            Start-Sleep -Seconds $UpdateIntervalSeconds
            # Clear console for next update
            Write-Host "`r`n`r`n`r`n`r`n`r`n`r`n" -NoNewline
        }
    }
    
    # Cleanup
    if ($useRGB -and $script:OpenRGBConnection) {
        $script:OpenRGBConnection.Client.Close()
    }
    
    Write-Host "`n✓ Thermal monitor stopped" -ForegroundColor Green
}

# ============================================
# ZONE CONFIGURATION EDITOR
# ============================================
function Edit-ThermalZones {
    Write-Host "`n🔧 THERMAL ZONE CONFIGURATION" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    
    $index = 1
    $zoneList = @($script:RGBZones.Zones.Keys)
    
    foreach ($zoneName in $zoneList) {
        $zone = $script:RGBZones.Zones[$zoneName]
        $status = if ($zone.Active) { "✓ ON" } else { "✗ OFF" }
        Write-Host "$index. $($zone.Name) [$status]" -ForegroundColor White
        Write-Host "   Sensor: $($zone.Sensor) | Range: $($zone.MinTemp)-$($zone.MaxTemp)°C" -ForegroundColor Gray
        Write-Host "   Keys: $($zone.Keys.Count) keys assigned`n" -ForegroundColor DarkGray
        $index++
    }
    
    Write-Host "Commands: (1-$($zoneList.Count)) toggle zone | S save | Q quit" -ForegroundColor Yellow
    
    do {
        $choice = Read-Host "Select"
        
        if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $zoneList.Count) {
            $selectedZone = $zoneList[[int]$choice - 1]
            $script:RGBZones.Zones[$selectedZone].Active = -not $script:RGBZones.Zones[$selectedZone].Active
            $newStatus = if ($script:RGBZones.Zones[$selectedZone].Active) { "ON" } else { "OFF" }
            Write-Host "✓ $($script:RGBZones.Zones[$selectedZone].Name) is now $newStatus" -ForegroundColor Green
        }
        elseif ($choice -eq "S") {
            # Save configuration (export to JSON)
            $configPath = Join-Path $env:LOCALAPPDATA "SleepTimer\thermal-zones.json"
            $script:RGBZones | ConvertTo-Json -Depth 5 | Set-Content $configPath
            Write-Host "✓ Configuration saved to $configPath" -ForegroundColor Green
        }
    } while ($choice -ne "Q")
}

# ============================================
# EXPORT FOR SLEEP TIMER PRO INTEGRATION
# ============================================
Export-ModuleMember -Function Start-ThermalMonitor, Edit-ThermalZones, Get-SystemTemperatures

# Demo if run directly
if ($MyInvocation.InvocationName -eq "&" -or $MyInvocation.Line -eq "" -or $MyInvocation.MyCommand.Name -eq "RGB-ThermalMonitor.ps1") {
    Start-ThermalMonitor -UpdateIntervalSeconds 2 -DurationMinutes 0
}
