# Integrate RGB with Sleep Timer Pro

## Quick Integration (Copy-Paste Ready)

### Step 1: Add to SleepTimer.ps1 - After param() block (Line ~75)

```powershell
# ============================================
# RGB KEYBOARD MODULES (Optional)
# ============================================
$script:RGBModules = @{
    Countdown = $null
    Thermal = $null
    Custom = $null
    Studio = $null
    Active = $false
}

# Load RGB modules if available
$rgbPaths = @{
    Countdown = Join-Path $PSScriptRoot "RGB-Countdown.ps1"
    Thermal = Join-Path $PSScriptRoot "RGB-ThermalMonitor.ps1"
    Custom = Join-Path $PSScriptRoot "RGB-CustomZones.ps1"
    Studio = Join-Path $PSScriptRoot "RGB-Studio.ps1"
}

foreach ($module in $rgbPaths.Keys) {
    if (Test-Path $rgbPaths[$module]) {
        try {
            . $rgbPaths[$module]
            $script:RGBModules[$module] = $true
            Write-TimerLog "RGB module loaded: $module"
        }
        catch {
            Write-TimerLog "Failed to load RGB module: $module" "WARN"
        }
    }
}

# RGB Settings (add to Get-DefaultSettings function)
# RGBEnabled = $false
# RGBMode = "Countdown"  # Countdown, Thermal, Custom
```

### Step 2: Add RGB Toggle to Settings Dialog (Line ~1140)

In `Show-SettingsDialog`, add after other checkboxes:

```powershell
# RGB Enable checkbox
$rgbCheck = New-Object System.Windows.Forms.CheckBox
$rgbCheck.Text = "🎨 Enable RGB Keyboard"
$rgbCheck.Checked = $settings.RGBEnabled
$rgbCheck.Location = New-Object System.Drawing.Point(30, $y)
$rgbCheck.Size = New-Object System.Drawing.Size(320, 25)
$rgbCheck.ForeColor = $script:Colors.Text
$rgbCheck.BackColor = $script:Colors.Background
$dialog.Controls.Add($rgbCheck)
$y += 32

# RGB Mode selector (if enabled)
$rgbModeLabel = New-Object System.Windows.Forms.Label
$rgbModeLabel.Text = "RGB Mode:"
$rgbModeLabel.ForeColor = $script:Colors.TextMuted
$rgbModeLabel.Location = New-Object System.Drawing.Point(50, $y)
$rgbModeLabel.Size = New-Object System.Drawing.Size(100, 25)
$dialog.Controls.Add($rgbModeLabel)

$rgbModeCombo = New-Object System.Windows.Forms.ComboBox
$rgbModeCombo.Items.AddRange(@("Countdown", "Thermal", "Custom"))
$rgbModeCombo.SelectedItem = $settings.RGBMode
$rgbModeCombo.Location = New-Object System.Drawing.Point(150, $y)
$rgbModeCombo.Size = New-Object System.Drawing.Size(150, 25)
$rgbModeCombo.DropDownStyle = "DropDownList"
$rgbModeCombo.BackColor = $script:Colors.SurfaceLight
$rgbModeCombo.ForeColor = $script:Colors.Text
$dialog.Controls.Add($rgbModeCombo)
$y += 35
```

And in the save button click handler:

```powershell
$settings.RGBEnabled = $rgbCheck.Checked
$settings.RGBMode = $rgbModeCombo.SelectedItem
```

### Step 3: Initialize RGB on Timer Start (Line ~960)

In `$startButton.Add_Click({`, after `$script:TimerActive = $true`:

```powershell
# Initialize RGB if enabled
if ($settings.RGBEnabled -and $script:RGBModules[$settings.RGBMode]) {
    switch ($settings.RGBMode) {
        "Countdown" {
            $script:RGBTimerState = Start-RGBCountdown -Seconds $totalSeconds -Provider "Auto"
            if ($script:RGBTimerState.Enabled) {
                $script:RGBModules.Active = $true
                Write-TimerLog "RGB Countdown started"
            }
        }
        "Thermal" {
            # Thermal runs continuously, start it
            $script:RGBModules.Active = $true
            Write-TimerLog "RGB Thermal monitoring active"
        }
        "Custom" {
            $connected = Connect-OpenRGBCustom
            if ($connected) {
                $script:RGBModules.Active = $true
                Write-TimerLog "RGB Custom zones connected"
            }
        }
    }
}
```

