#Requires -Version 5.1
<#
.SYNOPSIS
    RGB Custom Zone Mapper - Assign any keys to any metric
.DESCRIPTION
    Flexible RGB zone system where you define which keys show what:
    - Arrow keys = CPU temp
    - QWERTY keys = Timer progress
    - Number row = GPU temp
    - etc.
#>

# ============================================
# CUSTOMIZABLE ZONE DEFINITIONS
# ============================================
# Define your own zones here! Each zone has:
# - Name: What to display
# - Keys: Which keys (row, column) on keyboard
# - Type: What data to show (CPU, GPU, Timer, Custom)
# - ColorRange: Min/max temp or percentage for colors

$script:CustomZones = @{
    # EXAMPLE 1: Arrow Keys = CPU Temperature
    ArrowKeys_CPU = @{
        Name = "CPU Temp (Arrows)"
        Description = "Up/Down/Left/Right show CPU heat"
        Keys = @(
            @(4, 14),  # Left Arrow
            @(4, 15),  # Down Arrow  
            @(4, 16),  # Right Arrow
            @(3, 16)   # Up Arrow
        )
        Type = "Temperature"
        Sensor = "CPU"
        MinValue = 30    # 30°C = Blue
        MaxValue = 90    # 90°C = Red
        Active = $true
    }
    
    # EXAMPLE 2: QWERTY Row = Timer Progress
    QWERTY_Timer = @{
        Name = "Timer (QWERTY)"
        Description = "Q-W-E-R-T-Y shows countdown progress"
        Keys = @(
            @(2, 0),   # Q
            @(2, 1),   # W
            @(2, 2),   # E
            @(2, 3),   # R
            @(2, 4),   # T
            @(2, 5)    # Y
        )
        Type = "Progress"
        Direction = "Shrink"  # Keys turn off as timer runs down
        MinValue = 0
        MaxValue = 100   # Percentage
        Active = $true
    }
    
    # EXAMPLE 3: Number Row = GPU Temperature
    Numbers_GPU = @{
        Name = "GPU Temp (1-0)"
        Description = "Number keys show GPU heat level"
        Keys = @(
            @(1, 0),   # 1
            @(1, 1),   # 2
            @(1, 2),   # 3
            @(1, 3),   # 4
            @(1, 4),   # 5
            @(1, 5),   # 6
            @(1, 6),   # 7
            @(1, 7),   # 8
            @(1, 8),   # 9
            @(1, 9)    # 0
        )
        Type = "Temperature"
        Sensor = "GPU"
        MinValue = 30
        MaxValue = 85
        Active = $true
    }
    
    # EXAMPLE 4: Function Keys = System Load/Average
    FKeys_Average = @{
        Name = "System (F1-F12)"
        Description = "F-keys show average system temp"
        Keys = @(
            @(0, 0),   # F1
            @(0, 1),   # F2
            @(0, 2),   # F3
            @(0, 3),   # F4
            @(0, 4),   # F5
            @(0, 5),   # F6
            @(0, 6),   # F7
            @(0, 7),   # F8
            @(0, 8),   # F9
            @(0, 9),   # F10
            @(0, 10),  # F11
            @(0, 11)   # F12
        )
        Type = "Temperature"
        Sensor = "Average"
        MinValue = 30
        MaxValue = 85
        Active = $false  # Disabled by default
    }
    
    # EXAMPLE 5: ASDF = Memory Usage
    ASDF_Memory = @{
        Name = "RAM Usage (ASDF)"
        Description = "A-S-D-F show memory percentage"
        Keys = @(
            @(3, 0),   # A
            @(3, 1),   # S
            @(3, 2),   # D
            @(3, 3)    # F
        )
        Type = "Percentage"
        DataSource = "Memory"
        MinValue = 0
        MaxValue = 100
        Active = $false
    }
    
    # EXAMPLE 6: ZXCV = Network Activity
    ZXCV_Network = @{
        Name = "Network (ZXCV)"
        Description = "Z-X-C-V show network activity"
        Keys = @(
            @(4, 0),   # Z
            @(4, 1),   # X
            @(4, 2),   # C
            @(4, 3)    # V
        )
        Type = "Activity"
        DataSource = "Network"
        Active = $false
    }
    
    # EXAMPLE 7: Mouse LEDs = Highest Temp Alert
    Mouse_Alert = @{
        Name = "Mouse (Alert)"
        Description = "Mouse shows highest temp, pulses if critical"
        Keys = @("MOUSE")
        Type = "Temperature"
        Sensor = "Max"  # CPU or GPU, whichever is hotter
        MinValue = 30
        MaxValue = 90
        Active = $true
    }
}

