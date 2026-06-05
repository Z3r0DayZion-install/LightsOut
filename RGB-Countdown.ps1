#Requires -Version 5.1
<#
.SYNOPSIS
    RGB Keyboard Countdown Timer Visualizer
.DESCRIPTION
    Creates a visual countdown on RGB keyboard where keys light up showing remaining time.
    Like a progress bar made of keyboard keys that shrinks as time runs out.
#>

$script:RGBState = @{
    SessionId = $null
    OpenRGB = $null
    Enabled = $false
    TotalKeys = 104
}

# Standard QWERTY layout key positions (row, column) for visual countdown
$script:KeyLayout = @(
    # Row 0: Function keys (F1-F12) + Escape
    @( @(0,0), @(0,1), @(0,2), @(0,3), @(0,4), @(0,5), @(0,6), @(0,7), @(0,8), @(0,9), @(0,10), @(0,11), @(0,12) ),
    # Row 1: Number row
    @( @(1,0), @(1,1), @(1,2), @(1,3), @(1,4), @(1,5), @(1,6), @(1,7), @(1,8), @(1,9), @(1,10), @(1,11), @(1,12), @(1,13) ),
    # Row 2: QWERTY row
    @( @(2,0), @(2,1), @(2,2), @(2,3), @(2,4), @(2,5), @(2,6), @(2,7), @(2,8), @(2,9), @(2,10), @(2,11), @(2,12), @(2,13) ),
    # Row 3: ASDF row
    @( @(3,0), @(3,1), @(3,2), @(3,3), @(3,4), @(3,5), @(3,6), @(3,7), @(3,8), @(3,9), @(3,10), @(3,11), @(3,12) ),
    # Row 4: ZXCV row
    @( @(4,0), @(4,1), @(4,2), @(4,3), @(4,4), @(4,5), @(4,6), @(4,7), @(4,8), @(4,9), @(4,10), @(4,11) ),
    # Row 5: Spacebar row (modifiers only)
    @( @(5,0), @(5,3), @(5,6), @(5,9), @(5,11) )
)

# Flatten layout for sequential countdown
$script:AllKeys = @()
for ($row = 0; $row -lt $script:KeyLayout.Count; $row++) {
    for ($col = 0; $col -lt $script:KeyLayout[$row].Count; $col++) {
        $script:AllKeys += @{ Row = $row; Col = $col; Index = $script:AllKeys.Count }
    }
}
$script:RGBState.TotalKeys = $script:AllKeys.Count

function Connect-OpenRGB {
    param([string]$ServerHost = "127.0.0.1", [int]$Port = 6742)
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.ReceiveTimeout = 1000
        $client.SendTimeout = 1000
        $client.Connect($ServerHost, $Port)
        
        $stream = $client.GetStream()
        
        # Send protocol version request (0x01)
        $header = [byte[]]@(0x01, 0x00, 0x00, 0x00)
        $stream.Write($header, 0, 4)
        
        # Read response
        $response = New-Object byte[] 4
        $stream.Read($response, 0, 4) | Out-Null
        
        Write-Host "✓ OpenRGB Connected (Protocol: $($response[0]))" -ForegroundColor Green
        
        return @{
            Client = $client
            Stream = $stream
            Connected = $true
            DeviceCount = 0
        }
    }
    catch {
        Write-Host "⚠ OpenRGB not available (Install from openrgb.org and start SDK Server)" -ForegroundColor Yellow
        return @{ Connected = $false }
    }
}

function Get-OpenRGBDevices {
    param([hashtable]$Connection)
    if (-not $Connection.Connected) { return @() }
    
    try {
        # Request device count (0x02)
        $Connection.Stream.Write([byte[]]@(0x02), 0, 1)
        
        $countBytes = New-Object byte[] 4
        $Connection.Stream.Read($countBytes, 0, 4) | Out-Null
        $count = [BitConverter]::ToInt32($countBytes, 0)
        
        $Connection.DeviceCount = $count
        return $count
    }
    catch {
        return 0
    }
}

