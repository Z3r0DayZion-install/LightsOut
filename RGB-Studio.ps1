#Requires -Version 5.1
<#
.SYNOPSIS
    RGB Studio - Visual Keyboard RGB Customization App
.DESCRIPTION
    Standalone GUI app to map any keyboard area to any RGB effect.
    Create zones, assign triggers (temp, time, audio, etc), preview live.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================
# RGB STUDIO CONFIGURATION
# ============================================
$script:ConfigPath = Join-Path $env:LOCALAPPDATA "RGBStudio\config.json"
$script:ProfilesPath = Join-Path $env:LOCALAPPDATA "RGBStudio\profiles.json"
$script:OpenRGB = $null
$script:CurrentProfile = @{ Name = "Default"; Zones = @() }
$script:IsPreviewRunning = $false

# Standard keyboard grid (6 rows x 22 cols approx)
$script:KeyboardGrid = @{
    Rows = 6
    Cols = 22
    KeySize = 35
    KeySpacing = 2
}

# Color presets
$script:ColorPresets = @(
    @{ Name = "Heat"; Colors = @("0000FF", "00FFFF", "00FF00", "FFFF00", "FF0000") }
    @{ Name = "Cool"; Colors = @("0000FF", "4B0082", "8B00FF", "FF00FF", "FF69B4") }
    @{ Name = "Rainbow"; Colors = @("FF0000", "FF7F00", "FFFF00", "00FF00", "0000FF", "4B0082", "8B00FF") }
    @{ Name = "Fire"; Colors = @("FF0000", "FF4500", "FF8C00", "FFD700", "FFFF00") }
    @{ Name = "Cyber"; Colors = @("00FF00", "00FFFF", "FF00FF", "FFFF00") }
    @{ Name = "Ocean"; Colors = @("000080", "0000FF", "00CED1", "40E0D0", "00FFFF") }
)

# Trigger types
$script:TriggerTypes = @(
    @{ Name = "CPU Temperature"; Type = "CPUTemp"; Min = 30; Max = 90; Unit = "°C" }
    @{ Name = "GPU Temperature"; Type = "GPUTemp"; Min = 30; Max = 85; Unit = "°C" }
    @{ Name = "Timer Progress"; Type = "Timer"; Min = 0; Max = 100; Unit = "%" }
    @{ Name = "Memory Usage"; Type = "Memory"; Min = 0; Max = 100; Unit = "%" }
    @{ Name = "CPU Usage"; Type = "CPUUsage"; Min = 0; Max = 100; Unit = "%" }
    @{ Name = "Audio Visualizer"; Type = "Audio"; Min = 0; Max = 100; Unit = "dB" }
    @{ Name = "Network Speed"; Type = "Network"; Min = 0; Max = 100; Unit = "MB/s" }
    @{ Name = "Time of Day"; Type = "Time"; Min = 0; Max = 24; Unit = "hr" }
    @{ Name = "Battery Level"; Type = "Battery"; Min = 0; Max = 100; Unit = "%" }
    @{ Name = "Static Color"; Type = "Static"; Min = 0; Max = 0; Unit = "" }
    @{ Name = "Breathing Effect"; Type = "Breathing"; Min = 0; Max = 0; Unit = "" }
    @{ Name = "Wave Effect"; Type = "Wave"; Min = 0; Max = 0; Unit = "" }
)

# ============================================
# OPENRGB CONNECTION
# ============================================
function Connect-OpenRGBStudio {
    param([string]$Server = "127.0.0.1", [int]$Port = 6742)
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($Server, $Port)
        $stream = $client.GetStream()
        $stream.Write([byte[]]@(0x01, 0x00, 0x00, 0x00), 0, 4)
        
        $script:OpenRGB = @{
            Client = $client
            Stream = $stream
            Connected = $true
            DeviceCount = 0
        }
        
        # Get device count
        $stream.Write([byte[]]@(0x02), 0, 1)
        $countBytes = New-Object byte[] 4
        $stream.Read($countBytes, 0, 4) | Out-Null
        $script:OpenRGB.DeviceCount = [BitConverter]::ToInt32($countBytes, 0)
        
        return $true
    }
    catch {
        return $false
    }
}

