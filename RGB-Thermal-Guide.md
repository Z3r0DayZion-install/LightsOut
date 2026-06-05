# RGB Thermal Monitor - Visual Temperature Display

Transform your keyboard into a **live thermal dashboard**!

## 🌡 How It Works

Your keyboard becomes a temperature map:

```
┌────────────────────────────────────────────────────────┐
│  🟦  🟦  🟦  🟦 │ 🟩  🟨  🟨  🟧 │ 🟥  🟥  🟥  🟥  │
│  F1  F2  F3  F4   F5  F6  F7  F8   F9  F10 F11 F12  │
│  ─────────────────────────────────────────────────────  │
│  🟦  🟦  🟦  🟦 │ 🟩  🟩  🟨  🟨 │ 🟧  🟥  🟥  🟥  │
│  1   2   3   4    5   6   7   8    9   0   -   =    │
│  ─────────────────────────────────────────────────────  │
│  🟦  🟦  🟦  🟦 │ 🟩  🟩  🟨  🟨 │ 🟧  🟥  🟥  🟥  │
│  Q   W   E   R    T   Y   U   I    O   P   [   ]    │
│  ─────────────────────────────────────────────────────  │
│  🟦  🟦  🟦  🟦  🟦  🟦 │ 🟨  🟨  🟧  🟧  🟥  🟥  │
│  A   S   D   F   G   H    J   K   L   ;   '        │
│  ─────────────────────────────────────────────────────  │
│  🟦  🟦  🟦  🟦  🟦 │ 🟨  🟨  🟧  🟧  🟥  🟥     │
│  Z   X   C   V   B    N   M   ,   .   /            │
└────────────────────────────────────────────────────────┘

      🔷 LEFT SIDE = CPU TEMP          🔶 RIGHT SIDE = GPU TEMP
      🧊 30-50°C = Blue (Cool)         🟢 50-65°C = Green (Good)
      🟡 65-75°C = Yellow (Warm)         🟠 75-85°C = Orange (Hot)
      🔴 85°C+   = Red + Pulsing (CRITICAL!)
```

## 📍 Zone Layout

| Zone | Keyboard Area | Monitors | Default Keys |
|------|---------------|----------|--------------|
| **Left Side** | F1-F4, 1-4, Q-R, A-F, Z-V | CPU Temperature | ~26 keys |
| **Right Side** | F9-F12, 9-0, U-P, H-L, B-M | GPU Temperature | ~26 keys |
| **Center** | F5-F8, T-Y, G, B | Average/System | ~9 keys |
| **Mouse** | Entire mouse | Highest Temp | All LEDs |

## 🎨 Color Scale

| Temperature | Color | Meaning |
|-------------|-------|---------|
| **30-40°C** | 🔵 Deep Blue | Ice cold |
| **40-50°C** | 🔷 Cyan | Cool |
| **50-60°C** | 🟢 Green | Normal |
| **60-70°C** | 🟡 Yellow | Warm |
| **70-80°C** | 🟠 Orange | Hot |
| **80-90°C** | 🔴 Red | Very Hot |
| **90°C+** | 🔴⚡ Pulsing Red | CRITICAL! |

## 🚀 Quick Start

### 1. Install OpenRGB

Download from https://openrgb.org/ (free, open source)

### 2. Start SDK Server

OpenRGB → Settings → SDK Server → Start Server (port 6742)

### 3. Run Thermal Monitor

```powershell
. "RGB-ThermalMonitor.ps1"
Start-ThermalMonitor
```

Your keyboard will light up showing live temperatures!

## 🔧 Customization

### Change Zone Assignment

Edit `RGB-ThermalMonitor.ps1` around line 75:

```powershell
# Change which sensor monitors which zone
CPU_Left = @{
    Sensor = "CPU"      # Change to "GPU" or "Average"
    MinTemp = 30        # Adjust for your system
    MaxTemp = 90        # Adjust for your system
}
```

### Add Custom Keys

Add specific keys to any zone:

```powershell
Keys = @(
    @(0,0),   # F1 - Row 0, Column 0
    @(0,1),   # F2 - Row 0, Column 1
    @(2,0),   # Q - Row 2, Column 0
    @(4,2),   # C - Row 4, Column 2
)
```

### Change Color Range

Edit the color function (line ~95):

```powershell
# Default: Blue at 30°C, Red at 90°C
$color = Get-TemperatureColor -Temp $cpuTemp -Min 30 -Max 90

# Custom: Blue at 20°C, Red at 70°C (for water cooling)
$color = Get-TemperatureColor -Temp $cpuTemp -Min 20 -Max 70
```

