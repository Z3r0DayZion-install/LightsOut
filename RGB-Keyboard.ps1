#Requires -Version 5.1
<#
.SYNOPSIS
    RGB Keyboard Integration for Sleep Timer Pro
.DESCRIPTION
    Controls RGB lighting on gaming keyboards as a visual timer indicator.
    Supports Razer Chroma, Corsair iCUE, and OpenRGB.
#>

# ============================================
# RAZER CHROMA SDK (via REST API)
# ============================================
function Initialize-RazerChroma {
    try {
        $uri = "http://localhost:54235/razer/chromasdk"
        $body = @{
            title = "Sleep Timer Pro"
            description = "RGB Timer Visualization"
            author = @{ name = "SleepTimer"; contact = "" }
            device_supported = @("keyboard", "mouse", "headset", "mousepad")
            category = "application"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
        return $response.sessionid
    }
    catch {
        Write-Host "Razer Chroma not available (Install Razer Synapse)" -ForegroundColor Yellow
        return $null
    }
}

function Set-RazerTimerProgress {
    param(
        [string]$SessionId,
        [int]$Percent,  # 0-100
        [string]$Color = "green"  # green, yellow, red
    )
    if (-not $SessionId) { return }
    
    $colorMap = @{
        green  = @{ r = 0; g = 255; b = 0 }
        yellow = @{ r = 255; g = 165; b = 0 }
        red    = @{ r = 255; g = 0; b = 0 }
        blue   = @{ r = 0; g = 100; b = 255 }
    }
    
    $c = $colorMap[$Color]
    
    # Calculate how many keys to light up based on percentage
    # Standard keyboard has ~104 keys in a grid
    $keysToLight = [math]::Floor(104 * ($Percent / 100))
    
    $effects = @()
    
    # Create gradient effect across keyboard rows
    for ($row = 0; $row -lt 6; $row++) {
        $rowProgress = ($row / 6) * 100
        if ($rowProgress -le $Percent) {
            $intensity = [math]::Min(255, [math]::Floor(255 * ($Percent / 100)))
            $effects += @{
                row = $row
                color = @{ r = $c.r; g = $c.g; b = $c.b }
                intensity = $intensity
            }
        }
    }
    
    $uri = "http://localhost:54235/razer/chromasdk/keyboard"
    $body = @{
        effect = "CHROMA_CUSTOM"
        param = @{ color = $effects }
    } | ConvertTo-Json -Depth 5
    
    try {
        Invoke-RestMethod -Uri $uri -Method Put -Body $body -ContentType "application/json" | Out-Null
    }
    catch { }
}

function Stop-RazerChroma {
    param([string]$SessionId)
    if (-not $SessionId) { return }
    
    try {
        $uri = "http://localhost:54235/razer/chromasdk"
        Invoke-RestMethod -Uri $uri -Method Delete | Out-Null
    }
    catch { }
}

# ============================================
# CORSAIR iCUE SDK (via CUE.NET or REST)
# ============================================
function Initialize-CorsairICUE {
    try {
        # iCUE runs on port 25555 when SDK is enabled
        $response = Invoke-RestMethod -Uri "http://localhost:25555/devices" -Method Get -ErrorAction Stop
        return @{ Available = $true; Devices = $response }
    }
    catch {
        Write-Host "Corsair iCUE not available (Enable SDK in iCUE settings)" -ForegroundColor Yellow
        return @{ Available = $false }
    }
}

function Set-CorsairTimerProgress {
    param(
        [hashtable]$ICUE,
        [int]$Percent,
        [string]$Color = "green"
    )
    if (-not $ICUE.Available) { return }
    
    $colorMap = @{
        green  = "0,255,0"
        yellow = "255,165,0"
        red    = "255,0,0"
        blue   = "0,100,255"
    }
    
    $c = $colorMap[$Color]
    
    # Light up LEDs based on percentage
    $ledCount = 100  # Approximate per-key RGB zones
    $ledsToLight = [math]::Floor($ledCount * ($Percent / 100))
    
    try {
        $uri = "http://localhost:25555/lighting"
        $body = @{
            device = "keyboard"
            effect = "progress"
            percent = $Percent
            color = $c
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" | Out-Null
    }
    catch { }
}

# ============================================
# OPENRGB (Universal - Supports most brands)
# ============================================
# Download OpenRGB from: https://openrgb.org/
# Enable Server in OpenRGB: Settings > SDK Server > Start Server

function Initialize-OpenRGB {
    param([string]$Server = "127.0.0.1", [int]$Port = 6742)
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($Server, $Port)
        $stream = $client.GetStream()
        
        # Request controller count
        $header = [byte[]]@(0x01, 0x00, 0x00, 0x00)  # Request protocol version
        $stream.Write($header, 0, 4)
        
        return @{ 
            Client = $client
            Stream = $stream
            Available = $true
        }
    }
    catch {
        Write-Host "OpenRGB not available (Install OpenRGB and enable SDK Server)" -ForegroundColor Yellow
        return @{ Available = $false }
    }
}

function Set-OpenRGBTimerProgress {
    param(
        [hashtable]$OpenRGB,
        [int]$Percent,
        [string]$Color = "green"
    )
    if (-not $OpenRGB.Available) { return }
    
    $colorMap = @{
        green  = @(0, 255, 0)
        yellow = @(255, 165, 0)
        red    = @(255, 0, 0)
        blue   = @(0, 100, 255)
    }
    
    $c = $colorMap[$Color]
    
    # OpenRGB protocol: Set LED colors
    # This is a simplified version - full protocol needs device ID mapping
    
    try {
        $stream = $OpenRGB.Stream
        
        # Calculate color based on percentage
        $r = if ($Percent -lt 50) { [math]::Floor(255 * ($Percent / 50)) } else { 255 }
        $g = if ($Percent -gt 50) { [math]::Floor(255 * ((100 - $Percent) / 50)) } else { 255 }
        $b = 0
        
        # Set all LEDs to color (simplified)
        $ledData = [byte[]]@(
            0x03,  # Update LEDs command
            0x00, 0x00, 0x00, 0x00,  # Device ID (0 = first device)
            $r, $g, $b  # RGB values
        )
        
        $stream.Write($ledData, 0, $ledData.Length)
    }
    catch { }
}

function Stop-OpenRGB {
    param([hashtable]$OpenRGB)
    if (-not $OpenRGB.Available) { return }
    
    try {
        # Reset to default
        $stream = $OpenRGB.Stream
        $resetCmd = [byte[]]@(0x04, 0x00, 0x00, 0x00, 0x00)
        $stream.Write($resetCmd, 0, $resetCmd.Length)
        
        $OpenRGB.Client.Close()
    }
    catch { }
}

# ============================================
# TIMER RGB CONTROLLER
# ============================================
$script:RGBProviders = @{
    Razer = @{ SessionId = $null }
    Corsair = @{ ICUE = $null }
    OpenRGB = @{ Connection = $null }
}

function Initialize-TimerRGB {
    Write-Host "Initializing RGB Keyboard Support..." -ForegroundColor Cyan
    
    # Try all providers
    $script:RGBProviders.Razer.SessionId = Initialize-RazerChroma
    $script:RGBProviders.Corsair.ICUE = Initialize-CorsairICUE
    $script:RGBProviders.OpenRGB.Connection = Initialize-OpenRGB
    
    $active = @()
    if ($script:RGBProviders.Razer.SessionId) { $active += "Razer Chroma" }
    if ($script:RGBProviders.Corsair.ICUE.Available) { $active += "Corsair iCUE" }
    if ($script:RGBProviders.OpenRGB.Connection.Available) { $active += "OpenRGB" }
    
    if ($active.Count -gt 0) {
        Write-Host "✓ RGB Active: $($active -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ No RGB keyboard detected" -ForegroundColor Yellow
        Write-Host "  Install one of:" -ForegroundColor Gray
        Write-Host "    • Razer Synapse (Razer keyboards)" -ForegroundColor Gray
        Write-Host "    • Corsair iCUE (Corsair keyboards, enable SDK)" -ForegroundColor Gray
        Write-Host "    • OpenRGB (Universal, enable SDK Server)" -ForegroundColor Gray
    }
    
    return $active.Count -gt 0
}

function Update-TimerRGBProgress {
    param(
        [int]$Percent,  # 0-100
        [int]$RemainingSeconds = 0
    )
    
    # Determine color based on percentage
    $color = switch ($Percent) {
        { $_ -lt 25 } { "green" }
        { $_ -lt 50 } { "green" }
        { $_ -lt 75 } { "yellow" }
        { $_ -lt 90 } { "yellow" }
        default { "red" }
    }
    
    # Update all active providers
    if ($script:RGBProviders.Razer.SessionId) {
        Set-RazerTimerProgress -SessionId $script:RGBProviders.Razer.SessionId -Percent $Percent -Color $color
    }
    if ($script:RGBProviders.Corsair.ICUE.Available) {
        Set-CorsairTimerProgress -ICUE $script:RGBProviders.Corsair.ICUE -Percent $Percent -Color $color
    }
    if ($script:RGBProviders.OpenRGB.Connection.Available) {
        Set-OpenRGBTimerProgress -OpenRGB $script:RGBProviders.OpenRGB.Connection -Percent $Percent -Color $color
    }
}

function Stop-TimerRGB {
    # Reset all to default
    Stop-RazerChroma -SessionId $script:RGBProviders.Razer.SessionId
    Stop-OpenRGB -OpenRGB $script:RGBProviders.OpenRGB.Connection
    
    Write-Host "RGB Keyboard reset to default" -ForegroundColor Green
}

# ============================================
# EXAMPLE USAGE WITH SLEEP TIMER
# ============================================
<#
# Initialize RGB at start
$rgbAvailable = Initialize-TimerRGB

# In your timer loop, call every second:
Update-TimerRGBProgress -Percent $currentPercent

# At timer end or cancel:
Stop-TimerRGB
#>

Export-ModuleMember -Function Initialize-TimerRGB, Update-TimerRGBProgress, Stop-TimerRGB