### Step 4: Update RGB in Timer Loop (Line ~1010)

In `$timer.Add_Tick({`, inside the countdown:

```powershell
# Update RGB display
if ($script:RGBModules.Active) {
    switch ($settings.RGBMode) {
        "Countdown" {
            if ($script:RGBTimerState -and $script:RGBTimerState.Enabled) {
                Update-RGBCountdown -TimerState $script:RGBTimerState -RemainingSeconds $script:RemainingSeconds
            }
        }
        "Thermal" {
            # Update thermal every 5 seconds to avoid flicker
            if ($elapsed % 5 -eq 0) {
                $temps = Get-SystemTemperatures
                Set-ThermalRGBKeyboard -Temperatures $temps
            }
        }
        "Custom" {
            $script:TimerProgress = $percent
            Set-CustomZoneRGB
        }
    }
}
```

### Step 5: Cleanup on Cancel/Complete

In cancel button (line ~1090):

```powershell
# Stop RGB
if ($script:RGBModules.Active) {
    switch ($settings.RGBMode) {
        "Countdown" {
            if ($script:RGBTimerState) {
                Stop-RGBCountdown -TimerState $script:RGBTimerState
            }
        }
        "Thermal" {
            # Reset to default
            if ($script:OpenRGBConnection) {
                $script:OpenRGBConnection.Client.Close()
            }
        }
        "Custom" {
            # Reset zones
            if ($script:OpenRGB) {
                $script:OpenRGB.Client.Close()
            }
        }
    }
    $script:RGBModules.Active = $false
}
```

In timer completion (line ~1065):

```powershell
# RGB completion flash
if ($script:RGBModules.Active -and $settings.RGBMode -eq "Countdown") {
    Stop-RGBCountdown -TimerState $script:RGBTimerState
    $script:RGBModules.Active = $false
}
```

### Step 6: Add RGB Status to Footer

Change the footer (line ~980) to show RGB status:

```powershell
$footer = New-Object System.Windows.Forms.Label
$footer.Text = if ($settings.RGBEnabled) { 
    "Press F1 for help | RGB: $($settings.RGBMode) Mode | Timer continues in background" 
} else { 
    "Press F1 for help | Timer continues in background" 
}
```

## Alternative: One-File Integration

If you want everything in `SleepTimer.ps1` without separate files, paste the contents of:
1. `RGB-Countdown.ps1` (minus the last line)
2. `RGB-ThermalMonitor.ps1` (minus the last line)
3. `RGB-CustomZones.ps1` (minus the last line)

At the **end** of `SleepTimer.ps1` (before final `}`).

Then the integration steps above work without loading external files.

## Testing the Integration

1. Enable RGB in Settings dialog
2. Select mode (Countdown/Thermal/Custom)
3. Start a timer
4. Watch your keyboard light up!

## Troubleshooting

| Issue | Solution |
|-------|----------|
| RGB option grayed out | Module files missing - copy them to same folder |
| "RGB module failed to load" | Check file paths, run as Administrator |
| Keyboard not lighting | Start OpenRGB SDK Server first |
| Wrong colors | Check RGB mode matches loaded module |
| Slow performance | Increase timer interval to 2-5 seconds |

## RGB Studio Launch Button

Add a button in main form to launch RGB Studio:

```powershell
# In New-SleepTimerForm, add after settings button:
$rgbStudioBtn = New-Object System.Windows.Forms.Button
$rgbStudioBtn.Text = "🎨"
$rgbStudioBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$rgbStudioBtn.Size = New-Object System.Drawing.Size(35, 35)
$rgbStudioBtn.Location = New-Object System.Drawing.Point(350, 18)
$rgbStudioBtn.FlatStyle = "Flat"
$rgbStudioBtn.BackColor = $script:Colors.SurfaceLight
$rgbStudioBtn.ForeColor = $script:Colors.Text
$rgbStudioBtn.Add_Click({
    $studioPath = Join-Path $PSScriptRoot "RGB-Studio.ps1"
    if (Test-Path $studioPath) {
        Start-Process powershell -ArgumentList "-File `"$studioPath`"" -WindowStyle Normal
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("RGB-Studio.ps1 not found", "Error", "OK", "Error")
    }
})
$headerPanel.Controls.Add($rgbStudioBtn)
```

Now you have a complete RGB-integrated Sleep Timer Pro! 🎮