# ============================================
# KEYBOARD LAYOUT REFERENCE
# ============================================
# Standard 6-row layout coordinates:
# Row 0: Function keys (F1-F12)
# Row 1: Number row (1-0, -, =)
# Row 2: QWERTY row (Q-P, [, ])
# Row 3: ASDF row (A-L, ;, ')
# Row 4: ZXCV row (Z-M, ,, ., /) + Arrows
# Row 5: Bottom row (Ctrl, Win, Alt, Space, etc.)

$script:KeyReference = @{
    # Function Row (Row 0)
    "F1"  = @(0, 0);  "F2"  = @(0, 1);  "F3"  = @(0, 2);  "F4"  = @(0, 3)
    "F5"  = @(0, 4);  "F6"  = @(0, 5);  "F7"  = @(0, 6);  "F8"  = @(0, 7)
    "F9"  = @(0, 8);  "F10" = @(0, 9);  "F11" = @(0, 10); "F12" = @(0, 11)
    
    # Number Row (Row 1)
    "1" = @(1, 0);  "2" = @(1, 1);  "3" = @(1, 2);  "4" = @(1, 3)
    "5" = @(1, 4);  "6" = @(1, 5);  "7" = @(1, 6);  "8" = @(1, 7)
    "9" = @(1, 8);  "0" = @(1, 9);  "-" = @(1, 10); "=" = @(1, 11)
    
    # QWERTY Row (Row 2)
    "Q" = @(2, 0);  "W" = @(2, 1);  "E" = @(2, 2);  "R" = @(2, 3)
    "T" = @(2, 4);  "Y" = @(2, 5);  "U" = @(2, 6);  "I" = @(2, 7)
    "O" = @(2, 8);  "P" = @(2, 9);  "[" = @(2, 10); "]" = @(2, 11)
    "\" = @(2, 12)
    
    # ASDF Row (Row 3)
    "A" = @(3, 0);  "S" = @(3, 1);  "D" = @(3, 2);  "F" = @(3, 3)
    "G" = @(3, 4);  "H" = @(3, 5);  "J" = @(3, 6);  "K" = @(3, 7)
    "L" = @(3, 8);  ";" = @(3, 9);  "'" = @(3, 10)
    
    # ZXCV Row (Row 4)
    "Z" = @(4, 0);  "X" = @(4, 1);  "C" = @(4, 2);  "V" = @(4, 3)
    "B" = @(4, 4);  "N" = @(4, 5);  "M" = @(4, 6);  "," = @(4, 7)
    "." = @(4, 8);  "/" = @(4, 9)
    
    # Arrow Keys (Row 3-4, right side)
    "UP"    = @(3, 16)
    "LEFT"  = @(4, 14)
    "DOWN"  = @(4, 15)
    "RIGHT" = @(4, 16)
}

# ============================================
# DATA SOURCES
# ============================================
function Get-ZoneData {
    param([hashtable]$Zone)
    
    switch ($Zone.Type) {
        "Temperature" {
            switch ($Zone.Sensor) {
                "CPU" { return Get-CpuTemperature }
                "GPU" { return Get-GpuTemperature }
                "Average" { 
                    $c = Get-CpuTemperature
                    $g = Get-GpuTemperature
                    if ($c -and $g) { return ($c + $g) / 2 }
                    return $c
                }
                "Max" {
                    $c = Get-CpuTemperature
                    $g = Get-GpuTemperature
                    return [math]::Max($c, $g)
                }
            }
        }
        "Progress" {
            # Get from global timer progress if available
            if ($script:TimerProgress) {
                return $script:TimerProgress
            }
            return 50  # Default mid-progress
        }
        "Percentage" {
            if ($Zone.DataSource -eq "Memory") {
                return Get-MemoryUsage
            }
            return 0
        }
        "Activity" {
            return Get-Random -Minimum 0 -Maximum 100  # Placeholder
        }
    }
    return 0
}

function Get-CpuTemperature {
    try {
        $wmi = Get-WmiObject -Namespace "root\wmi" -Class "MSAcpi_ThermalZoneTemperature" -ErrorAction SilentlyContinue
        if ($wmi) {
            return [math]::Round(($wmi.CurrentTemperature / 10) - 273.15, 1)
        }
    }
    catch { }
    return 50  # Default fallback
}

function Get-GpuTemperature {
    try {
        $nvidia = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue
        if ($nvidia) {
            $out = & nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>$null
            if ($out -match "^\d+") { return [int]$out }
        }
    }
    catch { }
    return 55  # Default fallback
}