function Apply-RGBToKeyboard {
    param([array]$Zones)
    if (-not $script:OpenRGB -or -not $script:OpenRGB.Connected) { return }
    
    try {
        $stream = $script:OpenRGB.Stream
        
        # Get LED count
        $stream.Write([byte[]]@(0x03, 0x00, 0x00, 0x00, 0x00), 0, 5)
        $countBytes = New-Object byte[] 4
        $stream.Read($countBytes, 0, 4) | Out-Null
        $ledCount = [BitConverter]::ToInt32($countBytes, 0)
        
        if ($ledCount -eq 0) { return }
        
        # Calculate colors for all LEDs
        $ledColors = @()
        for ($i = 0; $i -lt $ledCount; $i++) { $ledColors += @{ R = 0; G = 0; B = 0 } }
        
        # Apply each zone
        foreach ($zone in $Zones) {
            if (-not $zone.Active) { continue }
            
            $color = Get-ZoneColor -Zone $zone
            
            foreach ($key in $zone.Keys) {
                $ledIndex = ($key.Row * $script:KeyboardGrid.Cols) + $key.Col
                if ($ledIndex -lt $ledCount) {
                    $ledColors[$ledIndex] = $color
                }
            }
        }
        
        # Send to OpenRGB
        $stream.Write([byte[]]@(0x04, 0x00, 0x00, 0x00, 0x00), 0, 5)
        $stream.Write([BitConverter]::GetBytes([int]$ledCount), 0, 4)
        
        foreach ($c in $ledColors) {
            $stream.Write([byte[]]@([byte]$c.R, [byte]$c.G, [byte]$c.B), 0, 3)
        }
    }
    catch { }
}

function Get-ZoneColor {
    param([hashtable]$Zone)
    
    $trigger = $script:TriggerTypes | Where-Object { $_.Type -eq $Zone.TriggerType }
    $value = Get-TriggerValue -Type $Zone.TriggerType
    
    switch ($Zone.Effect) {
        "Gradient" {
            return Get-GradientColor -Value $value -Min $Zone.MinValue -Max $Zone.MaxValue -Preset $Zone.ColorPreset
        }
        "Solid" {
            return HexToRgb -Hex $Zone.Color
        }
        "Pulse" {
            $pulse = ([math]::Sin((Get-Date).Second * 0.5) + 1) / 2
            $c = HexToRgb -Hex $Zone.Color
            return @{
                R = [int]($c.R * $pulse)
                G = [int]($c.G * $pulse)
                B = [int]($c.B * $pulse)
            }
        }
        "Rainbow" {
            $hue = (($value / ($Zone.MaxValue - $Zone.MinValue)) * 360 + (Get-Date).Second * 10) % 360
            return HslToRgb -Hue $hue -Saturation 1 -Lightness 0.5
        }
        default {
            return @{ R = 100; G = 100; B = 100 }
        }
    }
}

function Get-TriggerValue {
    param([string]$Type)
    
    switch ($Type) {
        "CPUTemp" { return Get-Random -Min 45 -Max 75 }  # Simulated, use real WMI
        "GPUTemp" { return Get-Random -Min 50 -Max 80 }
        "Timer" { return Get-Random -Min 0 -Max 100 }
        "Memory" { return Get-Random -Min 30 -Max 80 }
        "CPUUsage" { return Get-Random -Min 10 -Max 90 }
        "Audio" { return Get-Random -Min 0 -Max 100 }
        "Network" { return Get-Random -Min 0 -Max 50 }
        "Time" { return (Get-Date).Hour + (Get-Date).Minute / 60 }
        "Battery" { return 75 }
        "Static" { return 0 }
        "Breathing" { return ([math]::Sin((Get-Date).Second * 0.5) + 1) * 50 }
        "Wave" { return (Get-Date).Second * 4 }
        default { return 50 }
    }
}

# ============================================
# COLOR UTILITIES
# ============================================
function HexToRgb {
    param([string]$Hex)
    $Hex = $Hex.Replace("#", "")
    return @{
        R = [Convert]::ToInt32($Hex.Substring(0, 2), 16)
        G = [Convert]::ToInt32($Hex.Substring(2, 2), 16)
        B = [Convert]::ToInt32($Hex.Substring(4, 2), 16)
    }
}

