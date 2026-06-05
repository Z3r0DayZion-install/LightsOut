# RGB Countdown Integration for Sleep Timer Pro

Make your keyboard a **visual countdown timer** that shows time remaining as a shrinking bar of light!

## What It Looks Like

```
Time: 10:00 remaining → 🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢 (Full keyboard green)
Time: 05:00 remaining → 🟡🟡🟡🟡🟡⚫⚫⚫⚫⚫ (Half yellow, half dark)
Time: 01:00 remaining → 🔴⚫⚫⚫⚫⚫⚫⚫⚫⚫ (Just red corner flashing)
Time: 00:00 → ⚪⚪⚪ (Flash white 3x - DONE!)
```

## Quick Integration (4 Steps)

### Step 1: Add RGB Module

At the **top** of `SleepTimer.ps1`, after the `Add-Type` lines (around line 77), add:

```powershell
# RGB Keyboard Countdown Support
$rgbCountdownPath = Join-Path $PSScriptRoot "RGB-Countdown.ps1"
if (Test-Path $rgbCountdownPath) {
    . $rgbCountdownPath
    Write-TimerLog "RGB Countdown module loaded"
}
```

### Step 2: Initialize RGB When Timer Starts

In the `$startButton.Add_Click({` block (around line 957), add **after** `$script:TimerActive = $true`:

```powershell
# Initialize RGB Countdown
$script:RGBTimerState = Start-RGBCountdown -Seconds $totalSeconds -Provider "Auto"
```

### Step 3: Update RGB Every Second

In the `$timer.Add_Tick({` block (around line 975), add **inside** the countdown loop:

```powershell
# Update RGB countdown display
if ($script:RGBTimerState -and $script:RGBTimerState.Enabled) {
    Update-RGBCountdown -TimerState $script:RGBTimerState -RemainingSeconds $script:RemainingSeconds
}
```

### Step 4: Reset RGB on Cancel/Complete

In the `$cancelButton.Add_Click({` block (around line 1068), add at the start:

```powershell
# Stop RGB countdown
if ($script:RGBTimerState) {
    Stop-RGBCountdown -TimerState $script:RGBTimerState
}
```

Also in the timer completion section (around line 1060), add before `Execute-TimerAction`:

```powershell
# Flash RGB completion
if ($script:RGBTimerState) {
    Stop-RGBCountdown -TimerState $script:RGBTimerState
}
```

## Test It

1. Install [OpenRGB](https://openrgb.org/) (easiest option)
2. Open OpenRGB → Settings → SDK Server → Start Server
3. Run `SleepTimer.ps1`
4. Start a timer (try 1 minute for testing)
5. Watch your keyboard become a countdown!

## How It Works

The keyboard divides into zones:

```
┌─────────────────────────────────────────────────┐
│  F1  F2  F3  F4  F5  F6  F7  F8  F9  F10 F11 F12 │  ← Top row (last to dim)
├─────────────────────────────────────────────────┤
│  1 2 3 4 5 6 7 8 9 0 - =                         │
│  Q W E R T Y U I O P [ ] \                       │  ← Main rows (fill/dim)
│  A S D F G H J K L ; '                           │
│  Z X C V B N M , . /                             │
├─────────────────────────────────────────────────┤
│  Shift  Ctrl  Win  Alt  Space  Alt  Win  Ctrl   │  ← Bottom row
└─────────────────────────────────────────────────┘
```

As time passes:
- **Green** (75-100%): Safe, plenty of time
- **Yellow** (50-75%): Halfway, warming up
- **Orange** (25-50%): Getting urgent
- **Red** (0-25%): Critical, pulsing warning
- **Flash White**: Timer complete!

## No RGB Keyboard?

The timer works normally without RGB. You'll see console messages:
```
⚠ OpenRGB not available (Install from openrgb.org and start SDK Server)
```

## Alternative: Console Visual

If you don't have an RGB keyboard, the console also shows a visual bar:

```
⏱ [45 seconds] Keyboard: ████████░░░░░░░░░░░░ 40%
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No RGB keyboard detected" | Install OpenRGB, start SDK Server |
| Colors not updating | Run OpenRGB as Administrator |
| Wrong key mapping | OpenRGB Settings → Device → Set Layout |
| Flickering | Increase update interval in timer |

## Advanced: Custom Colors

Edit `RGB-Countdown.ps1` line ~95 to change the color calculation:

```powershell
# Current: Green → Yellow → Red
$r = [math]::Min(255, [int](255 * $urgencyRatio * 2))
$g = [math]::Min(255, [int](255 * (1 - $urgencyRatio)))

# Custom: Blue → Purple → Pink
$r = [int](255 * $urgencyRatio)
$g = 0
$b = [int](255 * (1 - $urgencyRatio))
```

## One-File Version

Want everything in one file? Merge `RGB-Countdown.ps1` into `SleepTimer.ps1`:

1. Copy all functions from `RGB-Countdown.ps1` (lines 1-290)
2. Paste at the **end** of `SleepTimer.ps1` (before the final `}`)
3. Use the 4-step integration above

## Demo Mode

Test RGB without Sleep Timer Pro:

```powershell
. "RGB-Countdown.ps1"
Show-RGBCountdownDemo
```

This runs a 10-second countdown to show how it looks!