function Get-MemoryUsage {
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $used = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize
        return [math]::Round($used * 100, 1)
    }
    catch { }
    return 40
}

# ============================================
# COLOR CALCULATIONS
# ============================================
function Get-ValueColor {
    param(
        [double]$Value,
        [double]$Min,
        [double]$Max,
        [string]$Preset = "Heat"  # Heat, Cool, Rainbow, Custom
    )
    
    $normalized = [math]::Max(0, [math]::Min(1, ($Value - $Min) / ($Max - $Min)))
    
    switch ($Preset) {
        "Heat" {
            # Blue → Green → Yellow → Red
            if ($normalized -lt 0.33) {
                $f = $normalized * 3
                return @{ R = 0; G = [int](255 * $f); B = 255 }
            }
            elseif ($normalized -lt 0.66) {
                $f = ($normalized - 0.33) * 3
                return @{ R = [int](255 * $f); G = 255; B = [int](255 * (1 - $f)) }
            }
            else {
                $f = ($normalized - 0.66) * 3
                return @{ R = 255; G = [int](255 * (1 - $f)); B = 0 }
            }
        }
        "Cool" {
            # Cyan → Blue → Purple → Pink
            $r = [int](255 * $normalized)
            $b = 255
            $g = [int](255 * (1 - $normalized * 0.5))
            return @{ R = $r; G = $g; B = $b }
        }
        "Rainbow" {
            # Full spectrum
            $hue = $normalized * 360
            return Convert-HslToRgb -Hue $hue -Saturation 1 -Lightness 0.5
        }
        default {
            # Heat default
            return @{ R = [int](255 * $normalized); G = [int](255 * (1 - $normalized)); B = 0 }
        }
    }
}

function Convert-HslToRgb {
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
# OPENRGB OUTPUT
# ============================================
$script:OpenRGB = $null

function Connect-OpenRGBCustom {
    param([string]$Server = "127.0.0.1", [int]$Port = 6742)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($Server, $Port)
        $stream = $client.GetStream()
        $stream.Write([byte[]]@(0x01, 0x00, 0x00, 0x00), 0, 4)
        $script:OpenRGB = @{ Client = $client; Stream = $stream; Connected = $true }
        return $true
    }
    catch { return $false }
}

function Set-CustomZoneRGB {
    if (-not $script:OpenRGB -or -not $script:OpenRGB.Connected) { return }
    
    try {
        $stream = $script:OpenRGB.Stream
        
        # Get LED count
        $stream.Write([byte[]]@(0x03, 0x00, 0x00, 0x00, 0x00), 0, 5)
        $countBytes = New-Object byte[] 4
        $stream.Read($countBytes, 0, 4) | Out-Null
        $ledCount = [BitConverter]::ToInt32($countBytes, 0)
        
        if ($ledCount -eq 0) { return }
        
        # Build zone color map (which LEDs belong to which zone)
        $ledColors = @()
        for ($i = 0; $i -lt $ledCount; $i++) { $ledColors += @{ R = 10; G = 10; B = 10 } }  # Default dim
        
        # Assign colors to zones
        foreach ($zoneName in $script:CustomZones.Keys) {
            $zone = $script:CustomZones[$zoneName]
            if (-not $zone.Active) { continue }
            
            $value = Get-ZoneData -Zone $zone
            $color = Get-ValueColor -Value $value -Min $zone.MinValue -Max $zone.MaxValue -Preset "Heat"
            
            # Apply color to zone's keys
            foreach ($key in $zone.Keys) {
                if ($key -is [Array] -and $key.Count -eq 2) {
                    $row = $key[0]
                    $col = $key[1]
                    # Map row/col to LED index (simplified)
                    $ledIndex = ($row * 22) + $col
                    if ($ledIndex -lt $ledCount) {
                        $ledColors[$ledIndex] = $color
                    }
                }
            }
        }
        
        # Send colors to OpenRGB
        $stream.Write([byte[]]@(0x04, 0x00, 0x00, 0x00, 0x00), 0, 5)
        $stream.Write([BitConverter]::GetBytes([int]$ledCount), 0, 4)
        
        foreach ($c in $ledColors) {
            $stream.Write([byte[]]@([byte]$c.R, [byte]$c.G, [byte]$c.B), 0, 3)
        }
    }
    catch { }
}