function Set-OpenRGBCountdown {
    param(
        [hashtable]$Connection,
        [int]$RemainingSeconds,
        [int]$TotalSeconds,
        [int]$DeviceId = 0
    )
    if (-not $Connection.Connected) { return }
    
    # Calculate percentage remaining
    $percentRemaining = [math]::Max(0, [math]::Min(100, ($RemainingSeconds / $TotalSeconds) * 100))
    
    # Calculate how many keys to light up
    $keysToLight = [math]::Floor(($script:RGBState.TotalKeys * $percentRemaining) / 100)
    
    # Color calculation based on urgency
    $urgencyRatio = 1 - ($percentRemaining / 100)
    
    # Start green (safe), transition to red (danger)
    $r = [math]::Min(255, [int](255 * $urgencyRatio * 2))
    $g = [math]::Min(255, [int](255 * (1 - $urgencyRatio)))
    $b = 0
    
    # Pulse effect for last 10%
    if ($percentRemaining -lt 10) {
        $pulse = [math]::Sin((Get-Date).Second * 0.5) * 50 + 205
        $r = [math]::Min(255, $pulse)
    }
    
    try {
        $stream = $Connection.Stream
        
        # Get device LED count first
        $stream.Write([byte[]]@(0x03, [byte]$DeviceId, 0x00, 0x00, 0x00), 0, 5)
        
        $ledCountBytes = New-Object byte[] 4
        $stream.Read($ledCountBytes, 0, 4) | Out-Null
        $ledCount = [BitConverter]::ToInt32($ledCountBytes, 0)
        
        if ($ledCount -eq 0) { return }
        
        # Build LED color data
        $colorsToLight = [math]::Min($keysToLight, $ledCount)
        
        # Command: Update LEDs (0x04)
        $cmd = [byte[]]@(0x04, [byte]$DeviceId, 0x00, 0x00, 0x00)
        $stream.Write($cmd, 0, 5)
        
        # Send number of LEDs
        $stream.Write([BitConverter]::GetBytes([int]$ledCount), 0, 4)
        
        # Send colors for each LED
        for ($i = 0; $i -lt $ledCount; $i++) {
            if ($i -lt $colorsToLight) {
                # Lit key (countdown active)
                $stream.Write([byte[]]@([byte]$r, [byte]$g, [byte]$b), 0, 3)
            }
            else {
                # Dim/off key (time elapsed)
                $stream.Write([byte[]]@(0x10, 0x10, 0x10), 0, 3)  # Very dim gray
            }
        }
    }
    catch {
        # Silently fail - RGB is cosmetic
    }
}

function Set-RazerCountdown {
    param(
        [string]$SessionId,
        [int]$RemainingSeconds,
        [int]$TotalSeconds
    )
    if (-not $SessionId) { return }
    
    $percentRemaining = [math]::Max(0, [math]::Min(100, ($RemainingSeconds / $TotalSeconds) * 100))
    $urgencyRatio = 1 - ($percentRemaining / 100)
    
    $r = [math]::Min(255, [int](255 * $urgencyRatio * 2))
    $g = [math]::Min(255, [int](255 * (1 - $urgencyRatio)))
    $b = 0
    
    # Build Chroma effect
    $rows = 6
    $cols = 22
    $effect = @()
    
    for ($row = 0; $row -lt $rows; $row++) {
        $rowPercent = ($row / $rows) * 100
        for ($col = 0; $col -lt $cols; $col++) {
            $keyPercent = ($col / $cols) * 100
            $overallPercent = ($rowPercent + $keyPercent) / 2
            
            if ($overallPercent -lt $percentRemaining) {
                $effect += @{ r = $r; g = $g; b = $b }
            }
            else {
                $effect += @{ r = 5; g = 5; b = 5 }  # Dim
            }
        }
    }
    
    try {
        $uri = "http://localhost:54235/razer/chromasdk/keyboard"
        $body = @{
            effect = "CHROMA_CUSTOM"
            param = @{ color = $effect }
        } | ConvertTo-Json -Depth 5
        
        Invoke-RestMethod -Uri $uri -Method Put -Body $body -ContentType "application/json" -TimeoutSec 1 | Out-Null
    }
    catch { }
}

# ============================================
# MAIN COUNTDOWN CONTROLLER
# ============================================
function Start-RGBCountdown {
    param(
        [int]$Seconds,
        [string]$Provider = "Auto"  # Auto, OpenRGB, Razer
    )
    
    Write-Host "`n🎮 RGB Keyboard Countdown Timer" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    $script:RGBState.Enabled = $false
    
    # Try providers in order
    if ($Provider -eq "Auto" -or $Provider -eq "OpenRGB") {
        $script:RGBState.OpenRGB = Connect-OpenRGB
        if ($script:RGBState.OpenRGB.Connected) {
            $deviceCount = Get-OpenRGBDevices -Connection $script:RGBState.OpenRGB
            if ($deviceCount -gt 0) {
                $script:RGBState.Enabled = $true
                Write-Host "✓ OpenRGB: $deviceCount device(s) found" -ForegroundColor Green
            }
        }
    }
    
    if (-not $script:RGBState.Enabled -and ($Provider -eq "Auto" -or $Provider -eq "Razer")) {
        try {
            $uri = "http://localhost:54235/razer/chromasdk"
            $body = @{
                title = "Sleep Timer Pro"
                description = "RGB Countdown"
                author = @{ name = "SleepTimer"; contact = "" }
                device_supported = @("keyboard")
                category = "application"
            } | ConvertTo-Json
            
            $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -TimeoutSec 2
            $script:RGBState.SessionId = $response.sessionid
            $script:RGBState.Enabled = $true
            Write-Host "✓ Razer Chroma Connected" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Razer Chroma not available" -ForegroundColor Yellow
        }
    }
    
    if (-not $script:RGBState.Enabled) {
        Write-Host "`n❌ No RGB keyboard detected" -ForegroundColor Red
        Write-Host "Install OpenRGB (recommended) or Razer Synapse" -ForegroundColor Gray
        return @{ Enabled = $false }
    }
    
    Write-Host "`n⏱ Countdown: $(Format-TimeSpan $Seconds)" -ForegroundColor White
    Write-Host "📊 Visual: Keyboard shows remaining time as green→red bar`n" -ForegroundColor Gray
    
    return @{
        Enabled = $true
        TotalSeconds = $Seconds
        StartTime = Get-Date
    }
}