## 📊 Integration with Sleep Timer Pro

Add thermal monitoring to your sleep timer:

### Option A: Thermal Overlay (Recommended)

Show temps while timer runs:

```powershell
# In SleepTimer.ps1 timer loop, add:
if ($settings.ShowThermal -and ($elapsed % 10 -eq 0)) {  # Update every 10s
    $temps = Get-SystemTemperatures
    Update-ThermalRGB -Temperatures $temps
}
```

### Option B: Thermal Warning

Only show RGB temps if CPU gets hot:

```powershell
# Before sleep/hibernate action
$cpu = Get-CpuTemperature
if ($cpu -gt 75) {
    Show-BalloonNotification -Title "⚠ Hot CPU: $cpu°C" -Message "System cooling before sleep..."
    # Flash keyboard red
    Set-ThermalRGBKeyboard -Temperatures @{ CPU = $cpu }
    Start-Sleep -Seconds 5  # Wait to cool
}
```

### Option C: Dual Mode (Timer + Thermal)

Left side = Timer countdown (green→red)
Right side = CPU temp (blue→red)

```powershell
# Requires merging both RGB modules
# Left 50% of keys: Countdown progress
# Right 50% of keys: Temperature
```

## 🖱️ Mouse Support

For RGB mice (Razer, Logitech G, Corsair):

The mouse shows the **highest** temperature (CPU or GPU) as a single color:

| Mouse Color | Meaning |
|-------------|---------|
| 🔵 Blue | Everything cool |
| 🟢 Green | Normal temps |
| 🟡 Yellow | Getting warm |
| 🟠 Orange | Hot |
| 🔴 Pulsing Red | CRITICAL - Check PC! |

## 🎮 Gaming Mode

When gaming, your keyboard shows live temps so you know if your PC is overheating:

```powershell
# Monitor during 2-hour gaming session
Start-ThermalMonitor -UpdateIntervalSeconds 5 -DurationMinutes 120
```

## 🔬 How Temperature Detection Works

| Method | Reliability | Requirements |
|--------|-------------|--------------|
| **WMI Thermal Zones** | ⭐⭐⭐⭐⭐ | Windows 8+, modern motherboard |
| **Performance Counters** | ⭐⭐⭐⭐ | Windows built-in |
| **nvidia-smi** | ⭐⭐⭐⭐⭐ | NVIDIA GPU + drivers |
| **AMD ADL** | ⭐⭐⭐ | AMD GPU (partial support) |

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "CPU temp shows null" | Run as Administrator / Check WMI permissions |
| "GPU temp not found" | Install vendor software (GeForce Experience, AMD drivers) |
| "Wrong keys light up" | OpenRGB → Device → Set correct keyboard layout |
| "Colors don't change" | Check OpenRGB SDK Server is started |
| "Too slow updates" | Lower `$UpdateIntervalSeconds` to 1 |
| "Flickering" | Increase interval to 3-5 seconds |

## 📁 File Structure

```
windsurf-project/
├── SleepTimer.ps1              # Main timer app
├── RGB-Countdown.ps1           # Timer countdown on RGB
├── RGB-ThermalMonitor.ps1      # ⬅️ Temperature display
├── RGB-Thermal-Guide.md        # This guide
└── RGB-Integration-Guide.md    # General RGB setup
```

## 🖥️ Console-Only Mode

No RGB keyboard? The thermal monitor still works:

```
🌡 THERMAL MONITOR
━━━━━━━━━━━━━━━━━━━
CPU: 62°C ████████████░░░░░░░░ (Zone: Left Side)
GPU: 71°C ███████████████░░░░░ (Zone: Right Side)
━━━━━━━━━━━━━━━━━━━
```

## 🎯 Use Cases

1. **Gaming** - Watch temps during intense sessions
2. **Rendering** - Monitor CPU during video encoding
3. **Mining** - Check GPU temps continuously
4. **Overclocking** - Visual feedback while testing
5. **General Use** - Pretty colors that happen to be useful!

## 💡 Pro Tips

- **Set Min/Max for your system**: If your CPU idles at 40°C, set Min=40
- **Use center for alerts**: Flash center keys when temps spike
- **Combine with timer**: Left=timer, Right=thermals
- **Different profiles**: Gaming vs Idle vs Rendering profiles

Run it now and watch your keyboard come alive with temperature data! 🌈🌡
