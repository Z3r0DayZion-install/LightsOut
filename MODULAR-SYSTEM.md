# 🧩 Modular Sleep Timer System

> **Nightly app:** [`COOLTIMER.md`](COOLTIMER.md) — not part of this modular split.

Two separate apps that work together or standalone through event-based communication.

## Architecture

```
┌─────────────────────┐         ┌─────────────────────┐
│  SleepTimer-Core    │◄───────►│  RGB-Controller     │
│  (Timer Engine)     │ Events  │  (RGB Display)      │
└──────────┬──────────┘         └──────────┬──────────┘
           │                                │
           ▼                                ▼
    %TEMP%\SleepTimer\Events\        OpenRGB SDK
    (JSON event files)               (RGB Keyboard)
```

## Communication Method

**Event-Driven Architecture:**
- Timer publishes events to `%TEMP%\SleepTimer\Events\`
- RGB Controller watches folder and reacts
- No direct coupling - apps can run independently

### Event Types

| Event | Data | RGB Response |
|-------|------|--------------|
| `Started` | TotalSeconds, Action | Light up blue |
| `Tick` | RemainingSeconds, Percent | Update progress color |
| `Warning` | RemainingSeconds | Flash yellow |
| `Completed` | Action | Flash white 3x |
| `Cancelled` | RemainingSeconds | Dim to gray |

## Two Apps Explained

### App 1: SleepTimer-Core.ps1
**Purpose:** Timer engine only - no GUI, no RGB

**Can run:**
- ✅ Standalone (console timer)
- ✅ With RGB-Controller (watches events)
- ✅ As module (other scripts import it)

**Usage:**
```powershell
# Standalone timer
.\SleepTimer-Core.ps1 -Minutes 30 -Action Shutdown

# Event mode (outputs events for RGB)
.\SleepTimer-Core.ps1 -Minutes 30 -Action Sleep -EventMode

# As module
Import-Module .\SleepTimer-Core.ps1 -Function Start-TimerEngine, Register-TimerModule
```

### App 2: RGB-Controller.ps1
**Purpose:** RGB visualization - no timer logic

**Can run:**
- ✅ Standalone (thermal display, demos)
- ✅ Subscribed to timer (reacts to events)
- ✅ As module (other scripts control it)

**Usage:**
```powershell
# Watch for timer events
.\RGB-Controller.ps1 -SubscribeToTimer

# Standalone thermal display
.\RGB-Controller.ps1 -Standalone

# As module
Import-Module .\RGB-Controller.ps1
Set-RGBMode -Mode "Thermal"
Set-ThermalData -CPU 65 -GPU 70
```

## Usage Modes

### Mode 1: Both Apps Together
```powershell
# Terminal 1: Start timer with events
.\SleepTimer-Core.ps1 -Minutes 10 -EventMode

# Terminal 2: Start RGB watching
.\RGB-Controller.ps1 -SubscribeToTimer
```

### Mode 2: Timer Only (No RGB)
```powershell
.\SleepTimer-Core.ps1 -Minutes 30
```

### Mode 3: RGB Only (No Timer)
```powershell
.\RGB-Controller.ps1 -Standalone
```

### Mode 4: Module Integration
```powershell
# Load both as modules
Import-Module .\SleepTimer-Core.ps1
Import-Module .\RGB-Controller.ps1

# Connect RGB
Connect-RGBController

# Register RGB as timer listener
Register-TimerModule -ModuleName "RGB" -OnTick {
    param($RemainingSeconds, $PercentComplete)
    Set-TimerData -RemainingSeconds $RemainingSeconds -TotalSeconds 600 -Active $true
}