function Update-RGBCountdown {
    param(
        [hashtable]$TimerState,
        [int]$RemainingSeconds
    )
    if (-not $TimerState.Enabled) { return }
    
    # Update visual
    if ($script:RGBState.OpenRGB -and $script:RGBState.OpenRGB.Connected) {
        Set-OpenRGBCountdown -Connection $script:RGBState.OpenRGB -RemainingSeconds $RemainingSeconds -TotalSeconds $TimerState.TotalSeconds
    }
    elseif ($script:RGBState.SessionId) {
        Set-RazerCountdown -SessionId $script:RGBState.SessionId -RemainingSeconds $RemainingSeconds -TotalSeconds $TimerState.TotalSeconds
    }
}

function Stop-RGBCountdown {
    param([hashtable]$TimerState)
    if (-not $TimerState.Enabled) { return }
    
    Write-Host "`n🎮 Resetting RGB keyboard..." -ForegroundColor Cyan
    
    # Flash completion effect
    if ($script:RGBState.OpenRGB -and $script:RGBState.OpenRGB.Connected) {
        # Flash white 3 times
        for ($i = 0; $i -lt 3; $i++) {
            # All white
            $stream = $script:RGBState.OpenRGB.Stream
            $stream.Write([byte[]]@(0x04, 0x00, 0x00, 0x00, 0x00), 0, 5)
            $stream.Write([BitConverter]::GetBytes([int]100), 0, 4)
            for ($j = 0; $j -lt 100; $j++) {
                $stream.Write([byte[]]@(255, 255, 255), 0, 3)
            }
            Start-Sleep -Milliseconds 200
            
            # All off
            $stream.Write([byte[]]@(0x04, 0x00, 0x00, 0x00, 0x00), 0, 5)
            $stream.Write([BitConverter]::GetBytes([int]100), 0, 4)
            for ($j = 0; $j -lt 100; $j++) {
                $stream.Write([byte[]]@(0, 0, 0), 0, 3)
            }
            Start-Sleep -Milliseconds 200
        }
        
        $script:RGBState.OpenRGB.Client.Close()
    }
    
    if ($script:RGBState.SessionId) {
        try {
            # Reset Chroma
            $uri = "http://localhost:54235/razer/chromasdk/keyboard"
            $body = @{ effect = "CHROMA_NONE" } | ConvertTo-Json
            Invoke-RestMethod -Uri $uri -Method Put -Body $body -ContentType "application/json" | Out-Null
            
            # Unregister
            $uri = "http://localhost:54235/razer/chromasdk"
            Invoke-RestMethod -Uri $uri -Method Delete | Out-Null
        }
        catch { }
    }
    
    $script:RGBState.Enabled = $false
    Write-Host "✓ RGB Reset complete" -ForegroundColor Green
}

function Show-RGBCountdownDemo {
    Write-Host "`n🎮 RGB KEYBOARD COUNTDOWN DEMO" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "This shows how the countdown will look on your RGB keyboard`n" -ForegroundColor Gray
    
    $demoSeconds = 10
    $timerState = Start-RGBCountdown -Seconds $demoSeconds -Provider "Auto"
    
    if (-not $timerState.Enabled) {
        Write-Host "`nDemo requires RGB keyboard software (OpenRGB recommended)" -ForegroundColor Yellow
        return
    }
    
    for ($i = $demoSeconds; $i -ge 0; $i--) {
        Write-Host -NoNewline "`r⏱ [$i seconds] Keyboard: " -ForegroundColor White
        
        # Visual bar
        $barLength = 20
        $filled = [math]::Floor(($i / $demoSeconds) * $barLength)
        $empty = $barLength - $filled
        $bar = "█" * $filled + "░" * $empty
        
        # Color based on urgency
        if ($i -gt $demoSeconds * 0.5) {
            Write-Host $bar -ForegroundColor Green -NoNewline
        }
        elseif ($i -gt $demoSeconds * 0.25) {
            Write-Host $bar -ForegroundColor Yellow -NoNewline
        }
        else {
            Write-Host $bar -ForegroundColor Red -NoNewline
        }
        
        Write-Host " $([math]::Floor(($i/$demoSeconds)*100))%" -ForegroundColor Gray -NoNewline
        
        Update-RGBCountdown -TimerState $timerState -RemainingSeconds $i
        Start-Sleep -Seconds 1
    }
    
    Write-Host ""  # New line
    Stop-RGBCountdown -TimerState $timerState
    
    Write-Host "`n✓ Demo complete! Your keyboard flashed to signal completion." -ForegroundColor Green
}

# Export functions
Export-ModuleMember -Function Start-RGBCountdown, Update-RGBCountdown, Stop-RGBCountdown, Show-RGBCountdownDemo

# Run demo if executed directly
if ($MyInvocation.InvocationName -eq "&" -or $MyInvocation.Line -eq "" -or $MyInvocation.MyCommand.Name -eq "RGB-Countdown.ps1") {
    Show-RGBCountdownDemo
}
