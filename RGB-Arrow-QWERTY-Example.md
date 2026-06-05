# RGB Custom Zones: Arrow Keys + QWERTY Example

## 🎯 Your Setup

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  Q  W  E  R  T  Y   ← QWERTY Row = Timer Progress      │
│  🔵 🔵 🟢 🟢 🟡 🟡    (Keys fill up as timer counts down) │
│                                                          │
│  A  S  D  F  G  H  J  K  L                              │
│                                                          │
│  Z  X  C  V  B  N  M                                    │
│                                                          │
│            ↑             ← Arrow Keys = CPU Temp        │
│          ← ↓ →           🟢 = Cool (30°C)               │
│            🟡            🟡 = Warm (60°C)               │
│            🔴            🔴 = Hot (90°C)                │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## How It Works

### 🔷 Arrow Keys (CPU Temperature)
| Key | Shows |
|-----|-------|
| **↑ Up** | Current CPU temp color |
| **← Left** | CPU temp color |
| **↓ Down** | CPU temp color |
| **→ Right** | CPU temp color |

All 4 arrow keys show the same color based on CPU heat:
- **30-40°C** = 🔵 Blue (Ice cold)
- **40-50°C** = 🔷 Cyan (Cool)  
- **50-60°C** = 🟢 Green (Normal)
- **60-70°C** = 🟡 Yellow (Warm)
- **70-80°C** = 🟠 Orange (Hot)
- **80-90°C** = 🔴 Red (Very hot)
- **90°C+** = 🔴⚡ Pulsing (CRITICAL!)

### ⌨️ QWERTY Keys (Timer Progress)
| Key | Timer State |
|-----|-------------|
| **Q** | 100-83% remaining (Blue) |
| **W** | 83-66% remaining (Cyan) |
| **E** | 66-50% remaining (Green) |
| **R** | 50-33% remaining (Yellow) |
| **T** | 33-16% remaining (Orange) |
| **Y** | 16-0% remaining (Red) |

As timer runs down, keys turn from **Blue → Red** one by one.

## Quick Setup

### Step 1: Load the Module

Add to top of `SleepTimer.ps1`:

```powershell
# Load Custom RGB Zones
$customRGBPath = Join-Path $PSScriptRoot "RGB-CustomZones.ps1"
if (Test-Path $customRGBPath) {
    . $customRGBPath
    Write-TimerLog "Custom RGB zones loaded"
}
```

### Step 2: Connect RGB When Timer Starts

In `$startButton.Add_Click({` block:

```powershell
# Connect RGB for arrows + QWERTY
$script:RGBConnected = Connect-OpenRGBCustom
if ($script:RGBConnected) {
    Write-TimerLog "RGB Zones connected"
}
```

### Step 3: Update Every Second

In `$timer.Add_Tick({` block, add:

```powershell
# Update arrow keys (CPU temp) and QWERTY (timer progress)
if ($script:RGBConnected) {
    # Set global timer progress for QWERTY row
    $script:TimerProgress = $percent
    
    # Update all custom zones
    Set-CustomZoneRGB
}
```

### Step 4: Cleanup on Stop

In cancel and completion handlers:

```powershell
# Reset RGB zones
if ($script:RGBConnected) {
    # Turn off zone lighting
    foreach ($zone in $script:CustomZones.Keys) {
        $script:CustomZones[$zone].Active = $false
    }
    Set-CustomZoneRGB
}
```

## Customization

### Change Arrow Keys to GPU Temp

Edit `RGB-CustomZones.ps1` line ~35:

```powershell
ArrowKeys_CPU = @{
    Sensor = "GPU"  # Change from "CPU" to "GPU"
    MinValue = 30
    MaxValue = 85
}
```

### Change QWERTY to Show Memory

Edit line ~50:

```powershell
QWERTY_Timer = @{
    Type = "Percentage"
    DataSource = "Memory"  # Instead of timer
    MinValue = 0
    MaxValue = 100
}
```

### Add More Zones

Add to `$script:CustomZones` hash table:

```powershell
# Number row = GPU temp
Numbers_GPU = @{
    Name = "GPU (1-5)"
    Keys = @(@(1,0), @(1,1), @(1,2), @(1,3), @(1,4))  # 1,2,3,4,5
    Type = "Temperature"
    Sensor = "GPU"
    MinValue = 30
    MaxValue = 85
    Active = $true
}

# ASDF = Battery level (laptops)
ASDF_Battery = @{
    Name = "Battery (ASDF)"
    Keys = @(@(3,0), @(3,1), @(3,2), @(3,3))  # A,S,D,F
    Type = "Percentage"
    DataSource = "Battery"
    MinValue = 0
    MaxValue = 100
    Active = $true
}
```

## Visual Layout Reference

```
Row 2:  Q  W  E  R  T  Y  U  I  O  P
        ↑  ↑  ↑  ↑  ↑  ↑
        │  │  │  │  │  └── Y = 16% timer (Red)
        │  │  │  │  └───── T = 33% timer (Orange)
        │  │  │  └──────── R = 50% timer (Yellow)
        │  │  └─────────── E = 66% timer (Green)
        │  └────────────── W = 83% timer (Cyan)
        └───────────────── Q = 100% timer (Blue)

Row 3-4: Arrow keys at right side
         ↑ Up    = Row 3, Col 16
        ← Left   = Row 4, Col 14  ← All show CPU temp
        ↓ Down   = Row 4, Col 15
        → Right  = Row 4, Col 16
```

## Test Without Sleep Timer

Run this to see zones in action:

```powershell
. "RGB-CustomZones.ps1"
Test-CustomZones
```

You'll see live data updating on your keyboard!

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Arrow keys wrong color | Check `$script:KeyReference` mapping |
| QWERTY not updating | Verify `$script:TimerProgress` is being set |
| Colors don't match | Adjust `MinValue` and `MaxValue` |
| Wrong keys light up | Edit `Keys` array coordinates |
| No RGB output | Start OpenRGB SDK Server |

## Key Coordinate Reference

Find any key's (row, col):

```powershell
. "RGB-CustomZones.ps1"
$script:KeyReference | Format-Table -AutoSize
```

Output:
```
Name  Value
----  -----
Q     {2, 0}
W     {2, 1}
UP    {3, 16}
LEFT  {4, 14}
F1    {0, 0}
1     {1, 0}
```

## More Ideas

| Zone | Keys | Shows |
|------|------|-------|
| **WASD** | W,A,S,D | Movement + CPU temp |
| **12345** | Number row | GPU temp gradient |
| **F1-F4** | Function keys | Fan speed |
| **Spacebar** | Space | Critical alert (flashing) |
| **Numpad** | 0-9 | Network download speed |

Your keyboard is now a **live system dashboard**! 🎮🌡