function Get-GradientColor {
    param([double]$Value, [double]$Min, [double]$Max, [string]$Preset)
    
    $norm = [math]::Max(0, [math]::Min(1, ($Value - $Min) / ($Max - $Min)))
    $presetData = $script:ColorPresets | Where-Object { $_.Name -eq $Preset }
    
    if (-not $presetData) { $presetData = $script:ColorPresets[0] }
    
    $colors = $presetData.Colors
    $segment = $norm * ($colors.Count - 1)
    $index = [math]::Floor($segment)
    $frac = $segment - $index
    
    if ($index -ge $colors.Count - 1) {
        return HexToRgb -Hex $colors[-1]
    }
    
    $c1 = HexToRgb -Hex $colors[$index]
    $c2 = HexToRgb -Hex $colors[$index + 1]
    
    return @{
        R = [int]($c1.R + ($c2.R - $c1.R) * $frac)
        G = [int]($c1.G + ($c2.G - $c1.G) * $frac)
        B = [int]($c1.B + ($c2.B - $c1.B) * $frac)
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

function RgbToHex {
    param([int]$R, [int]$G, [int]$B)
    return "{0:X2}{1:X2}{2:X2}" -f $R, $G, $B
}

# ============================================
# MAIN GUI APPLICATION
# ============================================
function New-RGBStudioForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "🎨 RGB Studio - Keyboard Lighting Designer"
    $form.Size = New-Object System.Drawing.Size(1200, 800)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    
    # Header
    $header = New-Object System.Windows.Forms.Panel
    $header.Size = New-Object System.Drawing.Size(1200, 60)
    $header.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 55)
    $form.Controls.Add($header)
    
    $title = New-Object System.Windows.Forms.Label
    $title.Text = "🎨 RGB Studio"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::White
    $title.Location = New-Object System.Drawing.Point(20, 10)
    $title.Size = New-Object System.Drawing.Size(300, 40)
    $header.Controls.Add($title)
    
    # Connection status
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "⚪ OpenRGB: Not Connected"
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $statusLabel.ForeColor = [System.Drawing.Color]::Gray
    $statusLabel.Location = New-Object System.Drawing.Point(900, 20)
    $statusLabel.Size = New-Object System.Drawing.Size(250, 25)
    $header.Controls.Add($statusLabel)
    
    # Connect button
    $connectBtn = New-Object System.Windows.Forms.Button
    $connectBtn.Text = "🔌 Connect"
    $connectBtn.Location = New-Object System.Drawing.Point(800, 15)
    $connectBtn.Size = New-Object System.Drawing.Size(90, 30)
    $connectBtn.BackColor = [System.Drawing.Color]::FromArgb(99, 102, 241)
    $connectBtn.ForeColor = [System.Drawing.Color]::White
    $connectBtn.FlatStyle = "Flat"
    $connectBtn.Add_Click({
        if (Connect-OpenRGBStudio) {
            $statusLabel.Text = "🟢 OpenRGB: Connected ($($script:OpenRGB.DeviceCount) devices)"
            $statusLabel.ForeColor = [System.Drawing.Color]::Green
        }
        else {
            $statusLabel.Text = "🔴 OpenRGB: Failed"
            $statusLabel.ForeColor = [System.Drawing.Color]::Red
            [System.Windows.Forms.MessageBox]::Show("Could not connect to OpenRGB.`n`nMake sure OpenRGB is running and SDK Server is started.`n`nDownload: https://openrgb.org/", "Connection Failed", "OK", "Error")
        }
    })
    $header.Controls.Add($connectBtn)
    
    # Left panel - Zone list
    $leftPanel = New-Object System.Windows.Forms.Panel
    $leftPanel.Size = New-Object System.Drawing.Size(300, 680)
    $leftPanel.Location = New-Object System.Drawing.Point(10, 70)
    $leftPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 48)
    $leftPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($leftPanel)
    
    $zonesLabel = New-Object System.Windows.Forms.Label
    $zonesLabel.Text = "📋 Zones"
    $zonesLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $zonesLabel.ForeColor = [System.Drawing.Color]::White
    $zonesLabel.Location = New-Object System.Drawing.Point(10, 10)
    $zonesLabel.Size = New-Object System.Drawing.Size(280, 30)
    $leftPanel.Controls.Add($zonesLabel)
    
    # Zone listbox
    $zoneList = New-Object System.Windows.Forms.ListBox
    $zoneList.Location = New-Object System.Drawing.Point(10, 50)
    $zoneList.Size = New-Object System.Drawing.Size(280, 500)
    $zoneList.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 58)
    $zoneList.ForeColor = [System.Drawing.Color]::White
    $zoneList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $leftPanel.Controls.Add($zoneList)
    
    # Add Zone button
    $addZoneBtn = New-Object System.Windows.Forms.Button
    $addZoneBtn.Text = "➕ Add Zone"
    $addZoneBtn.Location = New-Object System.Drawing.Point(10, 560)
    $addZoneBtn.Size = New-Object System.Drawing.Size(135, 35)
    $addZoneBtn.BackColor = [System.Drawing.Color]::FromArgb(34, 197, 94)
    $addZoneBtn.ForeColor = [System.Drawing.Color]::White
    $addZoneBtn.FlatStyle = "Flat"
    $addZoneBtn.Add_Click({ Add-NewZone -ZoneList $zoneList })
    $leftPanel.Controls.Add($addZoneBtn)
    
    # Remove Zone button
    $removeZoneBtn = New-Object System.Windows.Forms.Button
    $removeZoneBtn.Text = "🗑 Remove"
    $removeZoneBtn.Location = New-Object System.Drawing.Point(155, 560)
    $removeZoneBtn.Size = New-Object System.Drawing.Size(135, 35)
    $removeZoneBtn.BackColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
    $removeZoneBtn.ForeColor = [System.Drawing.Color]::White
    $removeZoneBtn.FlatStyle = "Flat"
    $leftPanel.Controls.Add($removeZoneBtn)
    
    # Preview button
    $previewBtn = New-Object System.Windows.Forms.Button
    $previewBtn.Text = "▶ Preview"
    $previewBtn.Location = New-Object System.Drawing.Point(10, 610)
    $previewBtn.Size = New-Object System.Drawing.Size(280, 40)
    $previewBtn.BackColor = [System.Drawing.Color]::FromArgb(99, 102, 241)
    $previewBtn.ForeColor = [System.Drawing.Color]::White
    $previewBtn.FlatStyle = "Flat"
    $previewBtn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $previewBtn.Add_Click({
        $script:IsPreviewRunning = -not $script:IsPreviewRunning
        if ($script:IsPreviewRunning) {
            $previewBtn.Text = "⏹ Stop Preview"
            $previewBtn.BackColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
        }
        else {
            $previewBtn.Text = "▶ Preview"
            $previewBtn.BackColor = [System.Drawing.Color]::FromArgb(99, 102, 241)
        }
    })
    $leftPanel.Controls.Add($previewBtn)
    
    # Center - Keyboard visualizer
    $keyboardPanel = New-Object System.Windows.Forms.Panel
    $keyboardPanel.Size = New-Object System.Drawing.Size(600, 250)
    $keyboardPanel.Location = New-Object System.Drawing.Point(320, 70)
    $keyboardPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
    $keyboardPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($keyboardPanel)
    
    $keyboardLabel = New-Object System.Windows.Forms.Label
    $keyboardLabel.Text = "⌨️ Keyboard Layout (Click keys to add to zone)"
    $keyboardLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $keyboardLabel.ForeColor = [System.Drawing.Color]::White
    $keyboardLabel.Location = New-Object System.Drawing.Point(10, 10)
    $keyboardLabel.Size = New-Object System.Drawing.Size(580, 25)
    $keyboardPanel.Controls.Add($keyboardLabel)
    
    # Create visual keyboard grid
    $keyButtons = @()
    $grid = $script:KeyboardGrid
    
    for ($row = 0; $row -lt 5; $row++) {
        for ($col = 0; $col -lt 15; $col++) {
            $btn = New-Object System.Windows.Forms.Button
            $btn.Size = New-Object System.Drawing.Size($grid.KeySize, $grid.KeySize)
            $btn.Location = New-Object System.Drawing.Point(
                10 + ($col * ($grid.KeySize + $grid.KeySpacing)),
                40 + ($row * ($grid.KeySize + $grid.KeySpacing))
            )
            $btn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 70)
            $btn.FlatStyle = "Flat"
            $btn.Tag = @{ Row = $row; Col = $col; Selected = $false }
            
            # Key label
            $labels = @(
                @("Esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "", ""),
                @("`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Del", ""),
                @("Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\", ""),
                @("Cap", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Enter", "", ""),
                @("Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "Shift", "", "", "")
            )
            $btn.Text = $labels[$row][$col]
            $btn.Font = New-Object System.Drawing.Font("Segoe UI", 7)
            $btn.ForeColor = [System.Drawing.Color]::White
            
            $btn.Add_Click({
                $tag = $this.Tag
                $tag.Selected = -not $tag.Selected
                if ($tag.Selected) {
                    $this.BackColor = [System.Drawing.Color]::FromArgb(99, 102, 241)
                }
                else {
                    $this.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 70)
                }
            })
            
            $keyboardPanel.Controls.Add($btn)
            $keyButtons += $btn
        }
    }
    
    # Right panel - Zone properties
    $rightPanel = New-Object System.Windows.Forms.Panel
    $rightPanel.Size = New-Object System.Drawing.Size(250, 680)
    $rightPanel.Location = New-Object System.Drawing.Point(930, 70)
    $rightPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 48)
    $rightPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($rightPanel)
    
    $propsLabel = New-Object System.Windows.Forms.Label
    $propsLabel.Text = "⚙️ Zone Properties"
    $propsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $propsLabel.ForeColor = [System.Drawing.Color]::White
    $propsLabel.Location = New-Object System.Drawing.Point(10, 10)
    $propsLabel.Size = New-Object System.Drawing.Size(230, 30)
    $rightPanel.Controls.Add($propsLabel)
    
    # Trigger type dropdown
    $triggerLabel = New-Object System.Windows.Forms.Label
    $triggerLabel.Text = "Trigger:"
    $triggerLabel.ForeColor = [System.Drawing.Color]::White
    $triggerLabel.Location = New-Object System.Drawing.Point(10, 50)
    $triggerLabel.Size = New-Object System.Drawing.Size(230, 20)
    $rightPanel.Controls.Add($triggerLabel)
    
    $triggerCombo = New-Object System.Windows.Forms.ComboBox
    $triggerCombo.Location = New-Object System.Drawing.Point(10, 75)
    $triggerCombo.Size = New-Object System.Drawing.Size(230, 25)
    $triggerCombo.DropDownStyle = "DropDownList"
    $triggerCombo.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 58)
    $triggerCombo.ForeColor = [System.Drawing.Color]::White
    $script:TriggerTypes | ForEach-Object { $triggerCombo.Items.Add($_.Name) }
    $rightPanel.Controls.Add($triggerCombo)
    
    # Effect dropdown
    $effectLabel = New-Object System.Windows.Forms.Label
    $effectLabel.Text = "Effect:"
    $effectLabel.ForeColor = [System.Drawing.Color]::White
    $effectLabel.Location = New-Object System.Drawing.Point(10, 110)
    $effectLabel.Size = New-Object System.Drawing.Size(230, 20)
    $rightPanel.Controls.Add($effectLabel)
    
    $effectCombo = New-Object System.Windows.Forms.ComboBox
    $effectCombo.Location = New-Object System.Drawing.Point(10, 135)
    $effectCombo.Size = New-Object System.Drawing.Size(230, 25)
    $effectCombo.DropDownStyle = "DropDownList"
    $effectCombo.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 58)
    $effectCombo.ForeColor = [System.Drawing.Color]::White
    @("Gradient", "Solid", "Pulse", "Rainbow", "Wave") | ForEach-Object { $effectCombo.Items.Add($_) }
    $rightPanel.Controls.Add($effectCombo)
    
    # Color preset
    $colorLabel = New-Object System.Windows.Forms.Label
    $colorLabel.Text = "Color Preset:"
    $colorLabel.ForeColor = [System.Drawing.Color]::White
    $colorLabel.Location = New-Object System.Drawing.Point(10, 170)
    $colorLabel.Size = New-Object System.Drawing.Size(230, 20)
    $rightPanel.Controls.Add($colorLabel)
    
    $colorCombo = New-Object System.Windows.Forms.ComboBox
    $colorCombo.Location = New-Object System.Drawing.Point(10, 195)
    $colorCombo.Size = New-Object System.Drawing.Size(230, 25)
    $colorCombo.DropDownStyle = "DropDownList"
    $colorCombo.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 58)
    $colorCombo.ForeColor = [System.Drawing.Color]::White
    $script:ColorPresets | ForEach-Object { $colorCombo.Items.Add($_.Name) }
    $rightPanel.Controls.Add($colorCombo)
    
    # Preview timer
    $previewTimer = New-Object System.Windows.Forms.Timer
    $previewTimer.Interval = 100
    $previewTimer.Add_Tick({
        if ($script:IsPreviewRunning -and $script:OpenRGB -and $script:OpenRGB.Connected) {
            Apply-RGBToKeyboard -Zones $script:CurrentProfile.Zones
        }
    })
    $previewTimer.Start()
    
    $form.ShowDialog() | Out-Null
}

function Add-NewZone {
    param([System.Windows.Forms.ListBox]$ZoneList)
    
    $zoneName = "Zone $($ZoneList.Items.Count + 1)"
    $newZone = @{
        Name = $zoneName
        Keys = @()
        TriggerType = "CPUTemp"
        Effect = "Gradient"
        ColorPreset = "Heat"
        MinValue = 30
        MaxValue = 90
        Active = $true
    }
    
    $script:CurrentProfile.Zones += $newZone
    $ZoneList.Items.Add($zoneName)
}

# Launch the app
New-RGBStudioForm