# Start timer
Start-TimerEngine -DurationSeconds 600 -TimerAction "Shutdown"
```

## Modular Launcher

```powershell
.\Launch-Modular.ps1
```

Menu:
```
╔════════════════════════════════════════╗
║  Modular Sleep Timer System            ║
╠════════════════════════════════════════╣
║                                        ║
║  [1] Start Timer (Console)            ║
║  [2] Start RGB Controller (Thermal)   ║
║  [3] Start BOTH (Timer + RGB)          ║
║  [4] RGB Demo Mode                     ║
║  [5] Module Test                       ║
║                                        ║
╚════════════════════════════════════════╝
```

## Why This Design?

| Benefit | Explanation |
|---------|-------------|
| **Separation of Concerns** | Timer does timing, RGB does lights |
| **Independent Deployment** | Use only what you need |
| **Easy Testing** | Test timer without RGB hardware |
| **Language Agnostic** | Event files could be read by Python, C#, etc. |
| **Hot Swappable** | Restart RGB without stopping timer |
| **Scalable** | Multiple RGB controllers can watch same timer |

## API Reference

### SleepTimer-Core Exports
```powershell
Start-TimerEngine      # Start countdown
Stop-TimerEngine       # Cancel countdown
Register-TimerModule   # Add callback module
Get-TimerStatus        # Get current state
Publish-TimerEvent     # Broadcast event
```

### RGB-Controller Exports
```powershell
Connect-RGBController  # Connect to OpenRGB
Set-RGBMode            # Set display mode
Set-TimerData          # Update timer info
Set-ThermalData        # Update temps
Update-RGBDisplay      # Refresh lights
Flash-RGBZone          # Flash effect
```

## File Structure

```
Modular-Suite/
│
├── Core Apps (Independent)
│   ├── SleepTimer-Core.ps1      ⭐ Timer engine
│   └── RGB-Controller.ps1        ⭐ RGB display
│
├── Integration
│   ├── Launch-Modular.ps1      🚀 Launcher menu
│   └── Combined-GUI.ps1        🎨 Optional combined UI
│
└── Documentation
    ├── MODULAR-SYSTEM.md       📖 This file
    └── README.md               📖 General docs
```

## Event File Format

```json
{
    "Module": "SleepTimer-Core",
    "Version": "3.0",
    "Timestamp": "2024-01-15 14:30:45",
    "EventType": "Tick",
    "Data": {
        "RemainingSeconds": 580,
        "PercentComplete": 3,
        "ElapsedSeconds": 20
    }
}
```

## Testing

### Test 1: Timer Events
```powershell
.\SleepTimer-Core.ps1 -Minutes 1 -EventMode
# Watch console for EVENT: output
```

### Test 2: RGB Standalone
```powershell
.\RGB-Controller.ps1 -Standalone
# Keyboard should show rainbow/wave
```

### Test 3: Integration
```powershell
# Terminal 1
.\SleepTimer-Core.ps1 -Minutes 2 -EventMode

# Terminal 2 (run simultaneously)
.\RGB-Controller.ps1 -SubscribeToTimer

# Both should work together!
```

## Extending the System

### Create Your Own Module

```powershell
# MyCustomModule.ps1
Import-Module .\SleepTimer-Core.ps1

Register-TimerModule -ModuleName "MyModule" -OnTick {
    param($RemainingSeconds, $PercentComplete)
    
    # Do something on each tick
    Write-Host "Custom: $PercentComplete% complete"
    
    # Send to web API, log to database, etc.
}

# Or watch events directly
while ($true) {
    $events = Get-ChildItem $env:TEMP\SleepTimer\Events -Filter "*.json"
    foreach ($e in $events) {
        $data = Get-Content $e | ConvertFrom-Json
        # Process
        Remove-Item $e  # Clean up
    }
    Start-Sleep -Seconds 1
}
```

## Comparison: Old vs Modular

| Feature | Old (Single File) | New (Modular) |
|---------|-----------------|---------------|
| Lines of Code | 1660 | 800 + 600 |
| Complexity | High | Low per module |
| Testability | Hard | Easy |
| RGB Optional | ❌ Always loaded | ✅ Truly optional |
| Standalone Timer | ❌ Has RGB code | ✅ Pure timer |
| Standalone RGB | ❌ N/A | ✅ Pure RGB |
| Reusability | Low | High |

## Migration Path

**From original SleepTimer.ps1:**

1. Replace timer logic with `SleepTimer-Core.ps1` calls
2. Move RGB to `RGB-Controller.ps1` subscription
3. Keep GUI in separate file or merge

**Or keep both:**
- Original `SleepTimer.ps1` for full-featured users
- Modular suite for advanced/power users

## Future Extensions

Modules that could be added:
- **AudioModule** - Play sounds on events
- **WebModule** - Web dashboard
- **DiscordModule** - Discord notifications
- **DatabaseModule** - Log history to SQL
- **TrayModule** - System tray icon only

All would use the same event system!

## Summary

**SleepTimer-Core** = The brain (timer logic)
**RGB-Controller** = The display (RGB visualization)
**Events** = The nervous system (communication)

Run together or separately - your choice! 🧩
