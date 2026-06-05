# RGB Keyboard Integration Guide

Make your Sleep Timer Pro control your gaming keyboard RGB lighting as a visual countdown!

## Supported Keyboards

| Brand | Software Required | Reliability |
|-------|------------------|-------------|
| **Razer** | Razer Synapse 3+ | ⭐⭐⭐⭐⭐ |
| **Corsair** | iCUE (SDK enabled) | ⭐⭐⭐⭐ |
| **Any/Universal** | OpenRGB | ⭐⭐⭐⭐⭐ |
| Logitech | G HUB (limited API) | ⭐⭐⭐ |
| SteelSeries | GG Engine | ⭐⭐⭐ |

## Quick Setup

### Option 1: OpenRGB (Recommended - Works with any keyboard)

1. Download [OpenRGB](https://openrgb.org/) (free, open source)
2. Install and run OpenRGB
3. Go to **Settings** → **SDK Server** → **Start Server**
4. Your keyboard should be detected automatically

### Option 2: Razer Chroma

1. Install **Razer Synapse 3** from razer.com
2. Enable **Chroma Connect** in Synapse settings
3. The SDK runs automatically on port 54235

### Option 3: Corsair iCUE

1. Open **Corsair iCUE**
2. Go to **Settings** (gear icon)
3. Enable **"Enable SDK"** checkbox
4. Restart iCUE

## Integration Code

Add this to `SleepTimer.ps1` after the other script-level variables (around line 95):

```powershell
# RGB Keyboard Support
$script:RGBEnabled = $false
$script:RGBModule = $null
```

### Step 1: Import RGB Module

Add near the top of the script after `Add-Type` lines:

```powershell
# Load RGB Keyboard module if available
$rgbModulePath = Join-Path $PSScriptRoot "RGB-Keyboard.ps1"
if (Test-Path $rgbModulePath) {
    . $rgbModulePath
    $script:RGBModule = $true
}
```

### Step 2: Initialize RGB in GUI

In `New-SleepTimerForm`, add after the form creation (around line 680):

```powershell
# Initialize RGB Keyboard
if ($script:RGBModule) {
    $script:RGBEnabled = Initialize-TimerRGB
}
```

### Step 3: Update RGB in Timer Tick

In the `$timer.Add_Tick({` block (around line 1115), add inside the countdown:

```powershell
# Update RGB Keyboard progress
if ($script:RGBEnabled) {
    Update-TimerRGBProgress -Percent $percent
}
```

### Step 4: Reset on Cancel/Complete

In the cancel button click and timer completion, add:

```powershell
# Reset RGB
if ($script:RGBEnabled) {
    Stop-TimerRGB
    $script:RGBEnabled = $false
}
```

## Visual Effects

The RGB timer shows:

| Timer Status | Keyboard Effect |
|--------------|-----------------|
| **75-100%** | Green gradient across keyboard |
| **50-75%** | Yellow/orange warming up |
| **25-50%** | Red warning zone |
| **0-25%** | Pulsing red urgency |
| **Complete** | Flash red 3 times then reset |

## Troubleshooting

### "No RGB keyboard detected"

1. Make sure your RGB software is running
2. Check that SDK/server mode is enabled
3. Try OpenRGB as it's the most compatible

### Razer: "Chroma not available"

- Ensure Razer Synapse 3 is installed (not Synapse 2)
- Check that Chroma-enabled devices are connected
- Try running as Administrator

### Corsair: "iCUE not available"

- Open iCUE → Settings → Enable SDK checkbox
- Restart iCUE after enabling
- Try running as Administrator

### OpenRGB: "SDK Server not responding"

- Open OpenRGB → Settings → SDK Server tab
- Click "Start Server"
- Default port is 6742

## Advanced: Custom RGB Patterns

Edit `RGB-Keyboard.ps1` to customize:

```powershell
# Example: Wave effect instead of gradient
function Set-CustomWaveEffect {
    param([int]$Percent)
    
    # Create wave pattern based on remaining time
    $wave = @()
    for ($i = 0; $i -lt 22; $i++) {  # 22 keys per row
        $brightness = [math]::Sin(($i + $Percent) * 0.3) * 127 + 128
        $wave += @{
            key = $i
            r = if ($Percent -gt 50) { $brightness } else { 255 }
            g = $brightness
            b = if ($Percent -lt 50) { $brightness } else { 0 }
        }
    }
    return $wave
}
```

## One-File Version (No Module)

If you want everything in one file, paste this at the end of `SleepTimer.ps1`:

```powershell
# ========== RGB KEYBOARD SUPPORT ==========
# (Paste entire RGB-Keyboard.ps1 content here)
# ==========================================
```

Then the integration steps above will work without a separate file.

## Brands Not Listed?

If your keyboard isn't supported:

1. **Try OpenRGB first** - it supports 100+ devices
2. Check if your brand has an SDK (ASUS Aura, MSI Mystic Light, etc.)
3. Use generic Windows notifications as fallback

## Safety Note

RGB keyboard control requires:
- Administrator rights (sometimes)
- RGB software running in background
- SDK/Server mode enabled

The timer will work without RGB if not available - it's purely visual enhancement!