# ============================================
# INTERACTIVE ZONE EDITOR
# ============================================
function Edit-CustomZones {
    Write-Host "`n🔧 CUSTOM ZONE EDITOR" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current Zones:" -ForegroundColor White
    
    $index = 1
    $zoneNames = @($script:CustomZones.Keys)
    
    foreach ($name in $zoneNames) {
        $zone = $script:CustomZones[$name]
        $status = if ($zone.Active) { "✓ ON" } else { "✗ OFF" }
        Write-Host "$index. $($zone.Name) $status" -ForegroundColor $(if ($zone.Active) { "Green" } else { "Gray" })
        Write-Host "   $($zone.Description)" -ForegroundColor DarkGray
        $index++
    }
    
    Write-Host "`nCommands:" -ForegroundColor Yellow
    Write-Host "  (number) Toggle zone on/off" -ForegroundColor Gray
    Write-Host "  E        Edit zone keys" -ForegroundColor Gray
    Write-Host "  S        Save configuration" -ForegroundColor Gray
    Write-Host "  T        Test zones live" -ForegroundColor Gray
    Write-Host "  Q        Quit" -ForegroundColor Gray
    
    do {
        $cmd = Read-Host "`nZone command"
        
        if ($cmd -match "^\d+$" -and [int]$cmd -ge 1 -and [int]$cmd -le $zoneNames.Count) {
            $z = $zoneNames[[int]$cmd - 1]
            $script:CustomZones[$z].Active = -not $script:CustomZones[$z].Active
            $newStatus = if ($script:CustomZones[$z].Active) { "ON ✓" } else { "OFF ✗" }
            Write-Host "$($script:CustomZones[$z].Name) is now $newStatus" -ForegroundColor Green
        }
        elseif ($cmd -eq "T") {
            Test-CustomZones
        }
        elseif ($cmd -eq "S") {
            $path = Join-Path $env:LOCALAPPDATA "SleepTimer\custom-zones.json"
            $script:CustomZones | ConvertTo-Json -Depth 5 | Set-Content $path
            Write-Host "Saved to $path" -ForegroundColor Green
        }
        elseif ($cmd -eq "E") {
            Write-Host "`nKey Reference:" -ForegroundColor Cyan
            $script:KeyReference.GetEnumerator() | Sort-Object Value | ForEach-Object {
                Write-Host "  $($_.Key) = Row $($_.Value[0]), Col $($_.Value[1])" -ForegroundColor Gray
            }
            Write-Host "`nExample: @(4, 14) = Left Arrow key" -ForegroundColor Yellow
        }
    } while ($cmd -ne "Q")
}

function Test-CustomZones {
    Write-Host "`n🎮 Testing Custom Zones..." -ForegroundColor Cyan
    Write-Host "Connect to OpenRGB? (Y/n)" -ForegroundColor Yellow
    $resp = Read-Host
    
    if ($resp -ne "n") {
        $connected = Connect-OpenRGBCustom
        if ($connected) {
            Write-Host "✓ RGB Connected - Zones will light up`n" -ForegroundColor Green
        }
    }
    
    Write-Host "Press Ctrl+C to stop test`n" -ForegroundColor Yellow
    
    while ($true) {
        Clear-Host
        Write-Host "🌡 LIVE ZONE DATA" -ForegroundColor Cyan
        Write-Host "=================" -ForegroundColor Cyan
        
        foreach ($zoneName in $script:CustomZones.Keys) {
            $zone = $script:CustomZones[$zoneName]
            $value = Get-ZoneData -Zone $zone
            $color = Get-ValueColor -Value $value -Min $zone.MinValue -Max $zone.MaxValue
            
            $status = if ($zone.Active) { "ON" } else { "OFF" }
            $bar = "█" * [math]::Min(20, [math]::Floor($value / 5))
            
            Write-Host "`n$($zone.Name) [$status]" -ForegroundColor White
            Write-Host "Value: $value | Keys: $($zone.Keys.Count)" -ForegroundColor Gray
            Write-Host "$bar" -ForegroundColor $(
                if ($color.R -gt 200) { "Red" } elseif ($color.G -gt 200) { "Green" } else { "Cyan" }
            )
        }
        
        if ($script:OpenRGB -and $script:OpenRGB.Connected) {
            Set-CustomZoneRGB
        }
        
        Start-Sleep -Seconds 2
    }
}

# ============================================
# EXPORT
# ============================================
Export-ModuleMember -Function Edit-CustomZones, Test-CustomZones, Set-CustomZoneRGB, Connect-OpenRGBCustom

# Run editor if executed directly
if ($MyInvocation.MyCommand.Name -eq "RGB-CustomZones.ps1") {
    Edit-CustomZones
}
